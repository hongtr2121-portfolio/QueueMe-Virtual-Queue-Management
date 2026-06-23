using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using Microsoft.EntityFrameworkCore;

namespace QueueApp.Models
{
    public class QueueEntry
    {
        [Key]
        public long QueueEntryID { get; set; }  // ⚙️ Đổi lại cho đồng bộ với QueueService (entry.QueueEntryID)

        // ✅ Số lượng khách trong nhóm (1–20)
        [Required]
        [Range(1, 20, ErrorMessage = "Số người trong nhóm phải từ 1–20.")]
        public int PartySize { get; set; }

        [Required]
        public DateTime JoinTime { get; set; } = DateTime.UtcNow;

        public string? Notes { get; set; }

        // ✅ Vị trí hiện tại trong hàng chờ
        [Range(0, int.MaxValue)]
        public int? CurrentPosition { get; set; }

        // ✅ Thời gian ước tính chờ (phút)
        [Range(0, int.MaxValue)]
        [Comment("Thời gian ước tính chờ (phút)")]
        public int? EstimatedWaitTime { get; set; }

        [Required, MaxLength(50)]
        public string Status { get; set; } = "Waiting"; // "Waiting", "Called", "Canceled", "Completed"

        // 🔗 FK tới User (customer)
        [Required]
        public int UserID { get; set; }

        [ForeignKey(nameof(UserID))]
        public User User { get; set; } = null!;

        // 🔗 FK tới Restaurant
        [Required]
        public int RestaurantID { get; set; }

        [ForeignKey(nameof(RestaurantID))]
        public Restaurant Restaurant { get; set; } = null!;

        // 🔗 FK tới QueueType
        [Required]
        public int QueueTypeID { get; set; }

        [ForeignKey(nameof(QueueTypeID))]
        public QueueType QueueType { get; set; } = null!;

        // 🔗 Các thông báo liên quan (nếu có)
        public ICollection<Notification>? Notifications { get; set; }
    }
}
