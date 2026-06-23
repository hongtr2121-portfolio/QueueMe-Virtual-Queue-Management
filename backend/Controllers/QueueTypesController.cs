using System.Collections.Generic;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using QueueApp.Data;
using QueueApp.Models;

namespace QueueApp.Controllers
{
    [ApiController]
    [Route("api/[controller]")] // -> /api/QueueTypes
    [Produces("application/json")]
    public class QueueTypesController : ControllerBase     // 👈 sửa lại
    {
        private readonly AppDbContext _db;
        private readonly ILogger<QueueTypesController> _logger;

        public QueueTypesController(AppDbContext db, ILogger<QueueTypesController> logger)
        {
            _db = db;
            _logger = logger;
        }

        // ===== DTOs =====
        public record QueueTypeDto(
            int QueueTypeID,
            int RestaurantID,
            string Name,
            int MaxPartySize,
            int StandardServiceDuration,
            bool IsActive
        );

        public record QueueTypeCreateDto(
            int RestaurantID,
            string Name,
            int MaxPartySize,
            int StandardServiceDuration,
            bool IsActive
        );

        public record QueueTypeUpdateDto(
            string Name,
            int MaxPartySize,
            int StandardServiceDuration,
            bool IsActive
        );

        private static QueueTypeDto ToDto(QueueType e) => new(
            e.QueueTypeID,
            e.RestaurantID,
            e.Name,
            e.MaxPartySize ?? 0,
            e.StandardServiceDuration ?? 0,
            e.IsActive
        );

        // ===== GET: /api/QueueTypes/by-restaurant/1 =====
        [HttpGet("by-restaurant/{restaurantId:int}")]
        public async Task<ActionResult<List<QueueTypeDto>>> GetByRestaurant(
            int restaurantId,
            CancellationToken ct = default)
        {
            var list = await _db.QueueTypes
                .Where(q => q.RestaurantID == restaurantId)
                .OrderBy(q => q.MaxPartySize)
                .ToListAsync(ct);

            return list.Select(ToDto).ToList();
        }

        // ===== GET: /api/QueueTypes/5 =====
        [HttpGet("{id:int}")]
        public async Task<ActionResult<QueueTypeDto>> GetOne(int id, CancellationToken ct = default)
        {
            var e = await _db.QueueTypes.FirstOrDefaultAsync(q => q.QueueTypeID == id, ct);
            if (e == null) return NotFound();
            return ToDto(e);
        }

        // ===== POST: /api/QueueTypes =====
        [HttpPost]
        public async Task<ActionResult<QueueTypeDto>> Create(
            [FromBody] QueueTypeCreateDto dto,
            CancellationToken ct = default)
        {
            var restaurantExists = await _db.Restaurants
                .AnyAsync(r => r.RestaurantID == dto.RestaurantID, ct);
            if (!restaurantExists)
            {
                return BadRequest($"Restaurant {dto.RestaurantID} không tồn tại.");
            }

            var entity = new QueueType
            {
                RestaurantID = dto.RestaurantID,
                Name = dto.Name.Trim(),
                MaxPartySize = dto.MaxPartySize,
                StandardServiceDuration = dto.StandardServiceDuration,
                IsActive = dto.IsActive
            };

            _db.QueueTypes.Add(entity);
            await _db.SaveChangesAsync(ct);

            return CreatedAtAction(nameof(GetOne),
                new { id = entity.QueueTypeID },
                ToDto(entity));
        }

        // ===== PUT: /api/QueueTypes/5 =====
        [HttpPut("{id:int}")]
        public async Task<ActionResult<QueueTypeDto>> Update(
            int id,
            [FromBody] QueueTypeUpdateDto dto,
            CancellationToken ct = default)
        {
            var e = await _db.QueueTypes.FirstOrDefaultAsync(q => q.QueueTypeID == id, ct);
            if (e == null) return NotFound();

            e.Name = dto.Name.Trim();
            e.MaxPartySize = dto.MaxPartySize;
            e.StandardServiceDuration = dto.StandardServiceDuration;
            e.IsActive = dto.IsActive;

            await _db.SaveChangesAsync(ct);
            return ToDto(e);
        }

        // ===== PATCH: /api/QueueTypes/5/toggle =====
        [HttpPatch("{id:int}/toggle")]
        public async Task<ActionResult<QueueTypeDto>> ToggleActive(
            int id,
            CancellationToken ct = default)
        {
            var e = await _db.QueueTypes.FirstOrDefaultAsync(q => q.QueueTypeID == id, ct);
            if (e == null) return NotFound();

            e.IsActive = !e.IsActive;
            await _db.SaveChangesAsync(ct);
            return ToDto(e);
        }

        // ===== DELETE: /api/QueueTypes/5 =====
        [HttpDelete("{id:int}")]
        public async Task<IActionResult> Delete(int id, CancellationToken ct = default)
        {
            var e = await _db.QueueTypes.FirstOrDefaultAsync(q => q.QueueTypeID == id, ct);
            if (e == null) return NotFound();

            _db.QueueTypes.Remove(e);
            await _db.SaveChangesAsync(ct);
            return NoContent();
        }
    }
}
