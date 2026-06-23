using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using QueueApp.Data;
using QueueApp.Models;
using System.ComponentModel.DataAnnotations;

namespace QueueApp.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    [Produces("application/json")]
    public class NotificationsController : ControllerBase
    {
        private readonly AppDbContext _context;
        public NotificationsController(AppDbContext context) => _context = context;

        public record NotificationDto(long NotificationID, string Message, string Type,
                                      DateTime Timestamp, bool IsSent, int UserID, long QueueEntryID);
        public record CreateNotificationDto(
            [property: Required, MaxLength(500)] string Message,
            [property: Required, MaxLength(50)] string Type,
            [property: Required] int UserID,
            [property: Required] long QueueEntryID
        );
        public record UpdateNotificationStatusDto([property: Required] bool IsSent);

        private static NotificationDto ToDto(Notification n) =>
            new(n.NotificationID, n.Message, n.Type, n.Timestamp, n.IsSent, n.UserID, n.QueueEntryID);

        // GET: api/Notifications
        [HttpGet]
        public async Task<ActionResult<IEnumerable<NotificationDto>>> GetAll(CancellationToken ct = default)
        {
            var data = await _context.Notifications.AsNoTracking()
                .OrderByDescending(n => n.Timestamp)
                .Select(n => ToDto(n))
                .ToListAsync(ct);
            return Ok(data);
        }

        // GET: api/Notifications/user/5
        [HttpGet("user/{userId:int}")]
        public async Task<ActionResult<IEnumerable<NotificationDto>>> GetByUser(int userId, CancellationToken ct = default)
        {
            var data = await _context.Notifications.AsNoTracking()
                .Where(n => n.UserID == userId)
                .OrderByDescending(n => n.Timestamp)
                .Select(n => ToDto(n))
                .ToListAsync(ct);
            if (!data.Any()) return NotFound(new { message = $"Không có thông báo cho UserID = {userId}" });
            return Ok(data);
        }

        // POST: api/Notifications
        [HttpPost]
        [ProducesResponseType(StatusCodes.Status201Created)]
        [ProducesResponseType(StatusCodes.Status409Conflict)]
        public async Task<ActionResult<NotificationDto>> Create([FromBody] CreateNotificationDto dto, CancellationToken ct = default)
        {
            // FK check
            if (!await _context.Users.AnyAsync(u => u.UserID == dto.UserID, ct))
                return Conflict(new { message = $"UserID = {dto.UserID} không tồn tại." });
            if (!await _context.QueueEntries.AnyAsync(q => q.QueueEntryID == dto.QueueEntryID, ct))
                return Conflict(new { message = $"QueueEntryID = {dto.QueueEntryID} không tồn tại." });

            var n = new Notification
            {
                Message = dto.Message,
                Type = dto.Type,
                Timestamp = DateTime.UtcNow,
                IsSent = false,
                UserID = dto.UserID,
                QueueEntryID = dto.QueueEntryID
            };

            _context.Notifications.Add(n);
            await _context.SaveChangesAsync(ct);
            return CreatedAtAction(nameof(GetAll), new { id = n.NotificationID }, ToDto(n));
        }

        // PUT: api/Notifications/123/status
        [HttpPut("{id:long}/status")]
        [ProducesResponseType(StatusCodes.Status204NoContent)]
        [ProducesResponseType(StatusCodes.Status404NotFound)]
        public async Task<IActionResult> UpdateStatus(long id, [FromBody] UpdateNotificationStatusDto dto, CancellationToken ct = default)
        {
            var n = await _context.Notifications.FirstOrDefaultAsync(x => x.NotificationID == id, ct);
            if (n == null) return NotFound(new { message = $"Không tìm thấy Notification ID = {id}" });

            n.IsSent = dto.IsSent;
            await _context.SaveChangesAsync(ct);
            return NoContent();
        }

        // DELETE: api/Notifications/123
        [HttpDelete("{id:long}")]
        [ProducesResponseType(StatusCodes.Status204NoContent)]
        [ProducesResponseType(StatusCodes.Status404NotFound)]
        public async Task<IActionResult> Delete(long id, CancellationToken ct = default)
        {
            var n = await _context.Notifications.FindAsync(new object?[] { id }, ct);
            if (n == null) return NotFound(new { message = $"Không tìm thấy Notification ID = {id}" });

            _context.Notifications.Remove(n);
            await _context.SaveChangesAsync(ct);
            return NoContent();
        }
    }
}
