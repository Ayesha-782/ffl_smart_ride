import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../data/reports_repository.dart';
import '../models/reports_models.dart';

/// Screen 2: Monthly leaderboard (top 2 drivers + top 2 passengers)
/// and "Your Contribution This Month" card.
class LeaderboardScreen extends StatelessWidget {
  final MonthlyLeaderboardData? leaderboard;
  final UserPersonalStats? personalStats;
  final Future<void> Function() onRefresh;

  const LeaderboardScreen({
    super.key,
    required this.leaderboard,
    required this.personalStats,
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
          // ── Your Contribution ──────────────────────────────────────
          if (personalStats != null) ...[
            _buildPersonalImpactCard(),
            const SizedBox(height: 24),
          ],

          // ── Monthly Leaderboard ────────────────────────────────────
          _buildLeaderboardSection(),
        ],
      ),
    );
  }

  // ─── Personal Contribution Card ─────────────────────────────────────

  Widget _buildPersonalImpactCard() {
    final stats = personalStats!;
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
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.person_rounded, color: AppColors.primary, size: 18),
              ),
              const SizedBox(width: 10),
              const Text(
                'Your Contribution This Month',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  title: 'Rides Given',
                  value: '${stats.ridesGivenAsDriver}',
                  subtitle: 'As Driver',
                  color: AppColors.primaryDark,
                ),
              ),
              Container(width: 1, height: 44, color: AppColors.border),
              Expanded(
                child: _buildMetricTile(
                  title: 'Rides Taken',
                  value: '${stats.ridesTakenAsPassenger}',
                  subtitle: 'As Passenger',
                  color: const Color(0xFF0284C7),
                ),
              ),
              Container(width: 1, height: 44, color: AppColors.border),
              Expanded(
                child: _buildMetricTile(
                  title: 'Saved CO₂',
                  value: '${stats.personalKgCo2Saved.toStringAsFixed(1)} kg',
                  subtitle: 'Personal Impact',
                  color: AppColors.success,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile({
    required String title,
    required String value,
    required String subtitle,
    required Color color,
  }) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: color,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          subtitle,
          style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  // ─── Leaderboard Section ────────────────────────────────────────────

  Widget _buildLeaderboardSection() {
    // Take only top 2 in each category
    final drivers = (leaderboard?.topDrivers ?? []).take(2).toList();
    final passengers = (leaderboard?.topPassengers ?? []).take(2).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Monthly Commute Leaderboard',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Top carpooling contributors fostering sustainable commute.',
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 18),

        // ── Top Drivers ──────────────────────────────────────────────
        _buildCategoryHeader(
          icon: Icons.directions_car_rounded,
          label: 'Top Drivers',
          color: AppColors.primary,
        ),
        const SizedBox(height: 10),
        if (drivers.isEmpty)
          _buildEmptyState(
            icon: Icons.directions_car_outlined,
            text: 'No completed driver rides this month',
          )
        else
          ...drivers.asMap().entries.map((entry) => Padding(
                padding: EdgeInsets.only(
                    bottom: entry.key < drivers.length - 1 ? 10 : 0),
                child: _buildLeaderboardTile(entry.value, isDriver: true),
              )),

        const SizedBox(height: 22),

        // ── Top Passengers ───────────────────────────────────────────
        _buildCategoryHeader(
          icon: Icons.people_rounded,
          label: 'Top Passengers',
          color: const Color(0xFF0284C7),
        ),
        const SizedBox(height: 10),
        if (passengers.isEmpty)
          _buildEmptyState(
            icon: Icons.people_outline,
            text: 'No completed passenger rides this month',
          )
        else
          ...passengers.asMap().entries.map((entry) => Padding(
                padding: EdgeInsets.only(
                    bottom: entry.key < passengers.length - 1 ? 10 : 0),
                child: _buildLeaderboardTile(entry.value, isDriver: false),
              )),
      ],
    );
  }

  Widget _buildCategoryHeader({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildLeaderboardTile(LeaderboardEntry entry,
      {required bool isDriver}) {
    final rankColor = entry.rank == 1
        ? const Color(0xFFD97706)
        : (entry.rank == 2 ? const Color(0xFF64748B) : const Color(0xFFC2410C));
    final rankBg = entry.rank == 1
        ? const Color(0xFFFEF3C7)
        : (entry.rank == 2 ? const Color(0xFFF1F5F9) : const Color(0xFFFFEDD5));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: entry.rank <= 2
              ? AppColors.primary.withValues(alpha: 0.3)
              : AppColors.border,
          width: entry.rank == 1 ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Rank Badge (Modern pill without emoji medal)
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: rankBg,
              shape: BoxShape.circle,
              border: Border.all(color: rankColor.withValues(alpha: 0.4), width: 1.5),
            ),
            child: Text(
              '#${entry.rank}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: rankColor,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Avatar
          CircleAvatar(
            radius: 18,
            backgroundColor:
                isDriver ? AppColors.primaryLight : const Color(0xFFE0F2FE),
            child: Text(
              entry.fullName.isNotEmpty
                  ? entry.fullName[0].toUpperCase()
                  : 'E',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: isDriver ? AppColors.primaryDark : const Color(0xFF0284C7),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Name & ID
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.fullName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (entry.employeeId.isNotEmpty)
                  Text(
                    'ID: ${entry.employeeId}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),

          // Stats
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${entry.ridesCount} Rides',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryDark,
                ),
              ),
              Text(
                '${entry.co2SavedKg.toStringAsFixed(1)} kg CO₂',
                style: const TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.success),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({required IconData icon, required String text}) {
    return Container(
      padding: const EdgeInsets.all(20),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(icon, size: 36, color: AppColors.textMuted),
          const SizedBox(height: 6),
          Text(
            text,
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
