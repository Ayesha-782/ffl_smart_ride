import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../models/reports_models.dart';

/// Screen 1: Overall stats hero card + 6-month CO₂ trend chart.
class StatsOverviewScreen extends StatelessWidget {
  final MonthlyCo2Summary? summary;
  final List<MonthlyTrend> trends;
  final Future<void> Function() onRefresh;

  const StatsOverviewScreen({
    super.key,
    required this.summary,
    required this.trends,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppColors.primary,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        children: [
          _buildHeroSummaryCard(),
          const SizedBox(height: 24),
          _buildTrendChartCard(),
        ],
      ),
    );
  }

  // ─── Hero Impact Summary ───────────────────────────────────────────

  Widget _buildHeroSummaryCard() {
    final kg = summary?.totalKgSaved ?? 0.0;
    final tons = summary?.totalTonsSaved ?? 0.0;
    final rides = summary?.totalMatchesCompleted ?? 0;
    final monthName = summary?.monthName ?? 'This Month';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.eco, color: Color(0xFF5EEAD4), size: 14),
                    const SizedBox(width: 6),
                    Text(
                      monthName.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              const Icon(Icons.public, color: Colors.white70, size: 22),
            ],
          ),
          const SizedBox(height: 18),
          const Text(
            'Total CO₂ Emissions Prevented',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                kg.toStringAsFixed(1),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 38,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'kg CO₂',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '(${tons.toStringAsFixed(3)} Tons)',
                style: const TextStyle(
                  color: Color(0xFF5EEAD4),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
            ),
            child: Row(
              children: [
                const Icon(Icons.directions_car, color: Colors.white, size: 18),
                const SizedBox(width: 10),
                Text(
                  '$rides Individual Commute Trips Avoided',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── 6-Month Trend Chart ──────────────────────────────────────────

  Widget _buildTrendChartCard() {
    double maxKg = 1.0;
    for (final t in trends) {
      if (t.kgSaved > maxKg) maxKg = t.kgSaved;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '6-Month CO₂ Savings Trend',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Total: ${trends.fold<double>(0.0, (acc, t) => acc + t.kgSaved).toStringAsFixed(1)} kg',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryDark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Bar chart
          SizedBox(
            height: 140,
            child: trends.isEmpty
                ? const Center(child: Text('No trend data available'))
                : Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: trends.map((trend) {
                      final ratio =
                          (trend.kgSaved / maxKg).clamp(0.08, 1.0);
                      final isCurrentMonth = trend == trends.last;

                      return Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            trend.kgSaved > 0
                                ? '${trend.kgSaved.toStringAsFixed(1)}kg'
                                : '0',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isCurrentMonth
                                  ? AppColors.primaryDark
                                  : AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            width: 28,
                            height: 80 * ratio,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: isCurrentMonth
                                    ? [
                                        AppColors.primary,
                                        AppColors.primaryAccent,
                                      ]
                                    : [
                                        const Color(0xFFE2E8F0),
                                        const Color(0xFFCBD5E1),
                                      ],
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            trend.monthShort,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isCurrentMonth
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: isCurrentMonth
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }
}
