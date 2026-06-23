using Microsoft.EntityFrameworkCore;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.IdentityModel.Tokens;
using QueueApp.Data;
using QueueApp.Services;
using QueueApp.Controllers; // chứa class JwtSettings
using System.Text;
using System.Text.Json.Serialization;

var builder = WebApplication.CreateBuilder(args);

// ==========================
// 💾 DB & SERVICES
// ==========================

// 🟢 1. Kết nối SQL Server (CHỈ KHAI BÁO 1 LẦN)
builder.Services.AddDbContext<AppDbContext>(opt =>
    opt.UseSqlServer(builder.Configuration.GetConnectionString("DefaultConnection"))
       .EnableSensitiveDataLogging()  // chỉ nên bật khi DEV
       .EnableDetailedErrors()
);

// 🟢 2. Đăng ký service dùng DI
builder.Services.AddScoped<QueueService>();
builder.Services.AddScoped<JwtService>();
builder.Services.AddScoped<NotificationService>();

// 🟢 3. Controllers + JSON options
builder.Services
    .AddControllers()
    .AddJsonOptions(opt =>
    {
        opt.JsonSerializerOptions.ReferenceHandler = ReferenceHandler.IgnoreCycles;
        opt.JsonSerializerOptions.DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull;
    });

// ==========================
// 📘 Swagger + JWT Bearer
// ==========================
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(o =>
{
    o.SwaggerDoc("v1", new() { Title = "QueueAPI", Version = "v1" });

    // Cho phép nhập Bearer token
    o.AddSecurityDefinition("Bearer", new Microsoft.OpenApi.Models.OpenApiSecurityScheme
    {
        Name = "Authorization",
        Type = Microsoft.OpenApi.Models.SecuritySchemeType.Http,
        Scheme = "bearer",
        BearerFormat = "JWT",
        In = Microsoft.OpenApi.Models.ParameterLocation.Header,
        Description = "Nhập token dạng: Bearer {your JWT}"
    });

    o.AddSecurityRequirement(new Microsoft.OpenApi.Models.OpenApiSecurityRequirement
    {
        {
            new Microsoft.OpenApi.Models.OpenApiSecurityScheme
            {
                Reference = new Microsoft.OpenApi.Models.OpenApiReference
                {
                    Type = Microsoft.OpenApi.Models.ReferenceType.SecurityScheme,
                    Id = "Bearer"
                }
            },
            Array.Empty<string>()
        }
    });
});

// ==========================
// 🌐 CORS
// ==========================
builder.Services.AddCors(options =>
{
    options.AddDefaultPolicy(policy =>
        policy.AllowAnyOrigin()
              .AllowAnyHeader()
              .AllowAnyMethod());
});

// ==========================
// 🔐 JWT Authentication
// ==========================

var jwtSection = builder.Configuration.GetSection("JwtSettings");
builder.Services.Configure<JwtSettings>(jwtSection);

var secret = jwtSection["Secret"];
if (string.IsNullOrEmpty(secret))
{
    Console.WriteLine("❌ Lỗi: Không tìm thấy JwtSettings:Secret trong appsettings.json");
    throw new Exception("❌ JWT Secret missing!");
}

var issuer = jwtSection["Issuer"] ?? "queueapp";
var audience = jwtSection["Audience"] ?? "queueapp-client";

builder.Services
    .AddAuthentication(options =>
    {
        options.DefaultAuthenticateScheme = JwtBearerDefaults.AuthenticationScheme;
        options.DefaultChallengeScheme = JwtBearerDefaults.AuthenticationScheme;
    })
    .AddJwtBearer(options =>
    {
        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidateAudience = true,
            ValidateLifetime = true,
            ValidateIssuerSigningKey = true,
            ValidIssuer = issuer,
            ValidAudience = audience,
            IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(secret)),
            ClockSkew = TimeSpan.Zero,
            RoleClaimType = System.Security.Claims.ClaimTypes.Role
        };

        // Nếu đang test HTTP (không HTTPS) có thể mở dòng dưới:
        // options.RequireHttpsMetadata = false;
    });

// (tuỳ chọn) policy nếu muốn dùng [Authorize(Policy="AdminOnly")]
builder.Services.AddAuthorization(options =>
{
    options.AddPolicy("AdminOnly", policy => policy.RequireRole("Admin"));
});

// ==========================
// 🚀 Build app
// ==========================
builder.WebHost.UseUrls("http://0.0.0.0:5266");
var app = builder.Build();

// ==========================
// 🗄️ Migration + check DB
// ==========================
using (var scope = app.Services.CreateScope())
{
    var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
    try
    {
        db.Database.Migrate();
        Console.WriteLine(db.Database.CanConnect()
            ? "✅ Database connected successfully!"
            : "⚠️ Cannot connect to database.");
    }
    catch (Exception ex)
    {
        Console.WriteLine($"❌ Database migration error: {ex.Message}");
    }
}

// ==========================
// 🌐 Middleware pipeline
// ==========================
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseHttpsRedirection();
app.UseCors();
app.UseAuthentication();
app.UseAuthorization();

app.MapControllers();

app.Run();
