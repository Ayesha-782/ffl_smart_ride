import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../core/services/supabase_service.dart';
import '../data/reports_repository.dart';
import '../models/reports_models.dart';
import 'stats_overview_screen.dart';
import 'leaderboard_screen.dart';

/// Shell screen with a bottom navigation bar hosting two report tabs:
///   0 – Stats Overview (hero card + 6-month trend)
///   1 – Leaderboard & Your Contribution
class ReportsShell extends StatefulWidget {
  const ReportsShell({super.key});

  @override
  State<ReportsShell> createState() => _ReportsShellState();
}

class _ReportsShellState extends State<ReportsShell> {
  final _reportsRepo = ReportsRepository();
  final _supabase = SupabaseService.instance.client;

  int _currentIndex = 0;
  bool _loading = true;

  MonthlyCo2Summary? _summary;
  MonthlyLeaderboardData? _leaderboard;
  List<MonthlyTrend> _trends = [];
  UserPersonalStats? _personalStats;

  @override
  void initState() {
    super.initState();
    _loadAllReports();
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
        title: Text(
          _currentIndex == 0 ? 'Stats Overview' : 'Leaderboard',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
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
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : IndexedStack(
              index: _currentIndex,
              children: [
                StatsOverviewScreen(
                  summary: _summary,
                  trends: _trends,
                  onRefresh: _loadAllReports,
                ),
                LeaderboardScreen(
                  leaderboard: _leaderboard,
                  personalStats: _personalStats,
                  onRefresh: _loadAllReports,
                ),
              ],
            ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: const Border(top: BorderSide(color: AppColors.border, width: 1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _buildNavItem(
                  index: 0,
                  icon: Icons.insights_rounded,
                  label: 'CO₂ Analytics',
                ),
                const SizedBox(width: 12),
                _buildNavItem(
                  index: 1,
                  icon: Icons.military_tech_outlined,
                  label: 'Leaderboard',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required String label,
  }) {
    final isActive = _currentIndex == index;

    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _currentIndex = index),
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive
                ? AppColors.primaryLight
                : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isActive ? AppColors.primary.withValues(alpha: 0.3) : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 20,
                color: isActive ? AppColors.primaryDark : AppColors.textMuted,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color: isActive ? AppColors.primaryDark : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
