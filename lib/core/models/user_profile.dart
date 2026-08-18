import 'vehicle.dart';

class UserProfile {
  final String id;
  final String employeeId;
  final String fullName;
  final String? email;
  final String? phone;
  final String? homeAddress;
  final String? pickupStopId;
  final int? pickupStopOrder;
  final String? officeLocation;
  final String? vehicleNumber;
  final bool hasVehicle;
  final Vehicle? vehicle;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const UserProfile({
    required this.id,
    required this.employeeId,
    required this.fullName,
    this.email,
    this.phone,
    this.homeAddress,
    this.pickupStopId,
    this.pickupStopOrder,
    this.officeLocation,
    this.vehicleNumber,
    this.hasVehicle = false,
    this.vehicle,
    this.createdAt,
    this.updatedAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    Vehicle? parsedVehicle;
    if (json['vehicles'] != null) {
      if (json['vehicles'] is Map<String, dynamic>) {
        parsedVehicle = Vehicle.fromJson(json['vehicles'] as Map<String, dynamic>);
      } else if (json['vehicles'] is List && (json['vehicles'] as List).isNotEmpty) {
        parsedVehicle = Vehicle.fromJson((json['vehicles'] as List).first as Map<String, dynamic>);
      }
    }

    return UserProfile(
      id: json['id'] as String? ?? '',
      employeeId: json['employee_id'] as String? ?? '',
      fullName: json['full_name'] as String? ?? '',
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      homeAddress: json['home_address'] as String?,
      pickupStopId: json['pickup_stop_id'] as String?,
      pickupStopOrder: (json['pickup_stop_order'] as num?)?.toInt(),
      officeLocation: json['office_location'] as String?,
      vehicleNumber: json['vehicle_number'] as String?,
      hasVehicle: (json['has_vehicle'] as bool?) ??
          (parsedVehicle != null ||
              (json['vehicle_number'] != null &&
                  json['vehicle_number'].toString().isNotEmpty)),
      vehicle: parsedVehicle,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'employee_id': employeeId,
      'full_name': fullName,
      if (email != null) 'email': email,
      if (phone != null) 'phone': phone,
      if (homeAddress != null) 'home_address': homeAddress,
      if (pickupStopId != null) 'pickup_stop_id': pickupStopId,
      if (pickupStopOrder != null) 'pickup_stop_order': pickupStopOrder,
      if (officeLocation != null) 'office_location': officeLocation,
      if (vehicleNumber != null) 'vehicle_number': vehicleNumber,
      'has_vehicle': hasVehicle,
    };
  }

  UserProfile copyWith({
    String? id,
    String? employeeId,
    String? fullName,
    String? email,
    String? phone,
    String? homeAddress,
    String? pickupStopId,
    int? pickupStopOrder,
    String? officeLocation,
    String? vehicleNumber,
    bool? hasVehicle,
    Vehicle? vehicle,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserProfile(
      id: id ?? this.id,
      employeeId: employeeId ?? this.employeeId,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      homeAddress: homeAddress ?? this.homeAddress,
      pickupStopId: pickupStopId ?? this.pickupStopId,
      pickupStopOrder: pickupStopOrder ?? this.pickupStopOrder,
      officeLocation: officeLocation ?? this.officeLocation,
      vehicleNumber: vehicleNumber ?? this.vehicleNumber,
      hasVehicle: hasVehicle ?? this.hasVehicle,
      vehicle: vehicle ?? this.vehicle,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
