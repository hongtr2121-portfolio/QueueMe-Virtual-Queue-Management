using System;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace QueueApp.Models
{
    public class Notification
    {
        [Key]
        public long NotificationID { get; set; }

        [Required, MaxLength(500)]
        public string Message { get; set; } = string.Empty;

        [Required, MaxLength(50)]
        public string Type { get; set; } = string.Empty;

        [Required]
        public DateTime Timestamp { get; set; } = DateTime.UtcNow;

        public bool IsSent { get; set; } = false;

        // FK
        public int UserID { get; set; }

        public long QueueEntryID { get; set; }

        [ForeignKey(nameof(UserID))]
        public User? User { get; set; }

        [ForeignKey(nameof(QueueEntryID))]
        public QueueEntry? QueueEntry { get; set; }
    }
}
