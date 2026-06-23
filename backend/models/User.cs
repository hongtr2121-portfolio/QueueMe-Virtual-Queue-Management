using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace QueueApp.Models
{
    public class User
    {
        [Key]
        public int UserID { get; set; }

        [Required, MaxLength(255)]
        public string? Email { get; set; }

        [MaxLength(20)]
        public string? PhoneNumber { get; set; }

        [Required, MaxLength(128)]
        public string? PasswordHash { get; set; }

        [MaxLength(100)]
        public string? FirstName { get; set; }

        [MaxLength(100)]
        public string? LastName { get; set; }

        [Required, MaxLength(50)]
        public string? UserType { get; set; }  // "Admin" hoặc "Customer"

        [Required]
        public bool IsVerified { get; set; } = false;

        // ======================
        // 🔗 Navigation properties
        // ======================

        // Một AdminUser sẽ quản lý đúng 1 nhà hàng (1-1)
        public Restaurant? Restaurant { get; set; }

        // Một user (khách hàng) có thể có nhiều lượt chờ (1-n)
        public ICollection<QueueEntry>? QueueEntries { get; set; }

        // Một user có thể có nhiều thông báo (1-n)
        public ICollection<Notification>? Notifications { get; set; }
    }
}
