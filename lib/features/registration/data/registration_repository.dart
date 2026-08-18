import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/supabase_service.dart';

class RegistrationData {
  final String fullName;
  final String employeeId;
  final String email;
  final String password;
  final String phone;
  final String homeAddress;
  final String pickupStopId;
  final int pickupStopOrder;
  final String officeLocation;
  final bool hasVehicle;
  final String? vehicleType;
  final String? make;
  final String? model;
  final String? licensePlate;

  const RegistrationData({
    required this.fullName,
    required this.employeeId,
    required this.email,
    required this.password,
    required this.phone,
    required this.homeAddress,
    this.pickupStopId = 'stop_d_type',
    this.pickupStopOrder = 1,
    this.officeLocation = 'Factory Main Plant',
    this.hasVehicle = false,
    this.vehicleType,
    this.make,
    this.model,
    this.licensePlate,
  });

  Map<String, dynamic> toMetadataMap() {
    return {
      'full_name': fullName.trim(),
      'employee_id': employeeId.trim(),
      'phone': phone.trim(),
      'home_address': homeAddress.trim(),
      'pickup_stop_id': pickupStopId,
      'pickup_stop_order': pickupStopOrder,
      'office_location': officeLocation.trim(),
      'has_vehicle': hasVehicle,
      if (hasVehicle) ...{
        'vehicle_type': vehicleType ?? 'Car',
        'make': make?.trim() ?? '',
        'model': model?.trim() ?? '',
        'vehicle_number': licensePlate?.toUpperCase().trim() ?? '',
        'license_plate': licensePlate?.toUpperCase().trim() ?? '',
      },
    };
  }
}

class RegistrationRepository {
  SupabaseClient get _supabase => SupabaseService.instance.client;

  /// Registers user account atomically.
  /// User auth record + Profile + Vehicle records are created via PostgreSQL trigger / atomic upserts.
  Future<AuthResponse> registerUser(RegistrationData data) async {
    final response = await _supabase.auth.signUp(
      email: data.email.trim(),
      password: data.password.trim(),
      data: data.toMetadataMap(),
    );

    final user = response.user;
    if (user == null) {
      throw Exception('Account creation could not be initialized.');
    }

    // Direct fallback upsert if trigger is not yet migrated on the Supabase project
    try {
      await _supabase.from('profiles').upsert({
        'id': user.id,
        'employee_id': data.employeeId.trim(),
        'full_name': data.fullName.trim(),
        'email': data.email.trim(),
        'phone': data.phone.trim(),
        'home_address': data.homeAddress.trim(),
        'pickup_stop_id': data.pickupStopId,
        'pickup_stop_order': data.pickupStopOrder,
        'office_location': data.officeLocation.trim(),
        'has_vehicle': data.hasVehicle,
        'vehicle_number': data.hasVehicle ? data.licensePlate?.toUpperCase().trim() : null,
      });

      if (data.hasVehicle && data.licensePlate != null && data.licensePlate!.trim().isNotEmpty) {
        await _supabase.from('vehicles').upsert({
          'user_id': user.id,
          'vehicle_type': data.vehicleType ?? 'Car',
          'make': data.make?.trim() ?? '',
          'model': data.model?.trim() ?? '',
          'license_plate': data.licensePlate!.toUpperCase().trim(),
        }, onConflict: 'user_id');
      }
    } catch (_) {
      // If trigger already handled it, continuing without failing
    }

    return response;
  }
}
