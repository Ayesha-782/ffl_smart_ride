import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../data/admin_repository.dart';

enum EnvironmentalMetric {
  co2,
  fuel,
}

class Co2ChartCard extends StatefulWidget {
  final List<TimeSeriesPoint> dataPoints;
  final bool isLoading;

  const Co2ChartCard({
    super.key,
    required this.dataPoints,
    this.isLoading = false,
  });

  @override
  State<Co2ChartCard> createState() => _Co2ChartCardState();
}

class _Co2ChartCardState extends State<Co2ChartCard> {
  EnvironmentalMetric _selectedMetric = EnvironmentalMetric.co2;

  @override
  Widget build(BuildContext context) {
    // Compute stats
    final isCo2 = _selectedMetric == EnvironmentalMetric.co2;
    final multiplier = isCo2 ? 1.0 : (1.0 / 3.0); // 1 Liter fuel saved ~= 3 kg CO2 saved
    final unitLabel = isCo2 ? 'kg CO₂' : 'Liters';

    final values = widget.dataPoints.map((p) => p.value * multiplier).toList();
    final total = values.fold<double>(0.0, (sum, val) => sum + val);
    final avg = values.isNotEmpty ? (total / values.length) : 0.0;
    
    double peak = 0.0;
    DateTime? peakDate;
    for (int i = 0; i < widget.dataPoints.length; i++) {
      final v = widget.dataPoints[i].value * multiplier;
      if (v > peak) {
        peak = v;
        peakDate = widget.dataPoints[i].date;
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
          // 1. Header with Title and Metric Switcher
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: const Color(0xFFECFDF5),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.eco_rounded,
                              size: 16,
                              color: Color(0xFF059669),
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'CO₂ & Environmental Impact',
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
                          'Daily reduction from carpooling operations',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Toggle pill
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildToggleButton(
                        label: 'CO₂ (kg)',
                        isSelected: isCo2,
                        onTap: () => setState(() => _selectedMetric = EnvironmentalMetric.co2),
                      ),
                      _buildToggleButton(
                        label: 'Fuel (L)',
                        isSelected: !isCo2,
                        onTap: () => setState(() => _selectedMetric = EnvironmentalMetric.fuel),
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
                  const Color(0xFFF0FDF4),
                  const Color(0xFFF8FAFC),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFDCFCE7)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildQuickStat(
                  label: 'TOTAL SAVED',
                  value: '${total.toStringAsFixed(1)} $unitLabel',
                  valueColor: const Color(0xFF059669),
                  icon: Icons.savings_outlined,
                ),
                Container(height: 24, width: 1, color: const Color(0xFFE2E8F0)),
                _buildQuickStat(
                  label: 'DAILY AVG',
                  value: '${avg.toStringAsFixed(1)} $unitLabel/d',
                  valueColor: const Color(0xFF0D9488),
                  icon: Icons.trending_up_rounded,
                ),
                Container(height: 24, width: 1, color: const Color(0xFFE2E8F0)),
                _buildQuickStat(
                  label: 'PEAK DAY',
                  value: peak > 0
                      ? '${peak.toStringAsFixed(1)} $unitLabel (${peakDate != null ? DateFormat('MM/dd').format(peakDate) : ''})'
                      : '0.0 $unitLabel',
                  valueColor: const Color(0xFF0284C7),
                  icon: Icons.bolt_rounded,
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 3. Chart Area
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 20, 16),
            child: SizedBox(
              height: 220,
              child: widget.isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF059669)),
                      ),
                    )
                  : widget.dataPoints.isEmpty
                      ? const Center(
                          child: Text(
                            'No completion data available for this range',
                            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                          ),
                        )
                      : _buildLineChart(multiplier, unitLabel),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleButton({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? const Color(0xFF059669) : const Color(0xFF64748B),
          ),
        ),
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

  Widget _buildLineChart(double multiplier, String unitLabel) {
    final spots = widget.dataPoints.asMap().entries.map((entry) {
      final scaled = entry.value.value * multiplier;
      return FlSpot(entry.key.toDouble(), scaled);
    }).toList();

    final maxY = spots.map((e) => e.y).reduce((a, b) => a > b ? a : b);
    final topBound = maxY > 0 ? (maxY * 1.35) : 5.0;

    return LineChart(
      LineChartData(
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
              reservedSize: 34,
              getTitlesWidget: (val, meta) {
                if (val == meta.max || val < 0) return const SizedBox.shrink();
                return Text(
                  val >= 10 ? val.toInt().toString() : val.toStringAsFixed(1),
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
              interval: (widget.dataPoints.length > 7
                  ? (widget.dataPoints.length / 5).ceilToDouble()
                  : 1.0),
              getTitlesWidget: (val, meta) {
                final idx = val.toInt();
                if (idx < 0 || idx >= widget.dataPoints.length) return const SizedBox.shrink();
                final date = widget.dataPoints[idx].date;
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
        minX: 0,
        maxX: (widget.dataPoints.length - 1).toDouble().clamp(0.0, double.infinity),
        minY: 0,
        maxY: topBound,
        lineTouchData: LineTouchData(
          handleBuiltInTouches: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => const Color(0xFF0F172A),
            tooltipRoundedRadius: 10,
            tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final idx = spot.spotIndex;
                final dateStr = (idx >= 0 && idx < widget.dataPoints.length)
                    ? DateFormat('EEE, MMM dd').format(widget.dataPoints[idx].date)
                    : '';
                final count = (idx >= 0 && idx < widget.dataPoints.length)
                    ? widget.dataPoints[idx].count
                    : 0;
                return LineTooltipItem(
                  '$dateStr\n',
                  const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontWeight: FontWeight.w500,
                    fontSize: 11,
                  ),
                  children: [
                    TextSpan(
                      text: '${spot.y.toStringAsFixed(2)} $unitLabel',
                      style: const TextStyle(
                        color: Color(0xFF34D399),
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    TextSpan(
                      text: count > 0 ? ' ($count rides)' : '',
                      style: const TextStyle(
                        color: Color(0xFFCBD5E1),
                        fontSize: 11,
                      ),
                    ),
                  ],
                );
              }).toList();
            },
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.32,
            gradient: const LinearGradient(
              colors: [
                Color(0xFF059669),
                Color(0xFF0D9488),
                Color(0xFF06B6D4),
              ],
            ),
            barWidth: 3.5,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: widget.dataPoints.length <= 15,
              getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                radius: 4,
                color: Colors.white,
                strokeWidth: 2.5,
                strokeColor: const Color(0xFF059669),
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF10B981).withOpacity(0.28),
                  const Color(0xFF06B6D4).withOpacity(0.05),
                  Colors.white.withOpacity(0.0),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
