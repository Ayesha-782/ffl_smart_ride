import 'ride_session.dart';
import 'user_profile.dart';

class DriverAvailability {
  final String id;
  final String sessionId;
  final String driverId;
  final int seatsOffered;
  final int seatsRemaining;
  final String status; // 'active', 'cancelled'
  final DateTime? createdAt;
  final RideSession? session;
  final UserProfile? driver;

  const DriverAvailability({
    required this.id,
    required this.sessionId,
    required this.driverId,
    required this.seatsOffered,
    required this.seatsRemaining,
    this.status = 'active',
    this.createdAt,
    this.session,
    this.driver,
  });

  factory DriverAvailability.fromJson(Map<String, dynamic> json) {
    RideSession? session;
    if (json['ride_sessions'] != null && json['ride_sessions'] is Map<String, dynamic>) {
      session = RideSession.fromJson(json['ride_sessions'] as Map<String, dynamic>);
    }

    UserProfile? driver;
    if (json['profiles'] != null && json['profiles'] is Map<String, dynamic>) {
      driver = UserProfile.fromJson(json['profiles'] as Map<String, dynamic>);
    }

    return DriverAvailability(
      id: json['id'] as String? ?? '',
      sessionId: json['session_id'] as String? ?? '',
      driverId: json['driver_id'] as String? ?? '',
      seatsOffered: (json['seats_offered'] as num?)?.toInt() ?? 1,
      seatsRemaining: (json['seats_remaining'] as num?)?.toInt() ?? 1,
      status: json['status'] as String? ?? 'active',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      session: session,
      driver: driver,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'session_id': sessionId,
      'driver_id': driverId,
      'seats_offered': seatsOffered,
      'seats_remaining': seatsRemaining,
      'status': status,
    };
  }

  bool get isActive => status.toLowerCase() == 'active';
  bool get hasRemainingSeats => seatsRemaining > 0;
}
