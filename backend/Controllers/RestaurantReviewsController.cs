using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using QueueApp.Data;
using System.ComponentModel.DataAnnotations;

namespace QueueApp.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    [Produces("application/json")]
    public class RestaurantReviewsController : ControllerBase
    {
        private readonly AppDbContext _context;

        public RestaurantReviewsController(AppDbContext context)
        {
            _context = context;
        }

        // DTO (GIỮ NGUYÊN key để Flutter khỏi đổi)
        public class CreateRestaurantReviewDto
        {
            [Required]
            public int restaurantId { get; set; }

            [Required]
            public int userId { get; set; }

            [Required, Range(1, 5)]
            public int rating { get; set; }

            public string? comment { get; set; }
        }

        // ✅ 1 format DUY NHẤT
        // Notes sẽ có dạng: [Rating:5] ngon, phục vụ nhanh
        private const string RatingPrefix = "[Rating:";

        private static bool HasRating(string? notes)
        {
            if (string.IsNullOrWhiteSpace(notes)) return false;
            return notes.Contains(RatingPrefix, StringComparison.OrdinalIgnoreCase);
        }

        private static string BuildRatingText(int rating, string? comment)
        {
            var c = string.IsNullOrWhiteSpace(comment) ? "" : $" {comment.Trim()}";
            return $"{RatingPrefix}{rating}]{c}";
        }

        // GET: /api/RestaurantReviews/exists?restaurantId=..&userId=..
        [HttpGet("exists")]
        public async Task<ActionResult<bool>> Exists(
            [FromQuery] int restaurantId,
            [FromQuery] int userId,
            CancellationToken ct = default)
        {
            // ✅ Chỉ cần check: có QueueEntry Completed + Notes chứa [Rating:
            // Lưu ý: Contains(StringComparison) không translate SQL -> dùng EF.Functions.Like
            var exists = await _context.QueueEntries
                .AsNoTracking()
                .AnyAsync(q =>
                    q.RestaurantID == restaurantId &&
                    q.UserID == userId &&
                    q.Status == "Completed" &&
                    q.Notes != null &&
                    EF.Functions.Like(q.Notes, "%[Rating:%"),
                    ct);

            return Ok(exists);
        }

        // POST: /api/RestaurantReviews
        [HttpPost]
        public async Task<IActionResult> Create(
            [FromBody] CreateRestaurantReviewDto dto,
            CancellationToken ct = default)
        {
            // Validate restaurant/user tồn tại
            var restaurantExists = await _context.Restaurants
                .AsNoTracking()
                .AnyAsync(x => x.RestaurantID == dto.restaurantId, ct);

            if (!restaurantExists)
                return NotFound(new { message = $"Không tìm thấy RestaurantID={dto.restaurantId}" });

            var userExists = await _context.Users
                .AsNoTracking()
                .AnyAsync(x => x.UserID == dto.userId, ct);

            if (!userExists)
                return NotFound(new { message = $"Không tìm thấy UserID={dto.userId}" });

            // ✅ Lấy lượt Completed mới nhất để gắn rating vào Notes
            var entry = await _context.QueueEntries
                .OrderByDescending(q => q.JoinTime)
                .FirstOrDefaultAsync(q =>
                    q.RestaurantID == dto.restaurantId &&
                    q.UserID == dto.userId &&
                    q.Status == "Completed", ct);

            if (entry == null)
                return NotFound(new { message = "Không tìm thấy lượt Completed để đánh giá." });

            // Không cho review trùng
            if (HasRating(entry.Notes))
                return Conflict(new { message = "Bạn đã đánh giá lượt này rồi." });

            var ratingText = BuildRatingText(dto.rating, dto.comment);

            entry.Notes = string.IsNullOrWhiteSpace(entry.Notes)
                ? ratingText
                : $"{entry.Notes} | {ratingText}";

            await _context.SaveChangesAsync(ct);

            return Ok(new { message = "Đã gửi đánh giá (lưu trong Notes của QueueEntry)." });
        }
    }
}
