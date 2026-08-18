class MonthlyCo2Summary {
  final String month; // '2026-08'
  final String monthName; // 'August 2026'
  final int totalMatchesCompleted;
  final double totalKgSaved;
  final double totalTonsSaved;

  const MonthlyCo2Summary({
    required this.month,
    required this.monthName,
    required this.totalMatchesCompleted,
    required this.totalKgSaved,
    required this.totalTonsSaved,
  });

  factory MonthlyCo2Summary.fromJson(Map<String, dynamic> json) {
    return MonthlyCo2Summary(
      month: json['month'] as String? ?? '',
      monthName: json['month_name'] as String? ?? 'This Month',
      totalMatchesCompleted: (json['total_matches_completed'] as num?)?.toInt() ?? 0,
      totalKgSaved: (json['total_kg_saved'] as num?)?.toDouble() ?? 0.0,
      totalTonsSaved: (json['total_tons_saved'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'month': month,
      'month_name': monthName,
      'total_matches_completed': totalMatchesCompleted,
      'total_kg_saved': totalKgSaved,
      'total_tons_saved': totalTonsSaved,
    };
  }
}

class LeaderboardEntry {
  final String userId;
  final String fullName;
  final String employeeId;
  final String? avatarUrl;
  final int ridesCount;
  final double co2SavedKg;
  final int rank;

  const LeaderboardEntry({
    required this.userId,
    required this.fullName,
    required this.employeeId,
    this.avatarUrl,
    required this.ridesCount,
    required this.co2SavedKg,
    required this.rank,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntry(
      userId: json['user_id'] as String? ?? '',
      fullName: json['full_name'] as String? ?? 'Employee',
      employeeId: json['employee_id'] as String? ?? '',
      avatarUrl: json['avatar_url'] as String?,
      ridesCount: (json['rides_count'] as num?)?.toInt() ?? 0,
      co2SavedKg: (json['co2_saved_kg'] as num?)?.toDouble() ?? 0.0,
      rank: (json['rank'] as num?)?.toInt() ?? 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'full_name': fullName,
      'employee_id': employeeId,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
      'rides_count': ridesCount,
      'co2_saved_kg': co2SavedKg,
      'rank': rank,
    };
  }

  String get rankMedal {
    if (rank == 1) return '🥇';
    if (rank == 2) return '🥈';
    if (rank == 3) return '🥉';
    return '#$rank';
  }
}

class MonthlyTrend {
  final String monthKey; // '2026-08'
  final String monthShort; // 'Aug'
  final String year; // '2026'
  final int matchCount;
  final double kgSaved;
  final double tonsSaved;

  const MonthlyTrend({
    required this.monthKey,
    required this.monthShort,
    required this.year,
    required this.matchCount,
    required this.kgSaved,
    required this.tonsSaved,
  });

  factory MonthlyTrend.fromJson(Map<String, dynamic> json) {
    return MonthlyTrend(
      monthKey: json['month_key'] as String? ?? '',
      monthShort: json['month_short'] as String? ?? '',
      year: json['year'] as String? ?? '',
      matchCount: (json['match_count'] as num?)?.toInt() ?? 0,
      kgSaved: (json['kg_saved'] as num?)?.toDouble() ?? 0.0,
      tonsSaved: (json['tons_saved'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'month_key': monthKey,
      'month_short': monthShort,
      'year': year,
      'match_count': matchCount,
      'kg_saved': kgSaved,
      'tons_saved': tonsSaved,
    };
  }
}

class UserPersonalStats {
  final String userId;
  final String month;
  final int ridesGivenAsDriver;
  final int ridesTakenAsPassenger;
  final int totalRides;
  final double personalKgCo2Saved;

  const UserPersonalStats({
    required this.userId,
    required this.month,
    required this.ridesGivenAsDriver,
    required this.ridesTakenAsPassenger,
    required this.totalRides,
    required this.personalKgCo2Saved,
  });

  factory UserPersonalStats.fromJson(Map<String, dynamic> json) {
    return UserPersonalStats(
      userId: json['user_id'] as String? ?? '',
      month: json['month'] as String? ?? '',
      ridesGivenAsDriver: (json['rides_given_as_driver'] as num?)?.toInt() ?? 0,
      ridesTakenAsPassenger: (json['rides_taken_as_passenger'] as num?)?.toInt() ?? 0,
      totalRides: (json['total_rides'] as num?)?.toInt() ?? 0,
      personalKgCo2Saved: (json['personal_kg_co2_saved'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'month': month,
      'rides_given_as_driver': ridesGivenAsDriver,
      'rides_taken_as_passenger': ridesTakenAsPassenger,
      'total_rides': totalRides,
      'personal_kg_co2_saved': personalKgCo2Saved,
    };
  }
}
