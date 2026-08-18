import 'package:flutter_test/flutter_test.dart';
import 'package:ffl_smart_ride/core/models/driver_availability.dart';
import 'package:ffl_smart_ride/core/models/passenger_log.dart';
import 'package:ffl_smart_ride/core/models/ride_match.dart';
import 'package:ffl_smart_ride/core/models/session_schedule.dart';
import 'package:ffl_smart_ride/features/rides/data/ride_repository.dart';

void main() {
  group('Session Lifecycle & Schedule Test Suite', () {
    test('SessionSchedule JSON parsing & time window formatting', () {
      final schedule = SessionSchedule.fromJson({
        'id': 'sched_morning',
        'slot': 'morning',
        'opens_at': '06:30:00',
        'closes_at': '08:30:00',
        'is_active': true,
      });

      expect(schedule.slot, equals('morning'));
      expect(schedule.slotDisplayName, equals('Morning Commute'));
      expect(schedule.timeWindowFormatted, equals('6:30 AM - 8:30 AM'));
      expect(schedule.isActive, isTrue);

      final json = schedule.toJson();
      expect(json['id'], equals('sched_morning'));
      expect(json['slot'], equals('morning'));
    });

    test('UserSessionStatus state flags', () {
      const noneStatus = UserSessionStatus(
        responseType: UserSessionResponseType.none,
      );
      expect(noneStatus.hasResponded, isFalse);

      final driverStatus = UserSessionStatus(
        responseType: UserSessionResponseType.driver,
        driverAvailability: DriverAvailability.fromJson({
          'id': 'da-1',
          'session_id': 'sess-1',
          'driver_id': 'd-1',
          'seats_offered': 3,
          'seats_remaining': 3,
          'status': 'active',
        }),
      );
      expect(driverStatus.hasResponded, isTrue);
      expect(driverStatus.driverAvailability?.seatsOffered, equals(3));

      final passengerStatus = UserSessionStatus(
        responseType: UserSessionResponseType.passenger,
        passengerLog: PassengerLog.fromJson({
          'id': 'pl-1',
          'session_id': 'sess-1',
          'passenger_id': 'p-1',
          'status': 'waiting',
          'requested_at': '2026-08-14T07:00:00Z',
        }),
      );
      expect(passengerStatus.hasResponded, isTrue);
      expect(passengerStatus.passengerLog?.isWaiting, isTrue);

      final matchedStatus = UserSessionStatus(
        responseType: UserSessionResponseType.matched,
        rideMatch: RideMatch.fromJson({
          'id': 'rm-1',
          'session_id': 'sess-1',
          'driver_id': 'd-1',
          'passenger_id': 'p-1',
          'status': 'active',
          'matched_at': '2026-08-14T07:10:00Z',
        }),
      );
      expect(matchedStatus.hasResponded, isTrue);
      expect(matchedStatus.rideMatch?.isActive, isTrue);
    });

    test('RideRepository currentSlotName returns valid slot', () {
      final repo = RideRepository();
      final slot = repo.currentSlotName;
      expect(['morning', 'afternoon', 'evening'], contains(slot));
    });
  });
}
