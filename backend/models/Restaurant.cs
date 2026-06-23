using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace QueueApp.Models
{
    public class Restaurant
    {
        [Key]
        public int RestaurantID { get; set; }

        [Required, MaxLength(255)]
        public string? Name { get; set; }

        [MaxLength(255)]
        public string? GooglePlaceID { get; set; }

        public double? Latitude { get; set; }
        public double? Longitude { get; set; }

        public string? Address { get; set; }

        [Column(TypeName = "decimal(3,2)")]
        public decimal? OverallRating { get; set; }

        public string? OperatingHours { get; set; }

        // 🔗 Foreign Key
        public int? AdminUserID { get; set; }

        [ForeignKey("AdminUserID")]
        public User? AdminUser { get; set; }

      // Một nhà hàng có nhiều loại hàng đợi
        public ICollection<QueueType>? QueueTypes { get; set; }

    // Một nhà hàng có nhiều lượt chờ
    public ICollection<QueueEntry>? QueueEntries { get; set; }
    }

}

