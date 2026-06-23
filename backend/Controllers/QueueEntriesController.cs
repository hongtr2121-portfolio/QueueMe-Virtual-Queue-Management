using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using QueueApp.Data;
using QueueApp.Models;
using QueueApp.Services;
using QueueApp.Dtos;          // UpdateQueueStatusDto
using System.ComponentModel.DataAnnotations;

namespace QueueApp.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    [Produces("application/json")]
    public class QueueEntriesController : ControllerBase
    {
        private readonly AppDbContext _context;
        private readonly QueueService _queueService;

        public QueueEntriesController(AppDbContext context, QueueService queueService)
        {
            _context = context;
            _queueService = queueService;
        }

        // ========================
        // 🔹 DTOs
        // ========================

        public record QueueEntryDto(
            long queueEntryID,
            int restaurantID,
            string? restaurantName,
            int userID,
            string? userName,
            int queueTypeID,
            int partySize,
            string status,
            DateTime joinTime,
            int? estimatedWaitTime,
            int currentPosition,
            string? notes
        );
        public record RateQueueEntryDto(
        [Required] int Rating,
        string? Comment
    );
        public record CreateQueueEntryDto(
            [property: Required] int restaurantID,
            [property: Required] int userID,
            [property: Required] int queueTypeID,
            int? partySize,
            string? notes
        );

        public record UpdateQueueEntryDto(
            [property: Required] int restaurantID,
            [property: Required] int userID,
            [property: Required] int queueTypeID,
            int? partySize,
            string? notes
        );

        public record QueueHistoryDto(
            long queueEntryID,
            int restaurantID,
            string? restaurantName,
            int userID,
            int queueTypeID,
            int partySize,
            string status,
            DateTime joinTime,
            string? notes
        );

        // ✅ Allowed statuses
        private static readonly HashSet<string> AllowedStatuses = new(StringComparer.OrdinalIgnoreCase)
        {
            "Waiting", "Called", "InService", "Completed", "Canceled", "NoShow"
        };

        // ✅ Active statuses (EF translate OK with Contains)
        private static readonly string[] ActiveStatuses = new[] { "Waiting", "Called", "InService" };

        // Map entity -> DTO
        private static QueueEntryDto ToDto(QueueEntry q) =>
            new(
                q.QueueEntryID,
                q.RestaurantID,
                q.Restaurant?.Name,
                q.UserID,
                q.User != null ? $"{q.User.FirstName} {q.User.LastName}" : null,
                q.QueueTypeID,
                q.PartySize,
                q.Status ?? "Waiting",
                q.JoinTime,
                q.EstimatedWaitTime,
                q.CurrentPosition ?? 0,
                q.Notes
            );

        // ========================
        // 🔹 GET ALL
        // ========================
        [HttpGet]
        public async Task<ActionResult<IEnumerable<QueueEntryDto>>> GetAll(
            [FromQuery] int page = 1,
            [FromQuery] int pageSize = 20,
            [FromQuery] int? restaurantId = null,
            [FromQuery] string? status = null,
            CancellationToken ct = default)
        {
            page = page <= 0 ? 1 : page;
            pageSize = pageSize is <= 0 or > 100 ? 20 : pageSize;

            IQueryable<QueueEntry> q = _context.QueueEntries
                .AsNoTracking()
                .Include(x => x.Restaurant)
                .Include(x => x.User);

            if (restaurantId is not null)
                q = q.Where(x => x.RestaurantID == restaurantId.Value);

            // filter status (exact string)
            if (!string.IsNullOrWhiteSpace(status))
            {
                var st = status.Trim();
                q = q.Where(x => x.Status != null && x.Status.Trim() == st);
            }

            var total = await q.CountAsync(ct);

            var items = await q
                .OrderBy(x => x.JoinTime)
                .Skip((page - 1) * pageSize)
                .Take(pageSize)
                .Select(x => ToDto(x))
                .ToListAsync(ct);

            Response.Headers["X-Total-Count"] = total.ToString();
            Response.Headers["X-Page"] = page.ToString();
            Response.Headers["X-Page-Size"] = pageSize.ToString();

            return Ok(items);
        }

        // ========================
        // 🔹 GET BY ID
        // ========================
        [HttpGet("{id:long}")]
        public async Task<ActionResult<QueueEntryDto>> Get(long id, CancellationToken ct = default)
        {
            var entry = await _context.QueueEntries
                .AsNoTracking()
                .Include(q => q.Restaurant)
                .Include(q => q.User)
                .FirstOrDefaultAsync(x => x.QueueEntryID == id, ct);

            if (entry == null)
                return NotFound(new { message = $"Không tìm thấy lượt chờ ID = {id}" });

            return Ok(ToDto(entry));
        }

        // ========================
        // 🔹 GET HISTORY BY USER
        // ========================
        [HttpGet("history/{userId:int}")]
        public async Task<ActionResult<IEnumerable<QueueHistoryDto>>> GetHistoryByUser(
            int userId,
            CancellationToken ct = default)
        {
            var query = _context.QueueEntries
                .AsNoTracking()
                .Include(q => q.Restaurant)
                .Where(q => q.UserID == userId)
                .OrderByDescending(q => q.JoinTime);

            var items = await query
                .Select(q => new QueueHistoryDto(
                    q.QueueEntryID,
                    q.RestaurantID,
                    q.Restaurant != null ? q.Restaurant.Name : null,
                    q.UserID,
                    q.QueueTypeID,
                    q.PartySize,
                    q.Status ?? "Waiting",
                    q.JoinTime,
                    q.Notes
                ))
                .ToListAsync(ct);

            return Ok(items);
        }

        // ========================
        // 🔹 CREATE
        // ========================
        [HttpPost]
        public async Task<ActionResult<QueueEntryDto>> Create(
            [FromBody] CreateQueueEntryDto dto,
            CancellationToken ct = default)
        {
            if (!await _context.Restaurants.AnyAsync(r => r.RestaurantID == dto.restaurantID, ct))
                return Conflict(new { message = $"RestaurantID = {dto.restaurantID} không tồn tại." });

            if (!await _context.Users.AnyAsync(u => u.UserID == dto.userID, ct))
                return Conflict(new { message = $"UserID = {dto.userID} không tồn tại." });

            var entry = await _queueService.CreateQueueEntryAsync(
                dto.restaurantID,
                dto.userID,
                dto.queueTypeID,
                dto.partySize ?? 1,
                dto.notes,
                ct
            );

            return CreatedAtAction(nameof(Get), new { id = entry.QueueEntryID }, ToDto(entry));
        }

        // ========================
        // 🔹 GET CURRENT QUEUE STATUS (re-index, active only)
        // ========================
        [HttpGet("current")]
        public async Task<ActionResult<object>> GetCurrentStatus(
            [FromQuery] int restaurantId,
            [FromQuery] int userId,
            CancellationToken ct = default)
        {
            // 1) Lấy danh sách active ticket của NHÀ HÀNG
            var active = await _context.QueueEntries
                .AsNoTracking()
                .Where(q =>
                    q.RestaurantID == restaurantId &&
                    q.Status != null &&
                    ActiveStatuses.Contains(q.Status.Trim())
                )
                .OrderBy(q => q.JoinTime)
                .ToListAsync(ct);

            if (!active.Any())
            {
                return Ok(new
                {
                    currentNumber = 0,
                    yourNumber = 0,
                    ahead = 0,
                    estimatedWait = 0,
                    status = (string?)null
                });
            }

            // 2) Re-index 1..n dựa trên active list
            var indexById = active
                .Select((q, idx) => new { q.QueueEntryID, Position = idx + 1 })
                .ToDictionary(x => x.QueueEntryID, x => x.Position);

            int currentNumber = 1; // thằng đầu hàng là 1 theo re-index

            // 3) Ticket của user trong active list
            var yourTicket = active.FirstOrDefault(q => q.UserID == userId);

            if (yourTicket == null)
            {
                return Ok(new
                {
                    currentNumber,
                    yourNumber = 0,
                    ahead = 0,
                    estimatedWait = 0,
                    status = (string?)null
                });
            }

            int yourNumber = indexById[yourTicket.QueueEntryID];
            int ahead = yourNumber > currentNumber ? yourNumber - currentNumber : 0;
            int est = yourTicket.EstimatedWaitTime ?? 0;

            return Ok(new
            {
                currentNumber,
                yourNumber,
                ahead,
                estimatedWait = est,
                status = yourTicket.Status != null ? yourTicket.Status.Trim() : null
            });
        }

        // ========================
        // 🔹 UPDATE
        // ========================
        [HttpPut("{id:long}")]
        public async Task<IActionResult> Update(
            long id,
            [FromBody] UpdateQueueEntryDto dto,
            CancellationToken ct = default)
        {
            var entry = await _context.QueueEntries.FirstOrDefaultAsync(x => x.QueueEntryID == id, ct);
            if (entry == null)
                return NotFound(new { message = $"Không tìm thấy lượt chờ ID = {id}" });

            if (!await _context.Restaurants.AnyAsync(r => r.RestaurantID == dto.restaurantID, ct))
                return Conflict(new { message = $"RestaurantID = {dto.restaurantID} không tồn tại." });

            if (!await _context.Users.AnyAsync(u => u.UserID == dto.userID, ct))
                return Conflict(new { message = $"UserID = {dto.userID} không tồn tại." });

            entry.RestaurantID = dto.restaurantID;
            entry.UserID = dto.userID;
            entry.QueueTypeID = dto.queueTypeID;
            entry.PartySize = dto.partySize ?? entry.PartySize;
            entry.Notes = dto.notes;

            await _context.SaveChangesAsync(ct);
            return NoContent();
        }

        // ========================
        // 🔹 UPDATE STATUS
        // ========================
        [HttpPut("{id:long}/status")]
        public async Task<IActionResult> UpdateStatus(
            long id,
            [FromBody] UpdateQueueStatusDto dto,
            CancellationToken ct = default)
        {
            if (string.IsNullOrWhiteSpace(dto.Status) || !AllowedStatuses.Contains(dto.Status))
                return BadRequest(new { message = $"Trạng thái không hợp lệ. Cho phép: {string.Join(", ", AllowedStatuses)}" });

            var entry = await _context.QueueEntries.FirstOrDefaultAsync(x => x.QueueEntryID == id, ct);
            if (entry == null)
                return NotFound(new { message = $"Không tìm thấy lượt chờ ID = {id}" });

            var oldStatus = entry.Status?.Trim() ?? "";
            var newStatus = dto.Status.Trim();

            bool valid;
            if (newStatus.Equals("Canceled", StringComparison.OrdinalIgnoreCase))
            {
                valid = true; // luôn cho huỷ
            }
            else
            {
                valid = oldStatus switch
                {
                    "Waiting" => newStatus is "Called" or "InService" or "Completed",
                    "Called" => newStatus is "InService" or "Completed",
                    "InService" => newStatus is "Completed",
                    _ => false,
                };
            }

            if (!valid)
                return BadRequest(new { message = $"Không thể chuyển trạng thái từ '{oldStatus}' sang '{newStatus}'." });

            entry.Status = newStatus;
            await _context.SaveChangesAsync(ct);

            // ⭐ Nếu lượt này vừa rời khỏi hàng → recalc + notify
            bool wasInQueue = oldStatus is "Waiting" or "Called" or "InService";
            bool nowOutQueue = newStatus is "Completed" or "Canceled" or "NoShow";

            if (wasInQueue && nowOutQueue)
            {
                await _queueService.RecalculateQueueAndNotifyAsync(
                    entry.RestaurantID,
                    entry.QueueTypeID,
                    ct
                );
            }

            return NoContent();
        }

        // ========================
        // 🔹 GET ACTIVE TICKET
        // ========================
        [HttpGet("active")]
        public async Task<ActionResult<QueueEntryDto>> GetActiveTicket(
            [FromQuery] int userId,
            [FromQuery] int? restaurantId,
            CancellationToken ct = default)
        {
            IQueryable<QueueEntry> query = _context.QueueEntries
                .AsNoTracking()
                .Include(q => q.Restaurant)
                .Include(q => q.User)
                .Where(q =>
                    q.UserID == userId &&
                    q.Status != null &&
                    ActiveStatuses.Contains(q.Status.Trim())
                );

            if (restaurantId.HasValue)
                query = query.Where(q => q.RestaurantID == restaurantId.Value);

            var entry = await query
                .OrderByDescending(q => q.JoinTime)
                .FirstOrDefaultAsync(ct);

            if (entry == null)
                return NotFound(new { message = "Không có ticket active." });

            return Ok(ToDto(entry));
        }
        // ========================
        // 🔹 RATE QUEUE ENTRY (SAVE TO NOTES)
        // ========================
        [HttpPut("{id:long}/rate")]
        public async Task<IActionResult> RateQueueEntry(
            long id,
            [FromBody] RateQueueEntryDto dto,
            CancellationToken ct = default)
        {
            if (dto.Rating < 1 || dto.Rating > 5)
                return BadRequest(new { message = "Rating phải từ 1 đến 5." });

            var entry = await _context.QueueEntries
                .FirstOrDefaultAsync(x => x.QueueEntryID == id, ct);

            if (entry == null)
                return NotFound(new { message = "Không tìm thấy lượt chờ." });

            // ❗ Chỉ cho rate khi đã hoàn thành
            if (!string.Equals(entry.Status, "Completed", StringComparison.OrdinalIgnoreCase))
                return BadRequest(new { message = "Chỉ có thể đánh giá sau khi đã phục vụ xong." });

            var ratingText = $"[Rating:{dto.Rating}] {dto.Comment?.Trim()}";

            if (string.IsNullOrWhiteSpace(entry.Notes))
            {
                entry.Notes = ratingText;
            }
            else
            {
                // tránh rate trùng
                if (entry.Notes.Contains("[Rating:", StringComparison.OrdinalIgnoreCase))
                    return BadRequest(new { message = "Lượt này đã được đánh giá." });

                entry.Notes = $"{entry.Notes} | {ratingText}";
            }

            await _context.SaveChangesAsync(ct);

            return NoContent();
        }


        // ========================
        // 🔹 DELETE
        // ========================
        [HttpDelete("{id:long}")]
        public async Task<IActionResult> Delete(long id, CancellationToken ct = default)
        {
            var removed = await _queueService.RemoveFromQueueAsync(id, ct);
            if (!removed)
                return NotFound(new { message = $"Không tìm thấy lượt chờ ID = {id}" });

            return NoContent();
        }
    }
}
