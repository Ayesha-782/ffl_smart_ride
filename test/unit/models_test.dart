import 'package:flutter_test/flutter_test.dart';
import 'package:ffl_smart_ride/core/models/pickup_stop.dart';
import 'package:ffl_smart_ride/core/models/user_profile.dart';
import 'package:ffl_smart_ride/core/models/vehicle.dart';
import 'package:ffl_smart_ride/core/models/ride_request.dart';

void main() {
  group('Models & Data Serialization Test Suite', () {
    test('PickupStop default ordering', () {
      expect(PickupStop.defaultStops.length, equals(7));
      expect(PickupStop.defaultStops.first.stopOrder, equals(1));
      expect(PickupStop.defaultStops.last.stopOrder, equals(7));
    });

    test('Vehicle JSON mapping', () {
      final vehicle = Vehicle.fromJson({
        'id': 'v-123',
        'user_id': 'u-456',
        'vehicle_type': 'Car',
        'make': 'Toyota',
        'model': 'Corolla',
        'license_plate': 'LEA-2024',
        'capacity': 4,
      });

      expect(vehicle.make, equals('Toyota'));
      expect(vehicle.displayName, equals('Toyota Corolla (LEA-2024)'));
      expect(vehicle.toJson()['license_plate'], equals('LEA-2024'));
    });

    test('UserProfile JSON mapping with nested vehicle', () {
      final profile = UserProfile.fromJson({
        'id': 'u-1',
        'employee_id': 'FFL-100',
        'full_name': 'Zain Malik',
        'pickup_stop_id': 'stop_gate_1',
        'pickup_stop_order': 1,
        'has_vehicle': true,
        'vehicles': {
          'id': 'v-1',
          'user_id': 'u-1',
          'vehicle_type': 'Car',
          'make': 'Honda',
          'model': 'Civic',
          'license_plate': 'ISB-555',
        },
      });

      expect(profile.fullName, equals('Zain Malik'));
      expect(profile.pickupStopOrder, equals(1));
      expect(profile.hasVehicle, isTrue);
      expect(profile.vehicle?.make, equals('Honda'));
    });

    test('RideRequest JSON mapping with pickup stop order', () {
      final ride = RideRequest.fromJson({
        'id': 'r-1',
        'passenger_id': 'p-1',
        'pickup_location': 'Gate 1',
        'office_location': 'Factory Main Plant',
        'pickup_stop_order': 1,
        'leaving_time': '2026-08-14T08:30:00Z',
        'status': 'pending',
      });

      expect(ride.pickupStopOrder, equals(1));
      expect(ride.status, equals('pending'));
      expect(ride.toJson()['pickup_stop_order'], equals(1));
    });
  });
}
