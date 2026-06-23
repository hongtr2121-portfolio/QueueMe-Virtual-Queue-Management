using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using QueueApp.Data;
using QueueApp.Models;
using System.ComponentModel.DataAnnotations;
using System; // Math.Abs

namespace QueueApp.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    [Produces("application/json")]
    public class RestaurantsController : ControllerBase
    {
        private readonly AppDbContext _context;
        public RestaurantsController(AppDbContext context) => _context = context;

        // =======================
        // DTOs
        // =======================

        public class CreateRestaurantRequest
        {
            [Required]
            [MaxLength(100)]
            public string Name { get; set; } = default!;

            public string? Address { get; set; }
            public decimal? OverallRating { get; set; }
            public string? OperatingHours { get; set; }
            public int? AdminUserID { get; set; }

            // toạ độ (dùng cho map / Nominatim)
            public double? Latitude { get; set; }
            public double? Longitude { get; set; }
        }

        public class UpdateRestaurantRequest
        {
            [Required]
            [MaxLength(100)]
            public string Name { get; set; } = default!;

            public string? Address { get; set; }
            public decimal? OverallRating { get; set; }
            public string? OperatingHours { get; set; }
            public int? AdminUserID { get; set; }

            public double? Latitude { get; set; }
            public double? Longitude { get; set; }
        }

        public record RestaurantDto(
            int RestaurantID,
            string? Name,
            string? Address,
            decimal? OverallRating,
            int? AdminUserID,
            double? Latitude,
            double? Longitude
        );

        private static RestaurantDto ToDto(Restaurant r) =>
            new(
                r.RestaurantID,
                r.Name,
                r.Address,
                r.OverallRating,
                r.AdminUserID,
                r.Latitude,
                r.Longitude
            );

        // DTO dùng cho ensure-from-osm
        public class EnsureRestaurantFromOsmRequest
        {
            [Required]
            [MaxLength(100)]
            public string Name { get; set; } = default!;

            public string? Address { get; set; }
            public double? Latitude { get; set; }
            public double? Longitude { get; set; }
        }

        public record EnsureRestaurantFromOsmResponse(
            int RestaurantID,
            bool IsNew
        );

        // =======================
        // GET: api/Restaurants?page=&pageSize=&search=
        // =======================
        [HttpGet]
        public async Task<ActionResult<IEnumerable<RestaurantDto>>> GetAll(
            [FromQuery] int page = 1,
            [FromQuery] int pageSize = 20,
            [FromQuery] string? search = null,
            CancellationToken ct = default)
        {
            page = page <= 0 ? 1 : page;
            pageSize = pageSize is <= 0 or > 100 ? 20 : pageSize;

            IQueryable<Restaurant> query = _context.Restaurants.AsNoTracking();

            if (!string.IsNullOrWhiteSpace(search))
            {
                var s = search.Trim();
                query = query.Where(r =>
                    (r.Name != null && r.Name.Contains(s)) ||
                    (r.Address != null && r.Address.Contains(s)));
            }

            var total = await query.CountAsync(ct);

            var items = await query
                .OrderBy(r => r.RestaurantID)
                .Skip((page - 1) * pageSize)
                .Take(pageSize)
                .Select(r => ToDto(r))
                .ToListAsync(ct);

            Response.Headers["X-Total-Count"] = total.ToString();
            Response.Headers["X-Page"] = page.ToString();
            Response.Headers["X-Page-Size"] = pageSize.ToString();

            return Ok(items);
        }

        // =======================
        // GET: api/Restaurants/5
        // =======================
        [HttpGet("{id:int}")]
        public async Task<ActionResult<RestaurantDto>> Get(
            int id,
            CancellationToken ct = default)
        {
            var r = await _context.Restaurants
                .AsNoTracking()
                .FirstOrDefaultAsync(x => x.RestaurantID == id, ct);

            if (r == null)
                return NotFound(new { message = $"Không tìm thấy nhà hàng ID = {id}" });

            return Ok(ToDto(r));
        }

        // =======================
        // POST: api/Restaurants
        // =======================
        [HttpPost]
        public async Task<ActionResult<RestaurantDto>> Create(
            [FromBody] CreateRestaurantRequest dto,
            CancellationToken ct = default)
        {
            if (!ModelState.IsValid)
                return BadRequest(ModelState);

            if (!string.IsNullOrWhiteSpace(dto.Address) &&
                await _context.Restaurants.AnyAsync(
                    r => r.Name == dto.Name && r.Address == dto.Address, ct))
            {
                return Conflict(new { message = "Nhà hàng với tên & địa chỉ này đã tồn tại." });
            }

            if (dto.AdminUserID is not null &&
                !await _context.Users.AnyAsync(u => u.UserID == dto.AdminUserID.Value, ct))
            {
                return Conflict(new { message = $"AdminUserID = {dto.AdminUserID} không tồn tại." });
            }

            var r = new Restaurant
            {
                Name = dto.Name,
                Address = dto.Address,
                OverallRating = dto.OverallRating,
                OperatingHours = dto.OperatingHours,   // ⭐ FIX HERE
                AdminUserID = dto.AdminUserID,
                Latitude = dto.Latitude,
                Longitude = dto.Longitude
            };

            _context.Restaurants.Add(r);
            await _context.SaveChangesAsync(ct);

            return CreatedAtAction(
                nameof(Get),
                new { id = r.RestaurantID },
                ToDto(r)
            );
        }

        // =======================
        // PUT: api/Restaurants/5
        // =======================
        [HttpPut("{id:int}")]
        public async Task<IActionResult> Update(
            int id,
            [FromBody] UpdateRestaurantRequest dto,
            CancellationToken ct = default)
        {
            if (!ModelState.IsValid)
                return BadRequest(ModelState);

            var r = await _context.Restaurants
                .FirstOrDefaultAsync(x => x.RestaurantID == id, ct);

            if (r == null)
                return NotFound(new { message = $"Không tìm thấy nhà hàng ID = {id}" });

            if (dto.AdminUserID is not null &&
                !await _context.Users.AnyAsync(u => u.UserID == dto.AdminUserID.Value, ct))
            {
                return Conflict(new { message = $"AdminUserID = {dto.AdminUserID} không tồn tại." });
            }

            if (!string.IsNullOrWhiteSpace(dto.Address) &&
                await _context.Restaurants.AnyAsync(
                    x => x.RestaurantID != id &&
                         x.Name == dto.Name &&
                         x.Address == dto.Address,
                    ct))
            {
                return Conflict(new { message = "Tên & địa chỉ bị trùng với nhà hàng khác." });
            }

            r.Name = dto.Name;
            r.Address = dto.Address;
            r.OverallRating = dto.OverallRating;
            r.OperatingHours = dto.OperatingHours;   // ⭐ FIX HERE
            r.AdminUserID = dto.AdminUserID;
            r.Latitude = dto.Latitude;
            r.Longitude = dto.Longitude;

            await _context.SaveChangesAsync(ct);
            return NoContent();
        }

        // =======================
        // DELETE: api/Restaurants/5
        // =======================
        [HttpDelete("{id:int}")]
        public async Task<IActionResult> Delete(
            int id,
            CancellationToken ct = default)
        {
            var r = await _context.Restaurants.FindAsync(new object?[] { id }, ct);
            if (r == null)
                return NotFound(new { message = $"Không tìm thấy nhà hàng ID = {id}" });

            _context.Restaurants.Remove(r);
            await _context.SaveChangesAsync(ct);
            return NoContent();
        }

        // =======================
        // GET: api/Restaurants/{id}/queue-stats
        // =======================
        [HttpGet("{id:int}/queue-stats")]
        public async Task<ActionResult<object>> GetQueueStats(
            int id,
            CancellationToken ct = default)
        {
            var exists = await _context.Restaurants.AnyAsync(r => r.RestaurantID == id, ct);
            if (!exists)
                return NotFound(new { message = $"Không có nhà hàng ID = {id}" });

            var waiting = await _context.QueueEntries
                .CountAsync(q => q.RestaurantID == id && q.Status == "Waiting", ct);
            var called = await _context.QueueEntries
                .CountAsync(q => q.RestaurantID == id && q.Status == "Called", ct);
            var done = await _context.QueueEntries
                .CountAsync(q => q.RestaurantID == id && q.Status == "Completed", ct);

            return Ok(new
            {
                restaurantId = id,
                waiting,
                called,
                completed = done
            });
        }

        // =======================
        // POST: api/Restaurants/ensure-from-osm
        // =======================
        [HttpPost("ensure-from-osm")]
        public async Task<ActionResult<EnsureRestaurantFromOsmResponse>> EnsureFromOsm(
            [FromBody] EnsureRestaurantFromOsmRequest dto,
            CancellationToken ct = default)
        {
            if (!ModelState.IsValid)
                return BadRequest(ModelState);

            var nameNorm = dto.Name.Trim();
            var addrNorm = dto.Address?.Trim();

            IQueryable<Restaurant> query = _context.Restaurants;
            Restaurant? existing = null;

            // 1) Ưu tiên check Name + Address
            if (!string.IsNullOrWhiteSpace(addrNorm))
            {
                existing = await query.FirstOrDefaultAsync(
                    r => r.Name == nameNorm && r.Address == addrNorm,
                    ct);
            }

            // 2) Nếu chưa có, check gần toạ độ
            if (existing == null && dto.Latitude.HasValue && dto.Longitude.HasValue)
            {
                var lat = dto.Latitude.Value;
                var lon = dto.Longitude.Value;
                const double tolerance = 0.0005;

                existing = await query.FirstOrDefaultAsync(
                    r => r.Latitude != null && r.Longitude != null &&
                         Math.Abs(r.Latitude!.Value - lat) < tolerance &&
                         Math.Abs(r.Longitude!.Value - lon) < tolerance,
                    ct);
            }

            // 3) Nếu đã tồn tại
            if (existing != null)
            {
                return Ok(new EnsureRestaurantFromOsmResponse(
                    existing.RestaurantID,
                    false
                ));
            }

            // 4) Tạo mới
            var restaurant = new Restaurant
            {
                Name = nameNorm,
                Address = addrNorm,
                OverallRating = null,
                AdminUserID = null,
                Latitude = dto.Latitude,
                Longitude = dto.Longitude
            };

            _context.Restaurants.Add(restaurant);
            await _context.SaveChangesAsync(ct);

            return Ok(new EnsureRestaurantFromOsmResponse(
                restaurant.RestaurantID,
                true
            ));
        }
    }
}
