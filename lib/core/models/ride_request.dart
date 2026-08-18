import 'ride_slot.dart';
import 'user_profile.dart';

class RideRequest {
  final String id;
  final String passengerId;
  final String? driverId;
  final String pickupLocation;
  final String officeLocation;
  final int? pickupStopOrder;
  final DateTime leavingTime;
  final String? additionalNote;
  final String status; // 'pending', 'pending_confirmation', 'accepted', 'confirmed', 'completed', 'cancelled', 'expired'
  final double? pickupLatitude;
  final double? pickupLongitude;
  final double? officeLatitude;
  final double? officeLongitude;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? confirmationDeadline;
  final UserProfile? passenger;
  final UserProfile? driver;

  const RideRequest({
    required this.id,
    required this.passengerId,
    this.driverId,
    required this.pickupLocation,
    required this.officeLocation,
    this.pickupStopOrder,
    required this.leavingTime,
    this.additionalNote,
    this.status = 'pending',
    this.pickupLatitude,
    this.pickupLongitude,
    this.officeLatitude,
    this.officeLongitude,
    this.createdAt,
    this.updatedAt,
    this.confirmationDeadline,
    this.passenger,
    this.driver,
  });

  factory RideRequest.fromJson(Map<String, dynamic> json) {
    UserProfile? passengerProfile;
    if (json['passenger'] != null) {
      if (json['passenger'] is Map<String, dynamic>) {
        passengerProfile = UserProfile.fromJson(json['passenger'] as Map<String, dynamic>);
      } else if (json['passenger'] is List && (json['passenger'] as List).isNotEmpty) {
        passengerProfile = UserProfile.fromJson((json['passenger'] as List).first as Map<String, dynamic>);
      }
    } else if (json['profiles'] != null) {
      if (json['profiles'] is Map<String, dynamic>) {
        passengerProfile = UserProfile.fromJson(json['profiles'] as Map<String, dynamic>);
      } else if (json['profiles'] is List && (json['profiles'] as List).isNotEmpty) {
        passengerProfile = UserProfile.fromJson((json['profiles'] as List).first as Map<String, dynamic>);
      }
    }

    UserProfile? driverProfile;
    if (json['driver'] != null) {
      if (json['driver'] is Map<String, dynamic>) {
        driverProfile = UserProfile.fromJson(json['driver'] as Map<String, dynamic>);
      } else if (json['driver'] is List && (json['driver'] as List).isNotEmpty) {
        driverProfile = UserProfile.fromJson((json['driver'] as List).first as Map<String, dynamic>);
      }
    }

    return RideRequest(
      id: json['id'] as String? ?? '',
      passengerId: json['passenger_id'] as String? ?? '',
      driverId: json['driver_id'] as String?,
      pickupLocation: json['pickup_location'] as String? ?? '',
      officeLocation: json['office_location'] as String? ?? '',
      pickupStopOrder: (json['pickup_stop_order'] as num?)?.toInt(),
      leavingTime: json['leaving_time'] != null
          ? (DateTime.tryParse(json['leaving_time'].toString()) ?? DateTime.now())
          : DateTime.now(),
      additionalNote: json['additional_note'] as String?,
      status: json['status'] as String? ?? 'pending',
      pickupLatitude: (json['pickup_latitude'] as num?)?.toDouble(),
      pickupLongitude: (json['pickup_longitude'] as num?)?.toDouble(),
      officeLatitude: (json['office_latitude'] as num?)?.toDouble(),
      officeLongitude: (json['office_longitude'] as num?)?.toDouble(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
      confirmationDeadline: json['confirmation_deadline'] != null
          ? DateTime.tryParse(json['confirmation_deadline'].toString())
          : null,
      passenger: passengerProfile,
      driver: driverProfile,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'passenger_id': passengerId,
      if (driverId != null) 'driver_id': driverId,
      'pickup_location': pickupLocation,
      'office_location': officeLocation,
      if (pickupStopOrder != null) 'pickup_stop_order': pickupStopOrder,
      'leaving_time': leavingTime.toIso8601String(),
      if (additionalNote != null) 'additional_note': additionalNote,
      'status': status,
      if (pickupLatitude != null) 'pickup_latitude': pickupLatitude,
      if (pickupLongitude != null) 'pickup_longitude': pickupLongitude,
      if (officeLatitude != null) 'office_latitude': officeLatitude,
      if (officeLongitude != null) 'office_longitude': officeLongitude,
      if (confirmationDeadline != null)
        'confirmation_deadline': confirmationDeadline!.toIso8601String(),
    };
  }

  bool get isPendingConfirmation => status == 'pending_confirmation' || status == 'accepted';
  bool get isConfirmed => status == 'confirmed';
  bool get isCompleted => status == 'completed';
  bool get isExpired => status == 'expired' || (isPending && isSlotExpired);
  bool get isCancelled => status == 'cancelled';
  bool get isPending => status == 'pending';

  /// Whether an unaddressed pending ride request has passed its slot window or departure time
  bool get isSlotExpired {
    if (status != 'pending') return false;
    return RideSlot.isSlotExpired(leavingTime.toLocal());
  }

  /// The matched operating slot for this ride request
  RideSlot? get slot => RideSlot.getMatchingSlotForDateTime(leavingTime.toLocal());

  /// Whether an accepted ride offer has passed its 5-minute confirmation deadline
  bool get isConfirmationExpired {
    if (status != 'accepted' && status != 'pending_confirmation') return false;
    if (confirmationDeadline != null) {
      return DateTime.now().toUtc().isAfter(confirmationDeadline!.toUtc());
    }
    final effectiveTime = updatedAt ?? createdAt;
    if (effectiveTime != null) {
      return DateTime.now().toUtc().difference(effectiveTime.toUtc()).inSeconds >= 300;
    }
    return false;
  }

  /// Remaining seconds (0 to 300) for the passenger to confirm the ride offer
  int get remainingConfirmationSeconds {
    if (status != 'accepted' && status != 'pending_confirmation') return 0;
    if (confirmationDeadline != null) {
      final diff = confirmationDeadline!.toUtc().difference(DateTime.now().toUtc()).inSeconds;
      return diff.clamp(0, 300);
    }
    final effectiveTime = updatedAt ?? createdAt;
    if (effectiveTime != null) {
      final elapsed = DateTime.now().toUtc().difference(effectiveTime.toUtc()).inSeconds;
      return (300 - elapsed).clamp(0, 300);
    }
    return 0;
  }

  RideRequest copyWith({
    String? id,
    String? passengerId,
    String? driverId,
    String? pickupLocation,
    String? officeLocation,
    int? pickupStopOrder,
    DateTime? leavingTime,
    String? additionalNote,
    String? status,
    double? pickupLatitude,
    double? pickupLongitude,
    double? officeLatitude,
    double? officeLongitude,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? confirmationDeadline,
    UserProfile? passenger,
    UserProfile? driver,
    bool clearDriver = false,
    bool clearDeadline = false,
  }) {
    return RideRequest(
      id: id ?? this.id,
      passengerId: passengerId ?? this.passengerId,
      driverId: clearDriver ? null : (driverId ?? this.driverId),
      pickupLocation: pickupLocation ?? this.pickupLocation,
      officeLocation: officeLocation ?? this.officeLocation,
      pickupStopOrder: pickupStopOrder ?? this.pickupStopOrder,
      leavingTime: leavingTime ?? this.leavingTime,
      additionalNote: additionalNote ?? this.additionalNote,
      status: status ?? this.status,
      pickupLatitude: pickupLatitude ?? this.pickupLatitude,
      pickupLongitude: pickupLongitude ?? this.pickupLongitude,
      officeLatitude: officeLatitude ?? this.officeLatitude,
      officeLongitude: officeLongitude ?? this.officeLongitude,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      confirmationDeadline: clearDeadline ? null : (confirmationDeadline ?? this.confirmationDeadline),
      passenger: passenger ?? this.passenger,
      driver: clearDriver ? null : (driver ?? this.driver),
    );
  }
}
