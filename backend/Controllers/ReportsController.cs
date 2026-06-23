using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using QueueApp.Data;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;

namespace QueueApp.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    [Produces("application/json")]
    public class ReportsController : ControllerBase
    {
        private readonly AppDbContext _context;

        public ReportsController(AppDbContext context)
        {
            _context = context;
        }

        // ===== DTOs – chỉ dùng cho API, KHÔNG liên quan DbContext =====

        public class ReportFilterDto
        {
            public int RestaurantID { get; set; }
            public DateTime From { get; set; }   // inclusive
            public DateTime To { get; set; }     // exclusive
        }

        public class TimeSeriesPointDto
        {
            public DateTime Date { get; set; }
            public int Count { get; set; }
        }

        public class HourCountDto
        {
            public int Hour { get; set; }   // 0–23
            public int Count { get; set; }
        }

        public class ReportsOverviewDto
        {
            public int TotalBookings { get; set; }
            public int Served { get; set; }
            public int CanceledOrNoShow { get; set; }
            public double AvgWaitingMinutes { get; set; }

            public List<TimeSeriesPointDto> BookingsPerDay { get; set; } = new();
            public List<TimeSeriesPointDto> ServedPerDay { get; set; } = new();
            public List<TimeSeriesPointDto> CanceledPerDay { get; set; } = new();
            public List<HourCountDto> PeakHours { get; set; } = new();
        }

        // =======================
        // POST: /api/Reports/overview
        // Body: { restaurantID, from, to }
        // =======================
        [HttpPost("overview")]
        public async Task<ActionResult<ReportsOverviewDto>> GetOverview(
            [FromBody] ReportFilterDto filter,
            CancellationToken ct = default)
        {
            if (filter.From >= filter.To)
                return BadRequest(new { message = "Khoảng ngày không hợp lệ." });

            // Dùng model QueueEntry hiện có: RestaurantID, Status, JoinTime, EstimatedWaitTime...
            var baseQuery = _context.QueueEntries
                .AsNoTracking()
                .Where(q =>
                    q.RestaurantID == filter.RestaurantID &&
                    q.JoinTime >= filter.From &&
                    q.JoinTime < filter.To);

            // ---- Tổng lượt đặt trong khoảng ----
            var totalBookings = await baseQuery.CountAsync(ct);

            // ---- Đã phục vụ (InService + Completed) ----
            var served = await baseQuery
                .Where(q => q.Status == "InService" || q.Status == "Completed")
                .CountAsync(ct);

            // ---- Canceled / NoShow ----
            var canceledOrNoShow = await baseQuery
                .Where(q => q.Status == "Canceled" || q.Status == "NoShow")
                .CountAsync(ct);

            // ---- Average waiting time (phút) – dùng EstimatedWaitTime làm proxy ----
            double avgWaitingMinutes = 0;
            var withEta = baseQuery.Where(q => q.EstimatedWaitTime != null);
            if (await withEta.AnyAsync(ct))
            {
                avgWaitingMinutes = await withEta
                    .AverageAsync(q => (double)q.EstimatedWaitTime!, ct);
            }

            // ---- Time series theo ngày ----
            var bookingsPerDay = await baseQuery
                .GroupBy(q => q.JoinTime.Date)
                .Select(g => new TimeSeriesPointDto
                {
                    Date = g.Key,
                    Count = g.Count()
                })
                .OrderBy(x => x.Date)
                .ToListAsync(ct);

            var servedPerDay = await baseQuery
                .Where(q => q.Status == "InService" || q.Status == "Completed")
                .GroupBy(q => q.JoinTime.Date)
                .Select(g => new TimeSeriesPointDto
                {
                    Date = g.Key,
                    Count = g.Count()
                })
                .OrderBy(x => x.Date)
                .ToListAsync(ct);

            var canceledPerDay = await baseQuery
                .Where(q => q.Status == "Canceled" || q.Status == "NoShow")
                .GroupBy(q => q.JoinTime.Date)
                .Select(g => new TimeSeriesPointDto
                {
                    Date = g.Key,
                    Count = g.Count()
                })
                .OrderBy(x => x.Date)
                .ToListAsync(ct);

            // ---- Peak hours: đếm lượt theo giờ JoinTime ----
            var peakHours = await baseQuery
                .GroupBy(q => q.JoinTime.Hour)
                .Select(g => new HourCountDto
                {
                    Hour = g.Key,
                    Count = g.Count()
                })
                .OrderBy(x => x.Hour)
                .ToListAsync(ct);

            var result = new ReportsOverviewDto
            {
                TotalBookings = totalBookings,
                Served = served,
                CanceledOrNoShow = canceledOrNoShow,
                AvgWaitingMinutes = avgWaitingMinutes,
                BookingsPerDay = bookingsPerDay,
                ServedPerDay = servedPerDay,
                CanceledPerDay = canceledPerDay,
                PeakHours = peakHours
            };

            return Ok(result);
        }
    }
}
