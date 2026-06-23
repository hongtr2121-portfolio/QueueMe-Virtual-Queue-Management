import 'package:flutter/material.dart';
import 'package:queueapp/api/report_service.dart';
import 'package:queueapp/models/report_models.dart';
import 'package:fl_chart/fl_chart.dart';

enum ReportMetric { totalBookings, avgWaitingTime, peakHours }

class ReportsScreen extends StatefulWidget {
  final int restaurantId; // 👈 nhà hàng của admin

  const ReportsScreen({
    super.key,
    required this.restaurantId,
  });

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final _reportService = ReportService();

  ReportMetric _selectedMetric = ReportMetric.totalBookings;

  String _dateRangeLabel = 'Last 7 days';
  DateTimeRange? _currentRange;
  DateTimeRange? _customRange;

  Future<ReportsOverview>? _futureReports;

  @override
  void initState() {
    super.initState();

    // Default: last 7 days
    final now = DateTime.now();
    _currentRange = DateTimeRange(
      start: now.subtract(const Duration(days: 6)),
      end: now.add(const Duration(days: 1)), // [start, end)
    );

    _loadReports();
  }

  void _loadReports() {
    if (_currentRange == null) return;

    final from = _currentRange!.start;
    final to = _currentRange!.end;

    setState(() {
      _futureReports = _reportService.getOverview(
        restaurantId: widget.restaurantId,
        from: from,
        to: to,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF7D9), // nền vàng nhạt giống design
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFCC00),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.assignment_return),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: const Text(
          'REPORTS',
          style: TextStyle(
            letterSpacing: 1.2,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadReports,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildMetricChips(),
          const SizedBox(height: 8),
          _buildFilterRow(context),
          const SizedBox(height: 8),
          Expanded(
            child: FutureBuilder<ReportsOverview>(
              future: _futureReports,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Lỗi tải báo cáo:\n${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: Text('No data'));
                }

                final data = snapshot.data!;
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: _buildReportContent(data),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ======= 3 chips: Total / Avg / Peak =======
  Widget _buildMetricChips() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          _metricChip(
            label: 'Total Bookings',
            metric: ReportMetric.totalBookings,
          ),
          const SizedBox(width: 8),
          _metricChip(
            label: 'Avg Waiting Time',
            metric: ReportMetric.avgWaitingTime,
          ),
          const SizedBox(width: 8),
          _metricChip(
            label: 'Peak Hours',
            metric: ReportMetric.peakHours,
          ),
        ],
      ),
    );
  }

  Widget _metricChip({
    required String label,
    required ReportMetric metric,
  }) {
    final bool selected = _selectedMetric == metric;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedMetric = metric;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF29C36A) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              if (selected)
                BoxShadow(
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                  color: Colors.black.withOpacity(0.15),
                ),
            ],
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: selected ? Colors.white : Colors.black87,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  // ======= Hàng filter: Date range + Export =======
  Widget _buildFilterRow(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          // nút Date Range
          Expanded(
            child: InkWell(
              onTap: () => _showPresetDateSheet(context),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today,
                        size: 18, color: Colors.black87),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _dateRangeLabel,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Icon(Icons.keyboard_arrow_down, size: 18),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // nút Export
          PopupMenuButton<String>(
            offset: const Offset(0, 40),
            onSelected: (value) {
              if (value == 'csv') {
                _showExportSheet('CSV');
              } else if (value == 'pdf') {
                _showExportSheet('PDF');
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'csv',
                child: Text('CSV'),
              ),
              PopupMenuItem(
                value: 'pdf',
                child: Text('PDF'),
              ),
            ],
            child: Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFCC00),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Row(
                children: [
                  Text(
                    'EXPORT',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                  SizedBox(width: 6),
                  Icon(Icons.download, size: 18),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ======= Nội dung chart theo metric (dùng data thật) =======
  Widget _buildReportContent(ReportsOverview data) {
    switch (_selectedMetric) {
      case ReportMetric.totalBookings:
        final dayCount = data.bookingsPerDay.length;
        final dayLabel = dayCount == 1 ? 'day' : 'days';

        return Column(
          children: [
            _reportCard(
              title: 'Total Bookings',
              value: data.totalBookings.toString(),
              subLabel: '$dayCount $dayLabel',
              chart: _buildLineChart(data.bookingsPerDay),
            ),
            const SizedBox(height: 16),
            _reportCard(
              title: 'Served',
              value: data.served.toString(),
              subLabel: '',
              chart: _buildLineChart(data.servedPerDay),
            ),
            const SizedBox(height: 16),
            _reportCard(
              title: 'Canceled/No-show',
              value: data.canceledOrNoShow.toString(),
              subLabel: '',
              chart: _buildLineChart(data.canceledPerDay),
            ),
          ],
        );

      case ReportMetric.avgWaitingTime:
        return _reportCard(
          title: 'Avg Waiting Time',
          value: '${data.avgWaitingMinutes.toStringAsFixed(1)} min',
          subLabel: '',
          chart: _buildLineChart(data.bookingsPerDay), // tạm reuse
        );

      case ReportMetric.peakHours:
        String peakText = '--';
        if (data.peakHours.isNotEmpty) {
          final peak = data.peakHours.reduce(
                (a, b) => a.count >= b.count ? a : b,
          );
          peakText = '${peak.hour.toString().padLeft(2, '0')}:00';
        }
        return _reportCard(
          title: 'Crowded Time',
          value: peakText,
          subLabel: 'Peak hour',
          chart: _buildPeakHoursBarChart(data.peakHours),
        );
    }
  }

  // ======= Card chung cho 3 loại báo cáo =======
  Widget _reportCard({
    required String title,
    required String value,
    required String subLabel,
    required Widget chart,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            blurRadius: 10,
            offset: const Offset(0, 4),
            color: Colors.black.withOpacity(0.08),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style:
                const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const Icon(Icons.more_horiz, size: 20),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              if (subLabel.isNotEmpty)
                Text(
                  subLabel,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.green,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            height: 160,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: const Color(0xFFF4F7FB),
            ),
            padding: const EdgeInsets.all(8),
            child: chart,
          ),
        ],
      ),
    );
  }

  // ======= Line chart cho TimeSeriesPoint – tối giản, đẹp hơn =======
  Widget _buildLineChart(List<TimeSeriesPoint> points) {
    if (points.isEmpty) {
      return const Center(
        child: Text(
          'No data',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
      );
    }

    final spots = List.generate(
      points.length,
          (i) => FlSpot(i.toDouble(), points[i].count.toDouble()),
    );

    final maxY = points
        .map((e) => e.count)
        .reduce((a, b) => a > b ? a : b)
        .toDouble();

    return LineChart(
      LineChartData(
        gridData: FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          // Ẩn toàn bộ trục Y cho sạch
          leftTitles:
          const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
          const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
          const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          // Chỉ hiện nhãn ngày ở trục X
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= points.length) {
                  return const SizedBox.shrink();
                }

                // Chỉ show 3 mốc: đầu, giữa, cuối cho đỡ dày
                final lastIndex = points.length - 1;
                final isEdge = index == 0 || index == lastIndex;
                final isMiddle = points.length > 4 &&
                    index == (lastIndex / 2).round();

                if (!isEdge && !isMiddle && points.length > 3) {
                  return const SizedBox.shrink();
                }

                final date = points[index].date;
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '${date.day}/${date.month}',
                    style: const TextStyle(fontSize: 10),
                  ),
                );
              },
            ),
          ),
        ),
        minX: 0,
        maxX: (points.length - 1).toDouble(),
        minY: 0,
        maxY: maxY == 0 ? 1 : maxY * 1.3,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            barWidth: 3,
            dotData: FlDotData(show: false),
            // màu line + đổ nền nhẹ
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF4FC3F7).withOpacity(0.4),
                  const Color(0xFF4FC3F7).withOpacity(0.0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ======= Bar chart cho Peak Hours – tối giản, giống design =======
  Widget _buildPeakHoursBarChart(List<HourCount> hours) {
    if (hours.isEmpty) {
      return const Center(
        child: Text(
          'No data',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
      );
    }

    final maxCount =
    hours.map((e) => e.count).reduce((a, b) => a > b ? a : b).toDouble();

    return BarChart(
      BarChartData(
        gridData: FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles:
          const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
          const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
          const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 26,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= hours.length) {
                  return const SizedBox.shrink();
                }

                final hour = hours[index].hour;
                // Show nhãn cách quãng cho đỡ dày (mỗi 2 cột)
                if (hours.length > 8 && index.isOdd) {
                  return const SizedBox.shrink();
                }

                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '${hour}h',
                    style: const TextStyle(fontSize: 10),
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: List.generate(
          hours.length,
              (i) => BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: hours[i].count.toDouble(),
                width: 12,
                borderRadius: BorderRadius.circular(6),
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: const [
                    Color(0xFF42A5F5),
                    Color(0xFF1976D2),
                  ],
                ),
              ),
            ],
          ),
        ),
        maxY: maxCount == 0 ? 1 : maxCount * 1.3,
      ),
    );
  }


  // ======= Bottom sheet chọn preset date range =======
  Future<void> _showPresetDateSheet(BuildContext context) async {
    final List<String> presets = [
      'Yesterday',
      'Last 7 days',
      'Last 28 days',
      'This week',
      'This month',
      'Last week',
      'Last month',
      'Custom',
    ];

    String tempSelected = _dateRangeLabel;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Preset date ranges',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: presets.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (ctx, index) {
                    final label = presets[index];
                    return RadioListTile<String>(
                      title: Text(label),
                      value: label,
                      groupValue: tempSelected,
                      onChanged: (value) async {
                        if (value == null) return;

                        if (value == 'Custom') {
                          final picked = await showDateRangePicker(
                            context: context,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
                            initialDateRange: _customRange ??
                                DateTimeRange(
                                  start: DateTime.now()
                                      .subtract(const Duration(days: 6)),
                                  end: DateTime.now()
                                      .add(const Duration(days: 1)),
                                ),
                          );
                          if (picked != null) {
                            setState(() {
                              _customRange = picked;
                              _currentRange = picked;
                              _dateRangeLabel =
                              '${picked.start.day}/${picked.start.month} - '
                                  '${picked.end.day}/${picked.end.month}';
                            });
                            _loadReports();
                            if (context.mounted) Navigator.pop(context);
                          }
                        } else {
                          // preset range
                          final now = DateTime.now();
                          DateTimeRange range;

                          switch (value) {
                            case 'Yesterday':
                              final y = now.subtract(const Duration(days: 1));
                              range = DateTimeRange(
                                start: DateTime(y.year, y.month, y.day),
                                end: DateTime(
                                    y.year, y.month, y.day + 1), // ngày hôm sau
                              );
                              break;
                            case 'Last 7 days':
                              range = DateTimeRange(
                                start:
                                now.subtract(const Duration(days: 6)),
                                end: now.add(const Duration(days: 1)),
                              );
                              break;
                            case 'Last 28 days':
                              range = DateTimeRange(
                                start:
                                now.subtract(const Duration(days: 27)),
                                end: now.add(const Duration(days: 1)),
                              );
                              break;
                            default:
                            // tạm cho các preset khác giống last 7 days
                              range = DateTimeRange(
                                start:
                                now.subtract(const Duration(days: 6)),
                                end: now.add(const Duration(days: 1)),
                              );
                              break;
                          }

                          setState(() {
                            _dateRangeLabel = value;
                            _currentRange = range;
                          });
                          _loadReports();
                          if (context.mounted) Navigator.pop(context);
                        }
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ======= Bottom sheet “Waiting for export…” =======
  void _showExportSheet(String type) {
    showModalBottomSheet(
      context: context,
      isDismissible: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SizedBox(
          height: 200,
          child: Center(
            child: Text(
              'Waiting for Export to $type...',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      },
    );

    // TODO: call API export CSV/PDF, khi xong thì đóng sheet + show snackbar
  }
}
