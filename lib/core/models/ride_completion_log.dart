class RideCompletionLog {
  final String id;
  final String? sessionId;
  final String driverId;
  final List<String> passengerIds;
  final int passengerCount;
  final double distanceKm;
  final double emissionFactorKgPerKm;
  final double kgCo2Saved;
  final double litersFuelSaved;
  final DateTime completedAt;

  const RideCompletionLog({
    required this.id,
    this.sessionId,
    required this.driverId,
    required this.passengerIds,
    required this.passengerCount,
    required this.distanceKm,
    required this.emissionFactorKgPerKm,
    required this.kgCo2Saved,
    this.litersFuelSaved = 0.0,
    required this.completedAt,
  });

  /// Factory constructor to parse from Supabase JSON
  factory RideCompletionLog.fromJson(Map<String, dynamic> json) {
    List<String> passengers = [];
    if (json['passenger_ids'] != null) {
      if (json['passenger_ids'] is List) {
        passengers = (json['passenger_ids'] as List)
            .map((e) => e.toString())
            .toList();
      }
    }

    final pCount = (json['passenger_count'] as num?)?.toInt() ??
        (passengers.isNotEmpty ? passengers.length : 1);
    final dist = (json['distance_km'] as num?)?.toDouble() ?? 2.5;
    final fuelVal = (json['liters_fuel_saved'] as num?)?.toDouble();

    return RideCompletionLog(
      id: json['id'] as String? ?? '',
      sessionId: json['session_id'] as String?,
      driverId: json['driver_id'] as String? ?? '',
      passengerIds: passengers,
      passengerCount: pCount,
      distanceKm: dist,
      emissionFactorKgPerKm:
          (json['emission_factor_kg_per_km'] as num?)?.toDouble() ?? 0.12,
      kgCo2Saved: (json['kg_co2_saved'] as num?)?.toDouble() ?? 0.0,
      litersFuelSaved: fuelVal ?? calculateFuelSaved(
        routeDistanceKm: dist,
        fuelConsumptionLPerKm: 0.08,
        passengerCount: pCount,
      ),
      completedAt: json['completed_at'] != null
          ? (DateTime.tryParse(json['completed_at'].toString()) ?? DateTime.now())
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      if (sessionId != null) 'session_id': sessionId,
      'driver_id': driverId,
      'passenger_ids': passengerIds,
      'passenger_count': passengerCount,
      'distance_km': distanceKm,
      'emission_factor_kg_per_km': emissionFactorKgPerKm,
      'kg_co2_saved': kgCo2Saved,
      'liters_fuel_saved': litersFuelSaved,
      'completed_at': completedAt.toUtc().toIso8601String(),
    };
  }

  /// Calculates the CO2 saved for a completed carpool trip.
  ///
  /// Negative inputs are treated as zero rather than propagated. A saving
  /// cannot be negative, and these values feed `ride_completion_log` and the
  /// public leaderboard — a negative result would silently subtract from a
  /// driver's lifetime total rather than fail visibly. `distance_km` and
  /// `emission_factor_kg_per_km` are admin-editable via `app_config`, so a
  /// negative value is reachable through configuration, not just through a bug.
  static double calculateCo2Saved({
    required double routeDistanceKm,
    required double emissionFactorKgPerKm,
    required int passengerCount,
  }) {
    if (routeDistanceKm <= 0 ||
        emissionFactorKgPerKm <= 0 ||
        passengerCount <= 0) {
      return 0.0;
    }
    return routeDistanceKm * emissionFactorKgPerKm * passengerCount;
  }

  /// Calculates the fuel saved (in liters) for a completed carpool trip.
  ///
  /// Negative inputs are treated as zero, for the same reason as
  /// [calculateCo2Saved].
  static double calculateFuelSaved({
    required double routeDistanceKm,
    required double fuelConsumptionLPerKm,
    required int passengerCount,
  }) {
    if (routeDistanceKm <= 0 ||
        fuelConsumptionLPerKm <= 0 ||
        passengerCount <= 0) {
      return 0.0;
    }
    return routeDistanceKm * fuelConsumptionLPerKm * passengerCount;
  }
}
