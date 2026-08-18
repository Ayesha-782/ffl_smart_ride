import 'ride_session.dart';
import 'user_profile.dart';

class RideMatch {
  final String id;
  final String sessionId;
  final String driverId;
  final String passengerId;
  final String status; // 'pending_confirmation', 'active', 'confirmed', 'completed', 'cancelled', 'expired'
  final DateTime matchedAt;
  final DateTime? cancelledAt;
  final DateTime? confirmationDeadline;
  final RideSession? session;
  final UserProfile? driver;
  final UserProfile? passenger;

  const RideMatch({
    required this.id,
    required this.sessionId,
    required this.driverId,
    required this.passengerId,
    this.status = 'active',
    required this.matchedAt,
    this.cancelledAt,
    this.confirmationDeadline,
    this.session,
    this.driver,
    this.passenger,
  });

  factory RideMatch.fromJson(Map<String, dynamic> json) {
    RideSession? session;
    if (json['ride_sessions'] != null && json['ride_sessions'] is Map<String, dynamic>) {
      session = RideSession.fromJson(json['ride_sessions'] as Map<String, dynamic>);
    }

    UserProfile? driver;
    if (json['driver'] != null && json['driver'] is Map<String, dynamic>) {
      driver = UserProfile.fromJson(json['driver'] as Map<String, dynamic>);
    }

    UserProfile? passenger;
    if (json['passenger'] != null && json['passenger'] is Map<String, dynamic>) {
      passenger = UserProfile.fromJson(json['passenger'] as Map<String, dynamic>);
    }

    return RideMatch(
      id: json['id'] as String? ?? '',
      sessionId: json['session_id'] as String? ?? '',
      driverId: json['driver_id'] as String? ?? '',
      passengerId: json['passenger_id'] as String? ?? '',
      status: json['status'] as String? ?? 'active',
      matchedAt: json['matched_at'] != null
          ? (DateTime.tryParse(json['matched_at'].toString()) ?? DateTime.now())
          : DateTime.now(),
      cancelledAt: json['cancelled_at'] != null
          ? DateTime.tryParse(json['cancelled_at'].toString())
          : null,
      confirmationDeadline: json['confirmation_deadline'] != null
          ? DateTime.tryParse(json['confirmation_deadline'].toString())
          : null,
      session: session,
      driver: driver,
      passenger: passenger,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'session_id': sessionId,
      'driver_id': driverId,
      'passenger_id': passengerId,
      'status': status,
      'matched_at': matchedAt.toIso8601String(),
      if (cancelledAt != null) 'cancelled_at': cancelledAt!.toIso8601String(),
      if (confirmationDeadline != null)
        'confirmation_deadline': confirmationDeadline!.toIso8601String(),
    };
  }

  bool get isPendingConfirmation => status.toLowerCase() == 'pending_confirmation';
  bool get isConfirmed => status.toLowerCase() == 'confirmed' || status.toLowerCase() == 'active';
  bool get isActive => status.toLowerCase() == 'active' || status.toLowerCase() == 'confirmed' || status.toLowerCase() == 'pending_confirmation';
  bool get isCompleted => status.toLowerCase() == 'completed';
  bool get isExpired => status.toLowerCase() == 'expired';
  bool get isCancelled => status.toLowerCase() == 'cancelled';
}
