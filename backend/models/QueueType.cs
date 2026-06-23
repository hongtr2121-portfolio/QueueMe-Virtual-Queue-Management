using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace QueueApp.Models
{
    public class QueueType
    {
        [Key]
        public int QueueTypeID { get; set; }

        // FK tới Restaurant
        public int RestaurantID { get; set; }
        [ForeignKey("RestaurantID")]
        public Restaurant Restaurant { get; set; } = null!;

        [Required, MaxLength(100)]
        public string Name { get; set; } = string.Empty; // ví dụ "Bàn 2 người"

        public int? MaxPartySize { get; set; } // số người tối đa cho loại này
        public int? StandardServiceDuration { get; set; } // phút
        public bool IsActive { get; set; } = true;

        // Các lượt chờ thuộc loại này
        public ICollection<QueueEntry>? QueueEntries { get; set; }
    }
}
