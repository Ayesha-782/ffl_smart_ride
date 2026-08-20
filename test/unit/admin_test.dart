import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ffl_smart_ride/core/models/ride_completion_log.dart';
import 'package:ffl_smart_ride/core/models/user_profile.dart';
import 'package:ffl_smart_ride/core/models/vehicle.dart';
import 'package:ffl_smart_ride/features/admin/data/admin_repository.dart';
import 'package:ffl_smart_ride/features/admin/screens/admin_dashboard_shell.dart';
import 'package:ffl_smart_ride/features/admin/services/pdf_report_service.dart';

void main() {
  group('UserProfile Role & Status Tests', () {
    test('Default profile parses as regular active user', () {
      final json = {
        'id': 'user-123',
        'employee_id': 'EMP-100',
        'full_name': 'Test User',
        'email': 'user@ffl.com',
      };

      final profile = UserProfile.fromJson(json);
      expect(profile.role, equals('user'));
      expect(profile.isActive, isTrue);
      expect(profile.isAdmin, isFalse);
      expect(profile.isSuperAdmin, isFalse);
      expect(profile.hasAdminPrivileges, isFalse);
    });

    test('Admin role profile is recognized correctly', () {
      final json = {
        'id': 'admin-456',
        'employee_id': 'ADM-001',
        'full_name': 'Admin User',
        'email': 'admin@ffl.com',
        'role': 'admin',
        'is_active': true,
      };

      final profile = UserProfile.fromJson(json);
      expect(profile.role, equals('admin'));
      expect(profile.isAdmin, isTrue);
      expect(profile.isSuperAdmin, isFalse);
      expect(profile.hasAdminPrivileges, isTrue);
      expect(profile.isActive, isTrue);
    });

    test('Pre-made test admin11 profile parses gracefully with no vehicle', () {
      final json = {
        'id': 'admin11-uuid',
        'employee_id': 'ADM-0011',
        'full_name': 'Test Administrator',
        'email': 'admin11@gmail.com',
        'role': 'admin',
        'is_active': true,
        'has_vehicle': false,
        'vehicle_number': null,
        'vehicles': null,
        'pickup_stop_id': null,
      };

      final profile = UserProfile.fromJson(json);
      expect(profile.role, equals('admin'));
      expect(profile.isAdmin, isTrue);
      expect(profile.isSuperAdmin, isFalse);
      expect(profile.hasVehicle, isFalse);
      expect(profile.vehicle, isNull);
      expect(profile.pickupStopId, isNull);
    });

    test('Super Admin role profile has full privilege flags', () {
      final json = {
        'id': 'super-789',
        'employee_id': 'SADM-001',
        'full_name': 'Super Admin User',
        'email': 'superadmin@ffl.com',
        'role': 'super_admin',
        'is_active': true,
        'national_id': '35201-9999999-1',
      };

      final profile = UserProfile.fromJson(json);
      expect(profile.role, equals('super_admin'));
      expect(profile.isAdmin, isTrue);
      expect(profile.isSuperAdmin, isTrue);
      expect(profile.hasAdminPrivileges, isTrue);
      expect(profile.nationalId, equals('35201-9999999-1'));
    });

    test('Deactivated user profile parses is_active as false', () {
      final json = {
        'id': 'deact-000',
        'employee_id': 'EMP-DEACT',
        'full_name': 'Inactive User',
        'email': 'inactive@ffl.com',
        'role': 'user',
        'is_active': false,
      };

      final profile = UserProfile.fromJson(json);
      expect(profile.isActive, isFalse);
    });

    test('UserProfile with vehicle details serialization and copyWith', () {
      const vehicle = Vehicle(
        id: 'v-1',
        userId: 'u-1',
        vehicleType: 'Car',
        make: 'Honda',
        model: 'City',
        licensePlate: 'LEA-5555',
      );

      final profile = UserProfile(
        id: 'u-1',
        employeeId: 'EMP-1',
        fullName: 'Driver Name',
        role: 'user',
        isActive: true,
        hasVehicle: true,
        vehicle: vehicle,
      );

      final updated = profile.copyWith(role: 'admin');
      expect(updated.role, equals('admin'));
      expect(updated.hasVehicle, isTrue);
      expect(updated.vehicle?.licensePlate, equals('LEA-5555'));
    });
  });

  group('RideCompletionLog Fuel & Emission Savings Tests', () {
    test('calculateFuelSaved computes liters based on distance, rate, and passengers', () {
      // 2.5 km route * 0.08 L/km * 1 passenger = 0.20 Liters
      final fuel1 = RideCompletionLog.calculateFuelSaved(
        routeDistanceKm: 2.5,
        fuelConsumptionLPerKm: 0.08,
        passengerCount: 1,
      );
      expect(fuel1, closeTo(0.20, 0.0001));

      // 2.5 km route * 0.08 L/km * 3 passengers = 0.60 Liters
      final fuel3 = RideCompletionLog.calculateFuelSaved(
        routeDistanceKm: 2.5,
        fuelConsumptionLPerKm: 0.08,
        passengerCount: 3,
      );
      expect(fuel3, closeTo(0.60, 0.0001));

      // 5.0 km route * 0.10 L/km * 4 passengers = 2.00 Liters
      final fuel4 = RideCompletionLog.calculateFuelSaved(
        routeDistanceKm: 5.0,
        fuelConsumptionLPerKm: 0.10,
        passengerCount: 4,
      );
      expect(fuel4, closeTo(2.00, 0.0001));
    });

    test('RideCompletionLog JSON serialization includes liters_fuel_saved', () {
      final log = RideCompletionLog(
        id: 'log-100',
        driverId: 'drv-1',
        passengerIds: ['p-1', 'p-2'],
        passengerCount: 2,
        distanceKm: 2.5,
        emissionFactorKgPerKm: 0.12,
        kgCo2Saved: 0.60,
        litersFuelSaved: 0.40,
        completedAt: DateTime.parse('2025-06-01T08:30:00Z'),
      );

      final json = log.toJson();
      expect(json['liters_fuel_saved'], equals(0.40));
      expect(json['kg_co2_saved'], equals(0.60));

      final parsed = RideCompletionLog.fromJson(json);
      expect(parsed.litersFuelSaved, equals(0.40));
      expect(parsed.kgCo2Saved, equals(0.60));
      expect(parsed.passengerCount, equals(2));
    });
  });

  group('PDF Report Generation Tests', () {
    test('PdfReportService generates valid PDF document bytes', () async {
      const summary = AdminDashboardSummary(
        totalCompletedRides: 42,
        totalCo2SavedKg: 25.2,
        totalCo2SavedTons: 0.0252,
        totalFuelSavedLiters: 16.8,
        totalRegisteredUsers: 50,
        activeUsers: 48,
      );

      final topDrivers = [
        const LeaderboardEntry(
          userId: 'drv-1',
          name: 'Tariq Driver',
          email: 'tariq@ffl.com',
          employeeId: 'EMP-101',
          rideCount: 15,
          co2SavedKg: 9.0,
          fuelSavedLiters: 6.0,
        ),
        const LeaderboardEntry(
          userId: 'drv-2',
          name: 'Usman Driver',
          email: 'usman@ffl.com',
          employeeId: 'EMP-102',
          rideCount: 12,
          co2SavedKg: 7.2,
          fuelSavedLiters: 4.8,
        ),
      ];

      final topPassengers = [
        const LeaderboardEntry(
          userId: 'pass-1',
          name: 'Bilal Commuter',
          email: 'bilal@ffl.com',
          employeeId: 'EMP-201',
          rideCount: 14,
          co2SavedKg: 4.2,
          fuelSavedLiters: 2.8,
        ),
      ];

      final pdfBytes = await PdfReportService.generateReportBytes(
        summary: summary,
        topDrivers: topDrivers,
        topPassengers: topPassengers,
        periodLabel: 'This Month',
        startDate: DateTime(2025, 6, 1),
        endDate: DateTime(2025, 6, 30),
      );

      expect(pdfBytes, isNotNull);
      expect(pdfBytes.isNotEmpty, isTrue);
      final header = String.fromCharCodes(pdfBytes.take(4));
      expect(header, equals('%PDF'));
    });
  });
}
