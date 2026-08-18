class PriorityPassenger {
  final String logId;
  final String passengerId;
  final String passengerName;
  final String employeeId;
  final String phone;
  final String homeAddress;
  final String? pickupStopId;
  final String? pickupStopName;
  final int passengerStopOrder;
  final int driverStopOrder;
  final int stopsAway;
  final DateTime requestedAt;
  final String status;

  const PriorityPassenger({
    required this.logId,
    required this.passengerId,
    required this.passengerName,
    required this.employeeId,
    required this.phone,
    required this.homeAddress,
    this.pickupStopId,
    this.pickupStopName,
    required this.passengerStopOrder,
    required this.driverStopOrder,
    required this.stopsAway,
    required this.requestedAt,
    this.status = 'waiting',
  });

  factory PriorityPassenger.fromJson(Map<String, dynamic> json) {
    return PriorityPassenger(
      logId: json['log_id'] as String? ?? '',
      passengerId: json['passenger_id'] as String? ?? '',
      passengerName: json['passenger_name'] as String? ?? 'Employee',
      employeeId: json['employee_id'] as String? ?? '',
      phone: json['phone'] as String? ?? 'No phone listed',
      homeAddress: json['home_address'] as String? ?? '',
      pickupStopId: json['pickup_stop_id'] as String?,
      pickupStopName: json['pickup_stop_name'] as String?,
      passengerStopOrder: (json['passenger_stop_order'] as num?)?.toInt() ?? 1,
      driverStopOrder: (json['driver_stop_order'] as num?)?.toInt() ?? 1,
      stopsAway: (json['stops_away'] as num?)?.toInt() ?? 0,
      requestedAt: json['requested_at'] != null
          ? (DateTime.tryParse(json['requested_at'].toString()) ?? DateTime.now())
          : DateTime.now(),
      status: json['status'] as String? ?? 'waiting',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'log_id': logId,
      'passenger_id': passengerId,
      'passenger_name': passengerName,
      'employee_id': employeeId,
      'phone': phone,
      'home_address': homeAddress,
      if (pickupStopId != null) 'pickup_stop_id': pickupStopId,
      if (pickupStopName != null) 'pickup_stop_name': pickupStopName,
      'passenger_stop_order': passengerStopOrder,
      'driver_stop_order': driverStopOrder,
      'stops_away': stopsAway,
      'requested_at': requestedAt.toIso8601String(),
      'status': status,
    };
  }

  String get stopsAwayDescription {
    if (stopsAway == 0) {
      return 'Same Stop (Stop #$passengerStopOrder)';
    } else if (stopsAway == 1) {
      return '1 Stop Away (Stop #$passengerStopOrder)';
    } else {
      return '$stopsAway Stops Away (Stop #$passengerStopOrder)';
    }
  }

  String get stopDisplayTitle {
    if (pickupStopName != null && pickupStopName!.isNotEmpty) {
      return 'Stop #$passengerStopOrder: $pickupStopName';
    }
    return 'Stop #$passengerStopOrder';
  }
}
