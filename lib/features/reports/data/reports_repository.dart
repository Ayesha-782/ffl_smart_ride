import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/supabase_service.dart';
import '../models/reports_models.dart';

class MonthlyLeaderboardData {
  final String month;
  final List<LeaderboardEntry> topDrivers;
  final List<LeaderboardEntry> topPassengers;

  const MonthlyLeaderboardData({
    required this.month,
    required this.topDrivers,
    required this.topPassengers,
  });
}

class ReportsRepository {
  SupabaseClient get _supabase => SupabaseService.instance.client;

  String _formatDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// Fetches total CO2 and completed match summary for the specified month (defaults to current month)
  Future<MonthlyCo2Summary> getMonthlyCo2Summary({DateTime? month}) async {
    final target = month ?? DateTime.now();
    try {
      final response = await _supabase.rpc(
        'monthly_co2_summary',
        params: {'p_month': _formatDate(target)},
      );

      if (response is Map<String, dynamic>) {
        final summary = MonthlyCo2Summary.fromJson(response);
        if (summary.totalMatchesCompleted > 0 || summary.totalKgSaved > 0) {
          return summary;
        }
      }
    } catch (_) {}

    // Fallback 1: Calculate directly from ride_completion_log table
    try {
      final logs = await _supabase
          .from('ride_completion_log')
          .select('passenger_count, kg_co2_saved') as List<dynamic>;

      int totalMatches = 0;
      double totalKg = 0.0;
      for (final item in logs) {
        totalMatches += (item['passenger_count'] as num?)?.toInt() ?? 1;
        totalKg += (item['kg_co2_saved'] as num?)?.toDouble() ?? 0.0;
      }

      if (totalMatches > 0 || totalKg > 0) {
        return MonthlyCo2Summary(
          month: '${target.year}-${target.month.toString().padLeft(2, '0')}',
          monthName: 'This Month',
          totalMatchesCompleted: totalMatches,
          totalKgSaved: totalKg,
          totalTonsSaved: totalKg / 1000.0,
        );
      }
    } catch (_) {}

    // Fallback 2: Calculate from completed ride_requests table
    try {
      final completedReqs = await _supabase
          .from('ride_requests')
          .select('id')
          .eq('status', 'completed') as List<dynamic>;

      final count = completedReqs.length;
      if (count > 0) {
        final kg = count * 2.5 * 0.12; // 2.5km distance * 0.12 kg/km
        return MonthlyCo2Summary(
          month: '${target.year}-${target.month.toString().padLeft(2, '0')}',
          monthName: 'This Month',
          totalMatchesCompleted: count,
          totalKgSaved: kg,
          totalTonsSaved: kg / 1000.0,
        );
      }
    } catch (_) {}

    return MonthlyCo2Summary(
      month: '${target.year}-${target.month.toString().padLeft(2, '0')}',
      monthName: 'This Month',
      totalMatchesCompleted: 0,
      totalKgSaved: 0.0,
      totalTonsSaved: 0.0,
    );
  }

  /// Fetches top drivers and top passengers leaderboards for the month
  Future<MonthlyLeaderboardData> getMonthlyLeaderboard({DateTime? month}) async {
    final target = month ?? DateTime.now();
    final response = await _supabase.rpc(
      'monthly_leaderboard',
      params: {'p_month': _formatDate(target)},
    );

    if (response is Map<String, dynamic>) {
      final monthStr = response['month'] as String? ?? '';
      final driversJson = response['top_drivers'] as List<dynamic>? ?? [];
      final passengersJson = response['top_passengers'] as List<dynamic>? ?? [];

      return MonthlyLeaderboardData(
        month: monthStr,
        topDrivers: driversJson
            .map((j) => LeaderboardEntry.fromJson(j as Map<String, dynamic>))
            .toList(),
        topPassengers: passengersJson
            .map((j) => LeaderboardEntry.fromJson(j as Map<String, dynamic>))
            .toList(),
      );
    }

    return MonthlyLeaderboardData(
      month: '${target.year}-${target.month.toString().padLeft(2, '0')}',
      topDrivers: [],
      topPassengers: [],
    );
  }

  /// Fetches historical 6 months CO2 savings trend for charts
  Future<List<MonthlyTrend>> getLast6MonthsTrend() async {
    final response = await _supabase.rpc('get_last_6_months_co2_trend');

    if (response is List<dynamic>) {
      return response
          .map((j) => MonthlyTrend.fromJson(j as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  /// Fetches the logged in user's personal monthly stats
  Future<UserPersonalStats> getUserPersonalStats({
    required String userId,
    DateTime? month,
  }) async {
    final target = month ?? DateTime.now();
    final response = await _supabase.rpc(
      'get_user_monthly_stats',
      params: {
        'p_user_id': userId,
        'p_month': _formatDate(target),
      },
    );

    if (response is Map<String, dynamic>) {
      return UserPersonalStats.fromJson(response);
    }

    return UserPersonalStats(
      userId: userId,
      month: '${target.year}-${target.month.toString().padLeft(2, '0')}',
      ridesGivenAsDriver: 0,
      ridesTakenAsPassenger: 0,
      totalRides: 0,
      personalKgCo2Saved: 0.0,
    );
  }
}
