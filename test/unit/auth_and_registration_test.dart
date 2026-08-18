import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ffl_smart_ride/core/errors/app_exceptions.dart';
import 'package:ffl_smart_ride/features/registration/data/registration_repository.dart';

void main() {
  group('Auth & Registration Test Suite', () {
    test('RegistrationData metadata serialization for Driver (hasVehicle = true)', () {
      const data = RegistrationData(
        fullName: 'Zain Malik',
        employeeId: 'FFL-7890',
        email: 'zain.malik@ffl.com',
        password: 'Password123!',
        phone: '+923001234567',
        homeAddress: 'House 42, Sector B, Township',
        pickupStopId: 'stop_sector_b',
        pickupStopOrder: 4,
        officeLocation: 'Factory Main Plant',
        hasVehicle: true,
        vehicleType: 'Car',
        make: 'Honda',
        model: 'Civic',
        licensePlate: 'lea-2024-55',
      );

      final map = data.toMetadataMap();

      expect(map['full_name'], equals('Zain Malik'));
      expect(map['employee_id'], equals('FFL-7890'));
      expect(map['pickup_stop_id'], equals('stop_sector_b'));
      expect(map['pickup_stop_order'], equals(4));
      expect(map['has_vehicle'], isTrue);
      expect(map['vehicle_type'], equals('Car'));
      expect(map['make'], equals('Honda'));
      expect(map['model'], equals('Civic'));
      expect(map['license_plate'], equals('LEA-2024-55'));
      expect(map['vehicle_number'], equals('LEA-2024-55'));
    });

    test('RegistrationData metadata serialization for Non-Driver (hasVehicle = false)', () {
      const data = RegistrationData(
        fullName: 'Sara Khan',
        employeeId: 'FFL-1122',
        email: 'sara.khan@ffl.com',
        password: 'SecurePassword123',
        phone: '+923009876543',
        homeAddress: 'House 12, Sector A, Township',
        pickupStopId: 'stop_sector_a',
        pickupStopOrder: 2,
        officeLocation: 'Factory Main Plant',
        hasVehicle: false,
      );

      final map = data.toMetadataMap();

      expect(map['full_name'], equals('Sara Khan'));
      expect(map['employee_id'], equals('FFL-1122'));
      expect(map['has_vehicle'], isFalse);
      expect(map.containsKey('make'), isFalse);
      expect(map.containsKey('model'), isFalse);
      expect(map.containsKey('license_plate'), isFalse);
    });

    test('AppExceptions error message translation', () {
      // 1. Invalid credentials
      expect(
        AppExceptions.getErrorMessage(const AuthException('Invalid login credentials')),
        equals('Incorrect email or password. Please verify and try again.'),
      );

      // 2. Duplicate email
      expect(
        AppExceptions.getErrorMessage(const AuthException('User already registered')),
        equals('An account with this email already exists. Please sign in.'),
      );

      // 3. Unconfirmed email
      expect(
        AppExceptions.getErrorMessage(const AuthException('Email not confirmed')),
        equals('Please check your email and verify your account to proceed.'),
      );

      // 4. Duplicate employee_id
      expect(
        AppExceptions.getErrorMessage(const PostgrestException(
          message: 'duplicate key value violates unique constraint',
          details: 'Key (employee_id)=(FFL-101) already exists.',
        )),
        equals('This Employee ID is already registered to another account.'),
      );

      // 5. Duplicate license plate
      expect(
        AppExceptions.getErrorMessage(const PostgrestException(
          message: 'duplicate key value violates unique constraint',
          details: 'Key (license_plate)=(LEA-2024) already exists.',
        )),
        equals('This Vehicle Number / License Plate is already registered.'),
      );

      // 6. Email rate limit
      expect(
        AppExceptions.getErrorMessage(const AuthException('email_rate_limit_exceeded')),
        contains('Email rate limit reached'),
      );

      // 7. Network failure SocketException
      expect(
        AppExceptions.getErrorMessage(const SocketException('Failed host lookup')),
        equals('No internet connection. Please verify your network and try again.'),
      );
    });
  });
}
