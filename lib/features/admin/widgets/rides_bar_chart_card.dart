import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/admin_repository.dart';

class RidesBarChartCard extends StatelessWidget {
  final List<TimeSeriesPoint> dataPoints;
  final bool isLoading;

  const RidesBarChartCard({
    super.key,
    required this.dataPoints,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final totalRides = dataPoints.fold<int>(0, (sum, p) => sum + p.count);
    final avgRides = dataPoints.isNotEmpty ? (totalRides / dataPoints.length) : 0.0;
    
    int maxRides = 0;
    DateTime? peakDate;
    for (final p in dataPoints) {
      if (p.count > maxRides) {
        maxRides = p.count;
        peakDate = p.date;
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header with Icon and Title
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE0F2FE),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.directions_car_filled_rounded,
                            size: 16,
                            color: Color(0xFF0284C7),
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Completed Rides Activity',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                            letterSpacing: -0.2,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Padding(
                      padding: EdgeInsets.only(left: 36),
                      child: Text(
                        'Daily completed employee carpools',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.bar_chart_rounded, size: 14, color: Color(0xFF0284C7)),
                      SizedBox(width: 4),
                      Text(
                        'Trips',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0284C7),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 2. Highlights Ribbon
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFF0F9FF),
                  const Color(0xFFF8FAFC),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE0F2FE)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildQuickStat(
                  label: 'TOTAL TRIPS',
                  value: '$totalRides rides',
                  valueColor: const Color(0xFF0284C7),
                  icon: Icons.check_circle_outline_rounded,
                ),
                Container(height: 24, width: 1, color: const Color(0xFFE2E8F0)),
                _buildQuickStat(
                  label: 'DAILY AVG',
                  value: '${avgRides.toStringAsFixed(1)} rides/d',
                  valueColor: const Color(0xFF0D9488),
                  icon: Icons.analytics_outlined,
                ),
                Container(height: 24, width: 1, color: const Color(0xFFE2E8F0)),
                _buildQuickStat(
                  label: 'BUSIEST DAY',
                  value: maxRides > 0
                      ? '$maxRides (${peakDate != null ? DateFormat('MM/dd').format(peakDate) : ''})'
                      : '0 rides',
                  valueColor: const Color(0xFF7C3AED),
                  icon: Icons.emoji_events_outlined,
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 3. Bar Chart Area
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 20, 16),
            child: SizedBox(
              height: 220,
              child: isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0284C7)),
                      ),
                    )
                  : dataPoints.isEmpty
                      ? const Center(
                          child: Text(
                            'No rides recorded for this range',
                            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                          ),
                        )
                      : _buildBarChart(maxRides),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStat({
    required String label,
    required String value,
    required Color valueColor,
    required IconData icon,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: valueColor),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: Color(0xFF94A3B8),
                letterSpacing: 0.5,
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: valueColor,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBarChart(int maxVal) {
    final topBound = maxVal > 0 ? (maxVal * 1.35).ceilToDouble() : 5.0;
    final barWidth = dataPoints.length > 20
        ? 6.0
        : dataPoints.length > 10
            ? 12.0
            : 20.0;

    final barGroups = dataPoints.asMap().entries.map((entry) {
      final idx = entry.key;
      final point = entry.value;

      return BarChartGroupData(
        x: idx,
        barRods: [
          BarChartRodData(
            toY: point.count.toDouble(),
            gradient: const LinearGradient(
              colors: [
                Color(0xFF0284C7),
                Color(0xFF0EA5E9),
                Color(0xFF38BDF8),
              ],
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
            ),
            width: barWidth,
            borderRadius: BorderRadius.circular(6),
            backDrawRodData: BackgroundBarChartRodData(
              show: true,
              toY: topBound,
              color: const Color(0xFFF1F5F9),
            ),
          ),
        ],
      );
    }).toList();

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: topBound,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: topBound > 8 ? (topBound / 4).roundToDouble().clamp(1.0, 1000.0) : 1.0,
          getDrawingHorizontalLine: (value) => FlLine(
            color: const Color(0xFFE2E8F0),
            strokeWidth: 1,
            dashArray: [5, 5],
          ),
        ),
        titlesData: FlTitlesData(
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (val, meta) {
                if (val == meta.max || val % 1 != 0 || val < 0) return const SizedBox.shrink();
                return Text(
                  val.toInt().toString(),
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 26,
              interval: (dataPoints.length > 7 ? (dataPoints.length / 5).ceilToDouble() : 1.0),
              getTitlesWidget: (val, meta) {
                final idx = val.toInt();
                if (idx < 0 || idx >= dataPoints.length) return const SizedBox.shrink();
                final date = dataPoints[idx].date;
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    DateFormat('MM/dd').format(date),
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => const Color(0xFF0F172A),
            tooltipRoundedRadius: 10,
            tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final date = dataPoints[group.x].date;
              final rides = rod.toY.toInt();
              return BarTooltipItem(
                '${DateFormat('EEE, MMM dd').format(date)}\n',
                const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontWeight: FontWeight.w500,
                  fontSize: 11,
                ),
                children: [
                  TextSpan(
                    text: '$rides completed ${rides == 1 ? 'ride' : 'rides'}',
                    style: const TextStyle(
                      color: Color(0xFF38BDF8),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        barGroups: barGroups,
      ),
    );
  }
}
