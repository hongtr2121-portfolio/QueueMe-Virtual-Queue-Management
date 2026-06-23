using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using QueueApp.Data;
using QueueApp.Models;

namespace QueueApp.Services
{
    public class NotificationService
    {
        private readonly AppDbContext _db;
        private readonly ILogger<NotificationService> _logger;

        public NotificationService(AppDbContext db, ILogger<NotificationService> logger)
        {
            _db = db;
            _logger = logger;
        }

        /// <summary>
        /// Xóa tất cả notifications thuộc về QueueEntryID
        /// </summary>
        public async Task DeleteNotificationsForQueueEntryAsync(long queueEntryId, CancellationToken ct = default)
        {
            var items = await _db.Notifications
                .Where(n => n.QueueEntryID == queueEntryId)
                .ToListAsync(ct);

            if (items.Any())
            {
                _db.Notifications.RemoveRange(items);
                await _db.SaveChangesAsync(ct);
            }
        }

        // ⭐ HÀM MỚI: tạo notification "còn 1 người trước bạn"
        public async Task CreateAlmostTurnNotificationAsync(
            QueueEntry entry,
            int peopleAhead,
            int waitMinutes,
            CancellationToken ct = default)
        {
            _logger.LogInformation(
                "CreateAlmostTurnNotification for User {UserId}, Entry {EntryId}, ahead={Ahead}, wait={Min}",
                entry.UserID, entry.QueueEntryID, peopleAhead, waitMinutes);

            var restaurantName = await _db.Restaurants
                .Where(r => r.RestaurantID == entry.RestaurantID)
                .Select(r => r.Name)
                .FirstOrDefaultAsync(ct);

            var eta = DateTime.Now.AddMinutes(waitMinutes);

            var msg =
                $"Sắp đến lượt bạn tại {restaurantName}. " +
                $"Hiện chỉ còn {peopleAhead} nhóm trước bạn. " +
                $"Thời gian dự kiến: khoảng {waitMinutes} phút nữa (lúc {eta:HH:mm}). " +
                $"Bạn nên chuẩn bị di chuyển tới quán.";

            var n = new Notification
            {
                UserID       = entry.UserID,
                QueueEntryID = entry.QueueEntryID,
                Message      = msg,
                Type         = "AlmostTurn",
                Timestamp    = DateTime.UtcNow,
                IsSent       = false
            };

            _db.Notifications.Add(n);
            await _db.SaveChangesAsync(ct);
        }

        // ⭐ HÀM MỚI: Thông báo khi đã đứng đầu hàng
        public async Task CreateTurnNotificationAsync(QueueEntry entry, CancellationToken ct = default)
        {
            var restaurantName = await _db.Restaurants
                .Where(r => r.RestaurantID == entry.RestaurantID)
                .Select(r => r.Name)
                .FirstOrDefaultAsync(ct);

            var msg = $"🎉 Bạn đã đứng đầu hàng tại {restaurantName}! Vui lòng đến quầy ngay để được phục vụ.";

            var n = new Notification
            {
                UserID = entry.UserID,
                QueueEntryID = entry.QueueEntryID,
                Message = msg,
                Type = "Ready", // Loại thông báo mới
                Timestamp = DateTime.UtcNow,
                IsSent = false
            };

            _db.Notifications.Add(n);
            await _db.SaveChangesAsync(ct);
        }
    } // <-- Đã thêm đóng ngoặc class
} // <-- Đã thêm đóng ngoặc namespace