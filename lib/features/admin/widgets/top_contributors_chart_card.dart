import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../data/admin_repository.dart';

class TopContributorsChartCard extends StatelessWidget {
  final List<LeaderboardEntry> contributors;
  final String title;
  final bool isLoading;

  const TopContributorsChartCard({
    super.key,
    required this.contributors,
    this.title = 'Top Contributors',
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
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
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.emoji_events_rounded,
                            size: 16,
                            color: Color(0xFFD97706),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          title,
                          style: const TextStyle(
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
                        'Highest completed carpools in selected period',
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
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.star_rounded, size: 14, color: Color(0xFFD97706)),
                      SizedBox(width: 4),
                      Text(
                        'Leaderboard',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFB45309),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 2. Chart Area
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 20, 16),
            child: SizedBox(
              height: 220,
              child: isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFD97706)),
                      ),
                    )
                  : contributors.isEmpty
                      ? const Center(
                          child: Text(
                            'No contributor data available for this range',
                            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                          ),
                        )
                      : _buildContributorsBarChart(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContributorsBarChart() {
    final list = contributors.take(8).toList();
    final maxRides = list.map((e) => e.rideCount).reduce((a, b) => a > b ? a : b);
    final topBound = maxRides > 0 ? (maxRides * 1.35).ceilToDouble() : 5.0;

    final barGroups = list.asMap().entries.map((entry) {
      final idx = entry.key;
      final e = entry.value;

      return BarChartGroupData(
        x: idx,
        barRods: [
          BarChartRodData(
            toY: e.rideCount.toDouble(),
            gradient: const LinearGradient(
              colors: [
                Color(0xFFD97706),
                Color(0xFFF59E0B),
                Color(0xFFFBBF24),
              ],
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
            ),
            width: 18,
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
          horizontalInterval: topBound > 6 ? (topBound / 4).roundToDouble().clamp(1.0, 1000.0) : 1.0,
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
              reservedSize: 26,
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
              reservedSize: 34,
              getTitlesWidget: (val, meta) {
                final idx = val.toInt();
                if (idx < 0 || idx >= list.length) return const SizedBox.shrink();
                final rawName = list[idx].name;
                final shortName = rawName.split(' ').first;
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    shortName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF475569),
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
              final item = list[group.x];
              return BarTooltipItem(
                '${item.name}\n',
                const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontWeight: FontWeight.w500,
                  fontSize: 11,
                ),
                children: [
                  TextSpan(
                    text: '${item.rideCount} rides  •  ${item.co2SavedKg.toStringAsFixed(1)} kg CO₂',
                    style: const TextStyle(
                      color: Color(0xFFFBBF24),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
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
