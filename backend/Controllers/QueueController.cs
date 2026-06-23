using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;
using Microsoft.AspNetCore.Http;
using Microsoft.EntityFrameworkCore;
using QueueApp.Data;
using QueueApp.Models;
using QueueApp.Services;
using System;
using System.Threading;
using System.Threading.Tasks;
using System.Linq; // 👈 THÊM DÒNG NÀY


namespace QueueApp.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    [Produces("application/json")]
    public class QueueController : ControllerBase
    {
        private readonly QueueService _queueService;
        private readonly ILogger<QueueController> _logger;
        private readonly AppDbContext _context;

        public QueueController(
            AppDbContext context,
            QueueService queueService,
            ILogger<QueueController> logger)
        {
            _context = context;
            _queueService = queueService;
            _logger = logger;
        }

        // ----- DTO cho join queue (request) -----
        public record JoinQueueDto(
            int RestaurantID,
            int UserID,
            int QueueTypeID,
            int PartySize,
            string? Notes
        );

        // (record này hiện chưa dùng tới, có thể giữ lại hoặc xoá)
        public record JoinQueueResultDto(
            long QueueEntryID,
            int RestaurantID,
            string RestaurantName,
            int UserID,
            int PartySize,
            int QueueNumber,
            string Status,
            DateTime JoinTime
        );

        // ================== JOIN QUEUE (CREATE) ==================
        // POST: /api/Queue/join
        [HttpPost("join")]
        public async Task<ActionResult> Join(
            [FromBody] JoinQueueDto dto,
            CancellationToken ct = default)
        {
            try
            {
                // validate FK như cũ...
                if (!await _context.Restaurants.AnyAsync(r => r.RestaurantID == dto.RestaurantID, ct))
                    return Conflict(new { message = $"RestaurantID = {dto.RestaurantID} không tồn tại." });

                if (!await _context.Users.AnyAsync(u => u.UserID == dto.UserID, ct))
                    return Conflict(new { message = $"UserID = {dto.UserID} không tồn tại." });

                QueueEntry entry;
                try
                {
                    entry = await _queueService.CreateQueueEntryAsync(
                        dto.RestaurantID,
                        dto.UserID,
                        dto.QueueTypeID,
                        dto.PartySize,
                        dto.Notes,
                        ct
                    );
                }
                catch (InvalidOperationException ex)
                {
                    // user đã có lượt active
                    return Conflict(new { message = ex.Message });
                }

                // tính queueNumber theo nhà hàng
                var queueNumber = await _context.QueueEntries
                    .AsNoTracking()
                    .CountAsync(q =>
                        q.RestaurantID == dto.RestaurantID &&
                        q.QueueEntryID <= entry.QueueEntryID, ct);

                var json = new
            {
                queueEntryID      = entry.QueueEntryID,
                restaurantID      = entry.RestaurantID,
                userID            = entry.UserID,
                queueTypeID       = entry.QueueTypeID,
                partySize         = entry.PartySize,
                status            = entry.Status,
                joinTime          = entry.JoinTime,
                currentPosition   = entry.CurrentPosition,              // STT hiện tại
                estimatedWaitTime = entry.EstimatedWaitTime,
                notes             = entry.Notes,
                queueNumber       = entry.CurrentPosition ?? 0          // nếu vẫn muốn trả thêm field này
            };

                return Ok(json);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Lỗi khi join queue");
                return StatusCode(StatusCodes.Status500InternalServerError,
                    new { message = "Đã xảy ra lỗi máy chủ khi join queue.", error = ex.Message });
            }
        }

             // ================== ADMIN: LIST QUEUE BY RESTAURANT ==================
        // GET: /api/Queue/admin/list?restaurantId=1
        [HttpGet("admin/list")]
        public async Task<IActionResult> AdminList(
            [FromQuery] int restaurantId,
            CancellationToken ct = default)
        {
            // kiểm tra nhà hàng có tồn tại không (cho đẹp)
            var exists = await _context.Restaurants
                .AnyAsync(r => r.RestaurantID == restaurantId, ct);

            if (!exists)
            {
                return NotFound(new { message = $"RestaurantID = {restaurantId} không tồn tại." });
            }

            // Lấy tất cả lượt chờ của nhà hàng đó
            var list = await _context.QueueEntries
                .AsNoTracking()
                .Where(q => q.RestaurantID == restaurantId)
                .OrderBy(q => q.JoinTime)
                .Select(q => new
                {
                    queueEntryID      = q.QueueEntryID,
                    restaurantID      = q.RestaurantID,
                    userID            = q.UserID,
                    queueTypeID       = q.QueueTypeID,
                    partySize         = q.PartySize,
                    status            = q.Status,
                    joinTime          = q.JoinTime,
                    currentPosition   = q.CurrentPosition,
                    estimatedWaitTime = q.EstimatedWaitTime,
                    notes             = q.Notes
                    // 👉 Không đụng model, nên chỉ dùng những field hiện có
                    // Nếu sau này bạn thêm TicketNumber, CustomerName... thì có thể select thêm ở đây
                })
                .ToListAsync(ct);

            return Ok(list);
        }

        // ================== REMOVE FROM QUEUE ==================
        [HttpDelete("{id:long}")]
        [ProducesResponseType(StatusCodes.Status204NoContent)]
        [ProducesResponseType(StatusCodes.Status404NotFound)]
        [ProducesResponseType(StatusCodes.Status400BadRequest)]
        [ProducesResponseType(StatusCodes.Status500InternalServerError)]
        public async Task<IActionResult> RemoveFromQueue(long id, CancellationToken ct = default)
        {
            if (id <= 0)
            {
                _logger.LogWarning("ID lượt chờ không hợp lệ: {Id}", id);
                return BadRequest(new { message = "ID lượt chờ phải lớn hơn 0." });
            }

            try
            {
                var removed = await _queueService.RemoveFromQueueAsync(id, ct);

                if (!removed)
                {
                    _logger.LogInformation("Không tìm thấy lượt chờ có ID = {Id}", id);
                    return NotFound(new { message = $"Không tìm thấy lượt chờ ID = {id}." });
                }

                _logger.LogInformation("Đã xóa lượt chờ ID = {Id} thành công.", id);
                return NoContent();
            }
            catch (OperationCanceledException)
            {
                _logger.LogWarning("Yêu cầu xóa lượt chờ ID = {Id} bị hủy.", id);
                return StatusCode(StatusCodes.Status499ClientClosedRequest,
                    new { message = "Yêu cầu đã bị hủy bởi client." });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Lỗi khi xóa lượt chờ ID = {Id}", id);
                return StatusCode(StatusCodes.Status500InternalServerError,
                    new { message = "Đã xảy ra lỗi máy chủ khi xóa hàng chờ.", error = ex.Message });
            }
        }
    }
}
