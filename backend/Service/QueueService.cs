using System;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.EntityFrameworkCore;
using QueueApp.Data;
using QueueApp.Models;

namespace QueueApp.Services
{
    public class QueueService
    {
        private readonly AppDbContext _db;
        private readonly NotificationService _notificationService;

        public QueueService(AppDbContext db, NotificationService notificationService)
        {
            _db = db;
            _notificationService = notificationService;
        }

        /// <summary>
        /// Tính lại thứ tự hàng chờ + thời gian chờ ước tính (PHÚT, lưu int?)
        /// và gửi thông báo "sắp đến lượt" cho những ai còn đúng 1 nhóm phía trước.
        /// </summary>
        public async Task RecalculateQueueAndNotifyAsync(
    int restaurantId,
    int queueTypeId,
    CancellationToken ct = default)
{
    var waitingEntries = await _db.QueueEntries
        .Where(q =>
            q.RestaurantID == restaurantId &&
            q.QueueTypeID == queueTypeId &&
            q.Status == "Waiting")
        .OrderBy(q => q.JoinTime)
        .Include(q => q.QueueType) // Để lấy StandardServiceDuration
        .ToListAsync(ct);
    
    for (int i = 0; i < waitingEntries.Count; i++)
    {
        var e = waitingEntries[i];
        
        // Cập nhật vị trí mới
        e.CurrentPosition = i + 1;

        int ahead = i; // Số người đứng trước
        var duration = e.QueueType?.StandardServiceDuration ?? 10;
        e.EstimatedWaitTime = ahead * duration;

        // ⭐ LOGIC MỚI: Gửi thông báo cho 2 người đầu hàng
        // Chỉ gửi nếu chưa gửi (cần logic check tránh spam, nhưng ở mức đơn giản ta cứ gọi hàm service)
        
        // Trường hợp 1: Đứng đầu hàng (Quan trọng nhất)
        if (ahead == 0)
        {
             // Gọi hàm thông báo kiểu "Đến lượt bạn rồi"
             // Bạn cần viết thêm hàm này bên NotificationService hoặc dùng lại hàm cũ với text khác
             await _notificationService.CreateTurnNotificationAsync(e, ct);
        }
        // Trường hợp 2: Đứng thứ 2 (Chuẩn bị)
        else if (ahead == 1)
        {
            await _notificationService.CreateAlmostTurnNotificationAsync(
                e, ahead, e.EstimatedWaitTime ?? 0, ct
            );
        }
    }

    await _db.SaveChangesAsync(ct);
}

        // ================== TẠO LƯỢT CHỜ ==================
        public async Task<QueueEntry> CreateQueueEntryAsync(
            int restaurantId,
            int userId,
            int queueTypeId,
            int partySize,
            string? notes,
            CancellationToken ct = default)
        {
            // ❌ Không cho 1 user có 2 ticket active ở cùng 1 nhà hàng
            var hasActive = await _db.QueueEntries.AnyAsync(q =>
                    q.RestaurantID == restaurantId &&
                    q.UserID == userId &&
                    (q.Status == "Waiting" || q.Status == "Called"),
                ct);

            if (hasActive)
            {
                throw new InvalidOperationException(
                    "User đã có lượt chờ đang hoạt động ở nhà hàng này.");
            }

            // ✅ Tính số thứ tự tiếp theo trong nhà hàng (dùng cho hiển thị ticket)
            var maxPosition = await _db.QueueEntries
                .Where(q => q.RestaurantID == restaurantId)
                .MaxAsync(q => (int?)q.CurrentPosition, ct) ?? 0;

            // Đếm số lượt đang chờ trong CÙNG queue type để ước lượng thời gian
            var waitingInThisQueueType = await _db.QueueEntries.CountAsync(q =>
                    q.RestaurantID == restaurantId &&
                    q.QueueTypeID == queueTypeId &&
                    q.Status == "Waiting",
                ct);

            var queueType = await _db.QueueTypes
                .FirstOrDefaultAsync(qt => qt.QueueTypeID == queueTypeId, ct);

            var duration = queueType?.StandardServiceDuration ?? 10; // phút / nhóm

            int peopleAhead = waitingInThisQueueType;
            int? estimatedWait =
                peopleAhead == 0
                    ? 0
                    : peopleAhead * duration;  // phút

            var entry = new QueueEntry
            {
                PartySize         = partySize,
                JoinTime          = DateTime.Now,
                CurrentPosition   = maxPosition + 1,   // số thứ tự chung theo nhà hàng
                EstimatedWaitTime = estimatedWait,     // int? phút
                Status            = "Waiting",
                UserID            = userId,
                RestaurantID      = restaurantId,
                QueueTypeID       = queueTypeId,
                Notes             = notes
            };

            _db.QueueEntries.Add(entry);
            await _db.SaveChangesAsync(ct);

            return entry;
        }

        // ================== XOÁ LƯỢT CHỜ ==================
        public async Task<bool> RemoveFromQueueAsync(long queueEntryId, CancellationToken ct = default)
        {
            var entry = await _db.QueueEntries
                .FirstOrDefaultAsync(q => q.QueueEntryID == queueEntryId, ct);

            if (entry == null)
                return false;

            int restaurantId = entry.RestaurantID;
            int queueTypeId  = entry.QueueTypeID;

            _db.QueueEntries.Remove(entry);
            await _db.SaveChangesAsync(ct);

            await _notificationService.DeleteNotificationsForQueueEntryAsync(queueEntryId, ct);

            // Sau khi 1 người rời hàng → tính lại hàng chờ + gửi noti nếu cần
            await RecalculateQueueAndNotifyAsync(restaurantId, queueTypeId, ct);

            return true;
        }
    }
}
