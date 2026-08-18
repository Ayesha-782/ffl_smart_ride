import 'package:flutter_test/flutter_test.dart';
import 'package:ffl_smart_ride/core/models/driver_availability.dart';
import 'package:ffl_smart_ride/core/models/passenger_log.dart';
import 'package:ffl_smart_ride/core/models/ride_match.dart';
import 'package:ffl_smart_ride/core/models/ride_session.dart';

void main() {
  group('Ride Sessions & Matching Models Test Suite', () {
    test('RideSession JSON serialization & slot formatting', () {
      final session = RideSession.fromJson({
        'id': 'sess-101',
        'session_date': '2026-08-14',
        'slot': 'morning',
        'status': 'open',
      });

      expect(session.id, equals('sess-101'));
      expect(session.slot, equals('morning'));
      expect(session.isOpen, isTrue);
      expect(session.slotDisplayName, contains('Morning Commute'));

      final json = session.toJson();
      expect(json['slot'], equals('morning'));
      expect(json['status'], equals('open'));
    });

    test('DriverAvailability JSON serialization & seat tracking', () {
      final availability = DriverAvailability.fromJson({
        'id': 'da-202',
        'session_id': 'sess-101',
        'driver_id': 'driver-99',
        'seats_offered': 3,
        'seats_remaining': 2,
        'status': 'active',
        'profiles': {
          'id': 'driver-99',
          'employee_id': 'FFL-777',
          'full_name': 'Ali Khan',
          'vehicle_number': 'LEA-2024',
        },
      });

      expect(availability.seatsOffered, equals(3));
      expect(availability.seatsRemaining, equals(2));
      expect(availability.isActive, isTrue);
      expect(availability.hasRemainingSeats, isTrue);
      expect(availability.driver?.fullName, equals('Ali Khan'));

      final json = availability.toJson();
      expect(json['seats_offered'], equals(3));
      expect(json['seats_remaining'], equals(2));
    });

    test('PassengerLog JSON serialization & waiting state', () {
      final passengerLog = PassengerLog.fromJson({
        'id': 'pl-303',
        'session_id': 'sess-101',
        'passenger_id': 'pass-44',
        'status': 'waiting',
        'requested_at': '2026-08-14T07:15:00Z',
        'profiles': {
          'id': 'pass-44',
          'employee_id': 'FFL-888',
          'full_name': 'Sarah Ahmed',
          'pickup_stop_order': 2,
        },
      });

      expect(passengerLog.isWaiting, isTrue);
      expect(passengerLog.isMatched, isFalse);
      expect(passengerLog.passenger?.pickupStopOrder, equals(2));

      final json = passengerLog.toJson();
      expect(json['status'], equals('waiting'));
    });

    test('RideMatch JSON serialization & participants', () {
      final match = RideMatch.fromJson({
        'id': 'rm-404',
        'session_id': 'sess-101',
        'driver_id': 'driver-99',
        'passenger_id': 'pass-44',
        'status': 'active',
        'matched_at': '2026-08-14T07:30:00Z',
        'driver': {
          'id': 'driver-99',
          'employee_id': 'FFL-777',
          'full_name': 'Ali Khan',
        },
        'passenger': {
          'id': 'pass-44',
          'employee_id': 'FFL-888',
          'full_name': 'Sarah Ahmed',
        },
      });

      expect(match.isActive, isTrue);
      expect(match.driver?.fullName, equals('Ali Khan'));
      expect(match.passenger?.fullName, equals('Sarah Ahmed'));

      final json = match.toJson();
      expect(json['driver_id'], equals('driver-99'));
      expect(json['passenger_id'], equals('pass-44'));
      expect(json['status'], equals('active'));
    });
  });
}
