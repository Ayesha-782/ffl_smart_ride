import 'ride_session.dart';
import 'user_profile.dart';

class PassengerLog {
  final String id;
  final String sessionId;
  final String passengerId;
  final String status; // 'waiting', 'matched', 'cancelled'
  final DateTime requestedAt;
  final RideSession? session;
  final UserProfile? passenger;

  const PassengerLog({
    required this.id,
    required this.sessionId,
    required this.passengerId,
    this.status = 'waiting',
    required this.requestedAt,
    this.session,
    this.passenger,
  });

  factory PassengerLog.fromJson(Map<String, dynamic> json) {
    RideSession? session;
    if (json['ride_sessions'] != null && json['ride_sessions'] is Map<String, dynamic>) {
      session = RideSession.fromJson(json['ride_sessions'] as Map<String, dynamic>);
    }

    UserProfile? passenger;
    if (json['profiles'] != null && json['profiles'] is Map<String, dynamic>) {
      passenger = UserProfile.fromJson(json['profiles'] as Map<String, dynamic>);
    }

    return PassengerLog(
      id: json['id'] as String? ?? '',
      sessionId: json['session_id'] as String? ?? '',
      passengerId: json['passenger_id'] as String? ?? '',
      status: json['status'] as String? ?? 'waiting',
      requestedAt: json['requested_at'] != null
          ? (DateTime.tryParse(json['requested_at'].toString()) ?? DateTime.now())
          : DateTime.now(),
      session: session,
      passenger: passenger,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'session_id': sessionId,
      'passenger_id': passengerId,
      'status': status,
      'requested_at': requestedAt.toIso8601String(),
    };
  }

  bool get isWaiting => status.toLowerCase() == 'waiting';
  bool get isMatched => status.toLowerCase() == 'matched';
  bool get isCancelled => status.toLowerCase() == 'cancelled';
}
