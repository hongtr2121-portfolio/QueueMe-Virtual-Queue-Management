
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using QueueApp.Data;
using QueueApp.Models;
using System.ComponentModel.DataAnnotations;
using System.Threading;
using System.Threading.Tasks;
using System.Collections.Generic;
using System.Linq;

namespace QueueApp.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    [Produces("application/json")]
    [Authorize(Roles = "Admin")] // ⭐ Bắt buộc Admin cho toàn bộ controller (gỡ ra nếu cần mở tạm)
    public class UsersController : ControllerBase
    {
        private readonly AppDbContext _context;

        public UsersController(AppDbContext context)
        {
            _context = context;
        }

        // ------------------------------
        // DTOs – tránh lộ PasswordHash
        // ------------------------------
        public record UserDto(
            int UserID,
            string Email,
            string? PhoneNumber,
            string? FirstName,
            string? LastName,
            string UserType,
            bool IsVerified);

        public record CreateUserDto(
            [property: Required, EmailAddress] string Email,
            string? PhoneNumber,
            [property: Required] string Password, // controller sẽ hash
            string? FirstName,
            string? LastName,
            [property: Required] string UserType,
            bool IsVerified = false
        );

        public record UpdateUserDto(
            [property: Required, EmailAddress] string Email,
            string? PhoneNumber,
            string? FirstName,
            string? LastName,
            [property: Required] string UserType,
            bool IsVerified
        );

        private static UserDto ToDto(User u) =>
            new(
                u.UserID,
                u.Email ?? string.Empty,
                u.PhoneNumber,
                u.FirstName,
                u.LastName,
                u.UserType ?? "Customer",
                u.IsVerified
            );

        // ------------------------------
        // GET: api/Users?page=1&pageSize=20&search=abc
        // ------------------------------
        [HttpGet]
        public async Task<ActionResult<IEnumerable<UserDto>>> GetUsers(
            [FromQuery] int page = 1,
            [FromQuery] int pageSize = 20,
            [FromQuery] string? search = null,
            CancellationToken ct = default)
        {
            page = page <= 0 ? 1 : page;
            pageSize = pageSize is <= 0 or > 100 ? 20 : pageSize;

            IQueryable<User> query = _context.Users.AsNoTracking();

            if (!string.IsNullOrWhiteSpace(search))
            {
                var s = search.Trim().ToLower();
                query = query.Where(u =>
                    (u.Email != null && u.Email.ToLower().Contains(s)) ||
                    (u.FirstName != null && u.FirstName.ToLower().Contains(s)) ||
                    (u.LastName != null && u.LastName.ToLower().Contains(s))
                );
            }

            var total = await query.CountAsync(ct);

            var users = await query
                .OrderBy(u => u.UserID)
                .Skip((page - 1) * pageSize)
                .Take(pageSize)
                .Select(u => new UserDto(
                    u.UserID,
                    u.Email ?? string.Empty,
                    u.PhoneNumber,
                    u.FirstName,
                    u.LastName,
                    u.UserType ?? "Customer",
                    u.IsVerified
                ))
                .ToListAsync(ct);

            Response.Headers["X-Total-Count"] = total.ToString();
            Response.Headers["X-Page"] = page.ToString();
            Response.Headers["X-Page-Size"] = pageSize.ToString();

            return Ok(users);
        }

        // ------------------------------
        // GET: api/Users/5
        // ------------------------------
        [HttpGet("{id:int}")]
        public async Task<ActionResult<UserDto>> GetUser(int id, CancellationToken ct = default)
        {
            var user = await _context.Users.AsNoTracking()
                .FirstOrDefaultAsync(u => u.UserID == id, ct);

            if (user == null)
                return NotFound(new { message = $"Không tìm thấy User ID = {id}" });

            return Ok(ToDto(user));
        }

        // ------------------------------
        // POST: api/Users
        // (Admin tạo tài khoản thủ công)
        // ------------------------------
        [HttpPost]
        public async Task<ActionResult<UserDto>> PostUser([FromBody] CreateUserDto dto, CancellationToken ct = default)
        {
            var emailNorm = dto.Email.Trim().ToLowerInvariant();

            if (await _context.Users.AnyAsync(u => u.Email == emailNorm, ct))
                return Conflict(new { message = "Email đã tồn tại." });

            string? phoneNorm = null;
            if (!string.IsNullOrWhiteSpace(dto.PhoneNumber))
            {
                phoneNorm = dto.PhoneNumber.Trim();
                if (await _context.Users.AnyAsync(u => u.PhoneNumber == phoneNorm, ct))
                    return Conflict(new { message = "Số điện thoại đã tồn tại." });
            }

            // Hash mật khẩu tại đây (BCrypt.Net-Next)
            var hashed = BCrypt.Net.BCrypt.HashPassword(dto.Password);

            var user = new User
            {
                Email = emailNorm,
                PhoneNumber = phoneNorm,
                PasswordHash = hashed,
                FirstName = dto.FirstName?.Trim(),
                LastName = dto.LastName?.Trim(),
                UserType = dto.UserType.Trim(),
                IsVerified = dto.IsVerified
            };

            _context.Users.Add(user);
            await _context.SaveChangesAsync(ct);

            return CreatedAtAction(nameof(GetUser), new { id = user.UserID }, ToDto(user));
        }

        // ------------------------------
        // PUT: api/Users/5
        // ------------------------------
        [HttpPut("{id:int}")]
        public async Task<IActionResult> PutUser(int id, [FromBody] UpdateUserDto dto, CancellationToken ct = default)
        {
            var user = await _context.Users.FirstOrDefaultAsync(u => u.UserID == id, ct);
            if (user == null)
                return NotFound(new { message = $"Không tìm thấy User ID = {id}" });

            var emailNorm = dto.Email.Trim().ToLowerInvariant();

            if (await _context.Users.AnyAsync(u => u.UserID != id && u.Email == emailNorm, ct))
                return Conflict(new { message = "Email đã được sử dụng bởi tài khoản khác." });

            string? phoneNorm = null;
            if (!string.IsNullOrWhiteSpace(dto.PhoneNumber))
            {
                phoneNorm = dto.PhoneNumber.Trim();
                if (await _context.Users.AnyAsync(u => u.UserID != id && u.PhoneNumber == phoneNorm, ct))
                    return Conflict(new { message = "Số điện thoại đã được sử dụng bởi tài khoản khác." });
            }

            user.Email = emailNorm;
            user.PhoneNumber = phoneNorm;
            user.FirstName = dto.FirstName?.Trim();
            user.LastName = dto.LastName?.Trim();
            user.UserType = dto.UserType.Trim();
            user.IsVerified = dto.IsVerified;

            await _context.SaveChangesAsync(ct);
            return NoContent();
        }

        // ------------------------------
        // DELETE: api/Users/5
        // ------------------------------
        [HttpDelete("{id:int}")]
        public async Task<IActionResult> DeleteUser(int id, CancellationToken ct = default)
        {
            var user = await _context.Users.FindAsync(new object?[] { id }, ct);
            if (user == null)
                return NotFound(new { message = $"Không tìm thấy User ID = {id}" });

            _context.Users.Remove(user);
            await _context.SaveChangesAsync(ct);
            return NoContent();
        }
    }
}
