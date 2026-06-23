using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using Microsoft.IdentityModel.Tokens;
using QueueApp.Data;
using QueueApp.Models;
using System;
using System.ComponentModel.DataAnnotations;
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using System.Collections.Generic;

namespace QueueApp.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    [Produces("application/json")]
    public class AuthController : ControllerBase
    {
        private readonly AppDbContext _context;
        private readonly JwtSettings _jwt;

        public AuthController(AppDbContext context, IOptions<JwtSettings> jwtOptions)
        {
            _context = context;
            _jwt = jwtOptions.Value;
        }

        // ----------------------------
        // 🧩 DTOs
        // ----------------------------
        public record RegisterDto(
            [Required, EmailAddress] string Email,
            string? PhoneNumber,
            [Required, MinLength(6)] string Password,
            string? FirstName,
            string? LastName,
            [Required] string UserType // "Admin" | "Customer"
        );

        public record LoginDto(
            [Required, EmailAddress] string Email,
            [Required] string Password
        );

        // 👉 THÊM displayName vào response cho tiện phía Flutter
        public record AuthResponse(
            int UserID,
            string Email,
            string UserType,
            bool IsVerified,
            string Token,
            string DisplayName
        );

        // ----------------------------
        // 🧩 Đăng ký tài khoản
        // ----------------------------
        [HttpPost("register")]
        [AllowAnonymous]
        [ProducesResponseType(StatusCodes.Status201Created)]
        [ProducesResponseType(StatusCodes.Status409Conflict)]
        public async Task<ActionResult<AuthResponse>> Register(
            [FromBody] RegisterDto dto,
            CancellationToken ct = default)
        {
            var emailNorm = dto.Email.Trim().ToLowerInvariant();
            var phoneNorm = string.IsNullOrWhiteSpace(dto.PhoneNumber) ? null : dto.PhoneNumber.Trim();
            var userType = dto.UserType.Trim();

            // Kiểm tra trùng
            if (await _context.Users.AnyAsync(u => u.Email == emailNorm, ct))
                return Conflict(new { message = "Email đã tồn tại." });

            if (!string.IsNullOrEmpty(phoneNorm) &&
                await _context.Users.AnyAsync(u => u.PhoneNumber == phoneNorm, ct))
                return Conflict(new { message = "Số điện thoại đã tồn tại." });

            // Hash mật khẩu
            var hash = BCrypt.Net.BCrypt.HashPassword(dto.Password);

            var user = new User
            {
                Email = emailNorm,
                PhoneNumber = phoneNorm,
                PasswordHash = hash,
                FirstName = dto.FirstName?.Trim(),
                LastName = dto.LastName?.Trim(),
                UserType = userType,
                // ⭐ đặt true luôn cho khỏi bị chặn bên Flutter
                IsVerified = true
            };

            _context.Users.Add(user);
            await _context.SaveChangesAsync(ct);

            var token = GenerateJwt(user);
            var displayName = BuildDisplayName(user);

            var response = new AuthResponse(
                user.UserID,
                user.Email!,
                user.UserType!,
                true,          // luôn true để client không chặn
                token,
                displayName
            );

            var location = $"/api/users/{user.UserID}";
            return Created(location, response);
        }

        // ----------------------------
        // 🔐 Đăng nhập
        // ----------------------------
        [HttpPost("login")]
        [AllowAnonymous]
        public async Task<ActionResult<AuthResponse>> Login(
            [FromBody] LoginDto dto,
            CancellationToken ct = default)
        {
            var emailNorm = dto.Email.Trim().ToLowerInvariant();
            Console.WriteLine($"[LOGIN] emailNorm={emailNorm}");

            var user = await _context.Users.FirstOrDefaultAsync(u => u.Email == emailNorm, ct);

            if (user == null)
            {
                Console.WriteLine("[LOGIN] user == null");
                return Unauthorized(new { message = "Email hoặc mật khẩu không đúng." });
            }

            if (string.IsNullOrEmpty(user.PasswordHash))
            {
                Console.WriteLine("[LOGIN] PasswordHash null/empty");
                return Unauthorized(new { message = "Email hoặc mật khẩu không đúng." });
            }

            var ok = BCrypt.Net.BCrypt.Verify(dto.Password, user.PasswordHash);
            Console.WriteLine($"[LOGIN] verify={ok}");

            if (!ok)
                return Unauthorized(new { message = "Email hoặc mật khẩu không đúng." });

            var token = GenerateJwt(user);
            var displayName = BuildDisplayName(user);

            // ⭐ Trả thêm displayName, isVerified luôn true
            return Ok(new AuthResponse(
                user.UserID,
                user.Email!,
                user.UserType!,
                true,
                token,
                displayName
            ));
        }

        // ----------------------------
        // 🔑 Helper build tên hiển thị
        // ----------------------------
        private string BuildDisplayName(User user)
        {
            var full = $"{user.FirstName} {user.LastName}".Trim();
            if (!string.IsNullOrWhiteSpace(full))
                return full;

            return user.Email ?? "User";
        }

        // ----------------------------
        // 🔑 Sinh JWT token
        // ----------------------------
        private string GenerateJwt(User user)
        {
            var fullName = BuildDisplayName(user);

            var claims = new List<Claim>
            {
                // chuẩn .NET
                new(ClaimTypes.NameIdentifier, user.UserID.ToString()),
                new(ClaimTypes.Email, user.Email ?? string.Empty),
                new(ClaimTypes.Name, fullName),
                new(ClaimTypes.Role, user.UserType ?? "Customer"),

                // claim custom để Flutter đọc dễ hơn
                new("userId", user.UserID.ToString()),
                new("userType", user.UserType ?? "Customer"),
                new("name", fullName),
                new("fullName", fullName),
                new("verified", (user.IsVerified ? "true" : "false"))
            };

            var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(_jwt.Secret));
            var creds = new SigningCredentials(key, SecurityAlgorithms.HmacSha256);

            var token = new JwtSecurityToken(
                issuer: _jwt.Issuer,
                audience: _jwt.Audience,
                claims: claims,
                notBefore: DateTime.UtcNow,
                expires: DateTime.UtcNow.AddMinutes(_jwt.ExpiryMinutes),
                signingCredentials: creds
            );

            return new JwtSecurityTokenHandler().WriteToken(token);
        }
    }

    // ----------------------------
    // ⚙️ Cấu hình JWT
    // ----------------------------
    public class JwtSettings
    {
        public string Secret { get; set; } = string.Empty;
        public string Issuer { get; set; } = "queueapp";
        public string Audience { get; set; } = "queueapp-client";
        public int ExpiryMinutes { get; set; } = 60;
    }
}
