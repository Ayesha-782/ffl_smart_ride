import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../core/services/supabase_service.dart';
import '../data/reports_repository.dart';
import '../models/reports_models.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> with SingleTickerProviderStateMixin {
  final _reportsRepo = ReportsRepository();
  final _supabase = SupabaseService.instance.client;

  late TabController _tabController;
  bool _loading = true;

  MonthlyCo2Summary? _summary;
  MonthlyLeaderboardData? _leaderboard;
  List<MonthlyTrend> _trends = [];
  UserPersonalStats? _personalStats;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted && !_tabController.indexIsChanging) {
        setState(() {});
      }
    });
    _loadAllReports();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllReports() async {
    setState(() => _loading = true);
    final user = _supabase.auth.currentUser;

    try {
      final results = await Future.wait([
        _reportsRepo.getMonthlyCo2Summary(),
        _reportsRepo.getMonthlyLeaderboard(),
        _reportsRepo.getLast6MonthsTrend(),
        if (user != null)
          _reportsRepo.getUserPersonalStats(userId: user.id)
        else
          Future.value(null),
      ]);

      if (!mounted) return;

      setState(() {
        _summary = results[0] as MonthlyCo2Summary?;
        _leaderboard = results[1] as MonthlyLeaderboardData?;
        _trends = (results[2] as List<MonthlyTrend>?) ?? [];
        if (user != null && results[3] != null) {
          _personalStats = results[3] as UserPersonalStats?;
        }
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppExceptions.getErrorMessage(e)),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Environmental Impact & Reports'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _loadAllReports,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Reports',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              onRefresh: _loadAllReports,
              color: AppColors.primary,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                children: [
                  // 1. Hero Impact Summary
                  _buildHeroSummaryCard(),
                  const SizedBox(height: 20),

                  // 2. Personal Contribution Stats
                  if (_personalStats != null) ...[
                    _buildPersonalImpactCard(),
                    const SizedBox(height: 24),
                  ],

                  // 3. 6-Month CO2 Trend Chart
                  _buildTrendChartCard(),
                  const SizedBox(height: 24),

                  // 4. Leaderboard Section
                  _buildLeaderboardSection(),
                ],
              ),
            ),
    );
  }

  Widget _buildHeroSummaryCard() {
    final kg = _summary?.totalKgSaved ?? 0.0;
    final tons = _summary?.totalTonsSaved ?? 0.0;
    final rides = _summary?.totalMatchesCompleted ?? 0;
    final monthName = _summary?.monthName ?? 'This Month';

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

  Widget _buildPersonalImpactCard() {
    final stats = _personalStats!;
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
        const SizedBox(height: 2),
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        Text(
          subtitle,
          style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildTrendChartCard() {
    double maxKg = 1.0;
    for (final t in _trends) {
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
                  'Total: ${_trends.fold<double>(0.0, (acc, t) => acc + t.kgSaved).toStringAsFixed(1)} kg',
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

          // Simple Animated Custom Bar Chart
          SizedBox(
            height: 140,
            child: _trends.isEmpty
                ? const Center(child: Text('No trend data available'))
                : Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: _trends.map((trend) {
                      final ratio = (trend.kgSaved / maxKg).clamp(0.08, 1.0);
                      final isCurrentMonth = trend == _trends.last;

                      return Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            trend.kgSaved > 0 ? '${trend.kgSaved.toStringAsFixed(1)}kg' : '0',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isCurrentMonth ? AppColors.primaryDark : AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            width: 28,
                            height: 80 * ratio,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: isCurrentMonth
                                    ? [AppColors.primary, AppColors.primaryAccent]
                                    : [const Color(0xFFE2E8F0), const Color(0xFFCBD5E1)],
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
                              fontWeight: isCurrentMonth ? FontWeight.bold : FontWeight.normal,
                              color: isCurrentMonth ? AppColors.primary : AppColors.textSecondary,
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

  Widget _buildLeaderboardSection() {
    final drivers = _leaderboard?.topDrivers ?? [];
    final passengers = _leaderboard?.topPassengers ?? [];
    final isDriverTab = _tabController.index == 0;
    final currentEntries = isDriverTab ? drivers : passengers;

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
          'Recognizing employees driving sustainability and carpooling at FFL.',
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 16),

        // Tabs
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFE2E8F0),
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.all(4),
          child: TabBar(
            controller: _tabController,
            onTap: (_) => setState(() {}),
            indicator: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(11),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            labelColor: Colors.white,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorSize: TabBarIndicatorSize.tab,
            tabs: [
              Tab(text: 'Top Drivers (${drivers.length})'),
              Tab(text: 'Top Passengers (${passengers.length})'),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Leaderboard List
        _buildLeaderboardList(currentEntries, isDriver: isDriverTab),
      ],
    );
  }

  Widget _buildLeaderboardList(List<LeaderboardEntry> entries, {required bool isDriver}) {
    if (entries.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isDriver ? Icons.directions_car_outlined : Icons.people_outline,
              size: 40,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: 8),
            Text(
              isDriver ? 'No completed driver rides this month' : 'No completed passenger rides this month',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        for (int i = 0; i < entries.length; i++) ...[
          _buildLeaderboardTile(entries[i], isDriver: isDriver),
          if (i < entries.length - 1) const SizedBox(height: 10),
        ],
        const SizedBox(height: 120),
      ],
    );
  }

  Widget _buildLeaderboardTile(LeaderboardEntry entry, {required bool isDriver}) {
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
          color: entry.rank <= 2 ? AppColors.primary.withValues(alpha: 0.3) : AppColors.border,
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
            backgroundColor: isDriver ? AppColors.primaryLight : const Color(0xFFE0F2FE),
            child: Text(
              entry.fullName.isNotEmpty ? entry.fullName[0].toUpperCase() : 'E',
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
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.success),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
