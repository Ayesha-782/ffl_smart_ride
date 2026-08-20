import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/models/ride_completion_log.dart';
import '../../../core/models/user_profile.dart';

class AdminDashboardSummary {
  final int totalCompletedRides;
  final double totalCo2SavedKg;
  final double totalCo2SavedTons;
  final double totalFuelSavedLiters;
  final int totalRegisteredUsers;
  final int activeUsers;

  const AdminDashboardSummary({
    required this.totalCompletedRides,
    required this.totalCo2SavedKg,
    required this.totalCo2SavedTons,
    required this.totalFuelSavedLiters,
    required this.totalRegisteredUsers,
    required this.activeUsers,
  });

  factory AdminDashboardSummary.empty() => const AdminDashboardSummary(
        totalCompletedRides: 0,
        totalCo2SavedKg: 0,
        totalCo2SavedTons: 0,
        totalFuelSavedLiters: 0,
        totalRegisteredUsers: 0,
        activeUsers: 0,
      );
}

class LeaderboardEntry {
  final String userId;
  final String name;
  final String email;
  final String employeeId;
  final int rideCount;
  final double co2SavedKg;
  final double fuelSavedLiters;

  const LeaderboardEntry({
    required this.userId,
    required this.name,
    required this.email,
    required this.employeeId,
    required this.rideCount,
    required this.co2SavedKg,
    required this.fuelSavedLiters,
  });
}

class TimeSeriesPoint {
  final DateTime date;
  final double value;
  final int count;

  const TimeSeriesPoint({
    required this.date,
    required this.value,
    this.count = 0,
  });
}

class AdminRepository {
  final SupabaseClient _supabase;

  AdminRepository({SupabaseClient? supabaseClient})
      : _supabase = supabaseClient ?? Supabase.instance.client;

  // ===========================================================================
  // 1. DASHBOARD ANALYTICS & SUMMARY
  // ===========================================================================

  /// Fetches summary stats for cards (completed rides, CO2, fuel, users)
  Future<AdminDashboardSummary> fetchDashboardSummary({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      // 1. Query ride_completion_log
      var query = _supabase.from('ride_completion_log').select();

      if (startDate != null) {
        query = query.gte('completed_at', startDate.toUtc().toIso8601String());
      }
      if (endDate != null) {
        query = query.lte('completed_at', endDate.toUtc().toIso8601String());
      }

      final logsResponse = await query;
      final logs = (logsResponse as List)
          .map((json) => RideCompletionLog.fromJson(json as Map<String, dynamic>))
          .toList();

      final totalRides = logs.length;
      final totalCo2Kg = logs.fold<double>(0.0, (acc, l) => acc + l.kgCo2Saved);
      final totalFuelL = logs.fold<double>(0.0, (acc, l) => acc + l.litersFuelSaved);

      // 2. Query users stats from profiles
      final profilesResponse = await _supabase.from('profiles').select('id, is_active');
      final profilesList = profilesResponse as List;
      final totalUsers = profilesList.length;
      final activeUsers = profilesList.where((p) => (p['is_active'] as bool?) ?? true).length;

      return AdminDashboardSummary(
        totalCompletedRides: totalRides,
        totalCo2SavedKg: totalCo2Kg,
        totalCo2SavedTons: totalCo2Kg / 1000.0,
        totalFuelSavedLiters: totalFuelL,
        totalRegisteredUsers: totalUsers,
        activeUsers: activeUsers,
      );
    } catch (e) {
      return AdminDashboardSummary.empty();
    }
  }

  /// Fetches daily or weekly trend data for CO2 and Fuel savings
  Future<List<TimeSeriesPoint>> fetchSavingsTrends({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      var query = _supabase
          .from('ride_completion_log')
          .select('completed_at, kg_co2_saved, distance_km, passenger_count');

      if (startDate != null) {
        query = query.gte('completed_at', startDate.toUtc().toIso8601String());
      }
      if (endDate != null) {
        query = query.lte('completed_at', endDate.toUtc().toIso8601String());
      }

      final response = await query.order('completed_at', ascending: true) as List;
      final Map<String, double> aggregated = {};
      final Map<String, int> counts = {};

      for (final row in response) {
        if (row['completed_at'] == null) continue;
        final dateStr = (row['completed_at'] as String).substring(0, 10);
        
        var co2 = (row['kg_co2_saved'] as num?)?.toDouble();
        if (co2 == null || co2 <= 0.0) {
          final dist = (row['distance_km'] as num?)?.toDouble() ?? 2.5;
          final pass = (row['passenger_count'] as num?)?.toInt() ?? 1;
          co2 = dist * 0.12 * pass;
        }

        aggregated[dateStr] = (aggregated[dateStr] ?? 0.0) + co2;
        counts[dateStr] = (counts[dateStr] ?? 0) + 1;
      }

      // Generate continuous date spectrum if date range provided
      final now = DateTime.now();
      final effectiveStart = startDate ?? (response.isNotEmpty 
          ? (DateTime.tryParse(response.first['completed_at'].toString().substring(0, 10)) ?? now.subtract(const Duration(days: 6)))
          : now.subtract(const Duration(days: 6)));
      final effectiveEnd = endDate ?? now;

      final List<TimeSeriesPoint> points = [];
      var curr = DateTime(effectiveStart.year, effectiveStart.month, effectiveStart.day);
      final stop = DateTime(effectiveEnd.year, effectiveEnd.month, effectiveEnd.day);

      // Guard against infinite loop if dates are inverted
      if (curr.isAfter(stop)) {
        curr = stop.subtract(const Duration(days: 6));
      }

      while (!curr.isAfter(stop)) {
        final key = DateFormat('yyyy-MM-dd').format(curr);
        points.add(TimeSeriesPoint(
          date: curr,
          value: aggregated[key] ?? 0.0,
          count: counts[key] ?? 0,
        ));
        curr = curr.add(const Duration(days: 1));
      }

      return points;
    } catch (e) {
      return [];
    }
  }

  /// Fetches daily completed rides counts with continuous date sequence
  Future<List<TimeSeriesPoint>> fetchRidesTrends({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      var query = _supabase
          .from('ride_completion_log')
          .select('completed_at');

      if (startDate != null) {
        query = query.gte('completed_at', startDate.toUtc().toIso8601String());
      }
      if (endDate != null) {
        query = query.lte('completed_at', endDate.toUtc().toIso8601String());
      }

      final response = await query.order('completed_at', ascending: true) as List;
      final Map<String, int> counts = {};

      for (final row in response) {
        if (row['completed_at'] == null) continue;
        final dateStr = (row['completed_at'] as String).substring(0, 10);
        counts[dateStr] = (counts[dateStr] ?? 0) + 1;
      }

      final now = DateTime.now();
      final effectiveStart = startDate ?? (response.isNotEmpty 
          ? (DateTime.tryParse(response.first['completed_at'].toString().substring(0, 10)) ?? now.subtract(const Duration(days: 6)))
          : now.subtract(const Duration(days: 6)));
      final effectiveEnd = endDate ?? now;

      final List<TimeSeriesPoint> points = [];
      var curr = DateTime(effectiveStart.year, effectiveStart.month, effectiveStart.day);
      final stop = DateTime(effectiveEnd.year, effectiveEnd.month, effectiveEnd.day);

      if (curr.isAfter(stop)) {
        curr = stop.subtract(const Duration(days: 6));
      }

      while (!curr.isAfter(stop)) {
        final key = DateFormat('yyyy-MM-dd').format(curr);
        final cnt = counts[key] ?? 0;
        points.add(TimeSeriesPoint(
          date: curr,
          value: cnt.toDouble(),
          count: cnt,
        ));
        curr = curr.add(const Duration(days: 1));
      }

      return points;
    } catch (e) {
      return [];
    }
  }

  // ===========================================================================
  // 2. LEADERBOARDS (DRIVERS & PASSENGERS FROM RIDE_COMPLETION_LOG)
  // ===========================================================================

  /// Fetches top drivers by rides given
  Future<List<LeaderboardEntry>> fetchDriverLeaderboard({
    int limit = 10,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      // 1. Fetch profiles for lookup
      final profilesRes = await _supabase.from('profiles').select('id, full_name, email, employee_id');
      final profilesMap = {
        for (var p in (profilesRes as List))
          p['id'] as String: p as Map<String, dynamic>
      };

      // 2. Fetch completion logs
      var query = _supabase.from('ride_completion_log').select();
      if (startDate != null) query = query.gte('completed_at', startDate.toUtc().toIso8601String());
      if (endDate != null) query = query.lte('completed_at', endDate.toUtc().toIso8601String());

      final logs = ((await query) as List)
          .map((j) => RideCompletionLog.fromJson(j as Map<String, dynamic>))
          .toList();

      final Map<String, _DriverAgg> map = {};
      for (final log in logs) {
        if (log.driverId.isEmpty) continue;
        final curr = map[log.driverId] ?? _DriverAgg();
        curr.rideCount += 1;
        curr.co2 += log.kgCo2Saved;
        curr.fuel += log.litersFuelSaved;
        map[log.driverId] = curr;
      }

      final entries = map.entries.map((e) {
        final p = profilesMap[e.key] ?? {};
        return LeaderboardEntry(
          userId: e.key,
          name: p['full_name'] as String? ?? 'Driver (${e.key.substring(0, 5)})',
          email: p['email'] as String? ?? '',
          employeeId: p['employee_id'] as String? ?? '',
          rideCount: e.value.rideCount,
          co2SavedKg: e.value.co2,
          fuelSavedLiters: e.value.fuel,
        );
      }).toList();

      entries.sort((a, b) => b.rideCount.compareTo(a.rideCount));
      return entries.take(limit).toList();
    } catch (e) {
      return [];
    }
  }

  /// Fetches top passengers by rides taken
  Future<List<LeaderboardEntry>> fetchPassengerLeaderboard({
    int limit = 10,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      // 1. Fetch profiles for lookup
      final profilesRes = await _supabase.from('profiles').select('id, full_name, email, employee_id');
      final profilesMap = {
        for (var p in (profilesRes as List))
          p['id'] as String: p as Map<String, dynamic>
      };

      // 2. Fetch completion logs
      var query = _supabase.from('ride_completion_log').select();
      if (startDate != null) query = query.gte('completed_at', startDate.toUtc().toIso8601String());
      if (endDate != null) query = query.lte('completed_at', endDate.toUtc().toIso8601String());

      final logs = ((await query) as List)
          .map((j) => RideCompletionLog.fromJson(j as Map<String, dynamic>))
          .toList();

      final Map<String, _DriverAgg> map = {};
      for (final log in logs) {
        final pShareCo2 = log.passengerCount > 0 ? (log.kgCo2Saved / log.passengerCount) : log.kgCo2Saved;
        final pShareFuel = log.passengerCount > 0 ? (log.litersFuelSaved / log.passengerCount) : log.litersFuelSaved;

        for (final pId in log.passengerIds) {
          if (pId.isEmpty) continue;
          final curr = map[pId] ?? _DriverAgg();
          curr.rideCount += 1;
          curr.co2 += pShareCo2;
          curr.fuel += pShareFuel;
          map[pId] = curr;
        }
      }

      final entries = map.entries.map((e) {
        final p = profilesMap[e.key] ?? {};
        return LeaderboardEntry(
          userId: e.key,
          name: p['full_name'] as String? ?? 'Passenger (${e.key.substring(0, 5)})',
          email: p['email'] as String? ?? '',
          employeeId: p['employee_id'] as String? ?? '',
          rideCount: e.value.rideCount,
          co2SavedKg: e.value.co2,
          fuelSavedLiters: e.value.fuel,
        );
      }).toList();

      entries.sort((a, b) => b.rideCount.compareTo(a.rideCount));
      return entries.take(limit).toList();
    } catch (e) {
      return [];
    }
  }

  // ===========================================================================
  // 3. USER MANAGEMENT & EDGE FUNCTION INVOCATIONS
  // ===========================================================================

  /// Fetches all users from profiles table with vehicle join
  Future<List<UserProfile>> fetchAllUsers({
    String? searchQuery,
    String? roleFilter,
    bool? activeFilter,
  }) async {
    try {
      var query = _supabase.from('profiles').select('*');

      if (roleFilter != null && roleFilter.isNotEmpty && roleFilter != 'all') {
        query = query.eq('role', roleFilter);
      }
      if (activeFilter != null) {
        query = query.eq('is_active', activeFilter);
      }

      final response = await query.order('created_at', ascending: false) as List;

      // Fetch vehicles in a separate call to avoid PostgREST relationship FK requirement
      Map<String, Map<String, dynamic>> vehiclesByUser = {};
      try {
        final vehiclesResponse = await _supabase.from('vehicles').select('*') as List;
        for (final v in vehiclesResponse) {
          if (v is Map<String, dynamic> && v['user_id'] != null) {
            vehiclesByUser[v['user_id'].toString()] = v;
          }
        }
      } catch (_) {}

      var list = response.map((json) {
        final data = Map<String, dynamic>.from(json as Map<String, dynamic>);
        final userId = data['id']?.toString();
        if (userId != null && vehiclesByUser.containsKey(userId)) {
          data['vehicles'] = [vehiclesByUser[userId]];
        }
        return UserProfile.fromJson(data);
      }).toList();

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.trim().toLowerCase();
        list = list.where((u) {
          return u.fullName.toLowerCase().contains(q) ||
              (u.email?.toLowerCase().contains(q) ?? false) ||
              u.employeeId.toLowerCase().contains(q) ||
              (u.nationalId?.toLowerCase().contains(q) ?? false);
        }).toList();
      }

      return list;
    } catch (e) {
      return [];
    }
  }

  /// Adds a new employee user via PostgreSQL RPC (or Edge Function fallback)
  Future<Map<String, dynamic>> addUser({
    required String name,
    required String email,
    required String houseAddress,
    required String nationalId,
    String? employeeId,
    String? phone,
    String? password,
    Map<String, dynamic>? vehicleDetails,
  }) async {
    // 1. Try Native Database RPC
    try {
      final rpcRes = await _supabase.rpc('admin_create_user', params: {
        'p_email': email.trim().toLowerCase(),
        'p_password': password ?? 'FFLSmartRide2025!',
        'p_full_name': name.trim(),
        'p_employee_id': employeeId?.trim() ?? 'EMP-${DateTime.now().millisecondsSinceEpoch % 10000}',
        'p_national_id': nationalId.trim(),
        'p_phone': phone?.trim(),
        'p_home_address': houseAddress.trim(),
        'p_has_vehicle': vehicleDetails != null,
        if (vehicleDetails != null) ...{
          'p_vehicle_type': vehicleDetails['vehicle_type'] ?? 'Car',
          'p_make': vehicleDetails['make'],
          'p_model': vehicleDetails['model'],
          'p_license_plate': vehicleDetails['license_plate'],
          'p_color': vehicleDetails['color'] ?? 'White',
          'p_capacity': vehicleDetails['capacity'] ?? 3,
        },
      });

      if (rpcRes is Map) {
        return Map<String, dynamic>.from(rpcRes);
      }
      return {'success': true, 'data': rpcRes};
    } catch (rpcError) {
      // 2. Fallback to Edge Function if RPC not found or throws
      try {
        final response = await _supabase.functions.invoke(
          'add-user',
          body: {
            'name': name,
            'email': email,
            'house_address': houseAddress,
            'national_id': nationalId,
            'employee_id': employeeId,
            'phone': phone,
            if (password != null && password.isNotEmpty) 'password': password,
            if (vehicleDetails != null) 'vehicle_details': vehicleDetails,
          },
        );

        if (response.status == 200 || response.status == 201) {
          return response.data as Map<String, dynamic>;
        }
      } catch (_) {}

      // Clean, actionable error message
      final msg = rpcError.toString().replaceAll('PostgrestException(', '').replaceAll('Exception: ', '');
      throw Exception(msg);
    }
  }

  /// Deactivates / soft-removes a user via RPC (preserving all historical logs)
  Future<Map<String, dynamic>> removeUser(
    String targetUserId, {
    bool deactivate = true,
  }) async {
    try {
      final rpcRes = await _supabase.rpc('admin_remove_user', params: {
        'p_target_user_id': targetUserId,
        'p_deactivate': deactivate,
      });
      if (rpcRes is Map) {
        return Map<String, dynamic>.from(rpcRes);
      }
      return {'success': true};
    } catch (rpcError) {
      try {
        final response = await _supabase.functions.invoke(
          'remove-user',
          body: {
            'target_user_id': targetUserId,
            'action': deactivate ? 'deactivate' : 'reactivate',
          },
        );
        if (response.status == 200) {
          return response.data as Map<String, dynamic>;
        }
      } catch (_) {}
      throw Exception(rpcError.toString().replaceAll('Exception: ', ''));
    }
  }

  /// Promotes a user to admin (Super Admin only)
  Future<Map<String, dynamic>> addAdmin(String targetUserId) async {
    try {
      final rpcRes = await _supabase.rpc('admin_add_admin', params: {
        'p_target_user_id': targetUserId,
      });
      if (rpcRes is Map) {
        return Map<String, dynamic>.from(rpcRes);
      }
      return {'success': true};
    } catch (rpcError) {
      try {
        final response = await _supabase.functions.invoke(
          'add-admin',
          body: {
            'target_user_id': targetUserId,
          },
        );
        if (response.status == 200) {
          return response.data as Map<String, dynamic>;
        }
      } catch (_) {}
      throw Exception(rpcError.toString().replaceAll('Exception: ', ''));
    }
  }

  /// Demotes an admin back to user (Super Admin only)
  Future<Map<String, dynamic>> removeAdmin(String targetUserId) async {
    try {
      final rpcRes = await _supabase.rpc('admin_remove_admin', params: {
        'p_target_user_id': targetUserId,
      });
      if (rpcRes is Map) {
        return Map<String, dynamic>.from(rpcRes);
      }
      return {'success': true};
    } catch (rpcError) {
      try {
        final response = await _supabase.functions.invoke(
          'remove-admin',
          body: {
            'target_user_id': targetUserId,
          },
        );
        if (response.status == 200) {
          return response.data as Map<String, dynamic>;
        }
      } catch (_) {}
      throw Exception(rpcError.toString().replaceAll('Exception: ', ''));
    }
  }
}

class _DriverAgg {
  int rideCount = 0;
  double co2 = 0.0;
  double fuel = 0.0;
}
