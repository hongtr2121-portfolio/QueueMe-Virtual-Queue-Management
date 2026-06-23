using Microsoft.EntityFrameworkCore;
using QueueApp.Models;
using System.Linq; // cần cho SelectMany ở foreach

namespace QueueApp.Data
{
    public class AppDbContext : DbContext
    {
        public AppDbContext(DbContextOptions<AppDbContext> options)
            : base(options)
        {
        }

        public DbSet<User> Users { get; set; } = null!;
        public DbSet<Restaurant> Restaurants { get; set; } = null!;
        public DbSet<QueueType> QueueTypes { get; set; } = null!;
        public DbSet<QueueEntry> QueueEntries { get; set; } = null!;
        public DbSet<Notification> Notifications { get; set; } = null!;


        protected override void OnModelCreating(ModelBuilder modelBuilder)
        {
            base.OnModelCreating(modelBuilder);

            // USER ↔ QUEUEENTRY (1-n)
            modelBuilder.Entity<User>()
                .HasMany(u => u.QueueEntries)
                .WithOne(q => q.User)
                .HasForeignKey(q => q.UserID);

            // USER ↔ NOTIFICATION (1-n)
            modelBuilder.Entity<User>()
                .HasMany(u => u.Notifications)
                .WithOne(n => n.User)
                .HasForeignKey(n => n.UserID);

            // USER ↔ RESTAURANT (1-1)
            modelBuilder.Entity<User>()
                .HasOne(u => u.Restaurant)
                .WithOne(r => r.AdminUser)
                .HasForeignKey<Restaurant>(r => r.AdminUserID)
                .IsRequired(false); // tránh lỗi xác định principal/optional

            // RESTAURANT ↔ QUEUETYPE (1-n)
            modelBuilder.Entity<Restaurant>()
                .HasMany(r => r.QueueTypes)
                .WithOne(qt => qt.Restaurant)
                .HasForeignKey(qt => qt.RestaurantID);

            // RESTAURANT ↔ QUEUEENTRY (1-n)
            modelBuilder.Entity<Restaurant>()
                .HasMany(r => r.QueueEntries)
                .WithOne(q => q.Restaurant)
                .HasForeignKey(q => q.RestaurantID);

            // QUEUETYPE ↔ QUEUEENTRY (1-n)
            modelBuilder.Entity<QueueType>()
                .HasMany(qt => qt.QueueEntries)
                .WithOne(qe => qe.QueueType)
                .HasForeignKey(qe => qe.QueueTypeID);

            // QUEUEENTRY ↔ NOTIFICATION (1-n)
            modelBuilder.Entity<QueueEntry>()
                .HasMany(qe => qe.Notifications)
                .WithOne(n => n.QueueEntry)
                .HasForeignKey(n => n.QueueEntryID);

            // --- CẤU HÌNH CỘT CƠ BẢN ---
            modelBuilder.Entity<User>()
                .Property(u => u.UserType)
                .HasMaxLength(50)
                .IsRequired();

            modelBuilder.Entity<Restaurant>()
                .Property(r => r.Name)
                .HasMaxLength(100)
                .IsRequired();

            modelBuilder.Entity<QueueType>()
                .Property(qt => qt.Name)
                .HasMaxLength(100)
                .IsRequired();

            modelBuilder.Entity<QueueEntry>()
                .Property(qe => qe.Status)
                .HasMaxLength(50)
                .IsRequired();

            // (khuyến nghị) Giới hạn độ dài Message để tránh nvarchar(max) không cần thiết
            modelBuilder.Entity<Notification>()
                .Property(n => n.Message)
                .HasMaxLength(500);

            // (khuyến nghị) Index các khóa ngoại để tối ưu truy vấn
            modelBuilder.Entity<QueueEntry>().HasIndex(q => q.RestaurantID);
            modelBuilder.Entity<QueueEntry>().HasIndex(q => q.QueueTypeID);
            modelBuilder.Entity<Notification>().HasIndex(n => n.UserID);
            modelBuilder.Entity<Notification>().HasIndex(n => n.QueueEntryID);

            // 🚫 Tắt cascade delete toàn cục để tránh multiple cascade paths
            foreach (var fk in modelBuilder.Model.GetEntityTypes().SelectMany(e => e.GetForeignKeys()))
            {
                fk.DeleteBehavior = DeleteBehavior.Restrict;
            }
        }
    }
}
