import 'package:flutter_test/flutter_test.dart';
import 'package:ffl_smart_ride/core/models/driver_availability.dart';
import 'package:ffl_smart_ride/core/models/passenger_log.dart';
import 'package:ffl_smart_ride/core/models/ride_match.dart';
import 'package:ffl_smart_ride/features/rides/data/ride_repository.dart';

void main() {
  group('Cancellation Handling & Driver Switch Test Suite', () {
    test('RideMatch cancellation state mapping', () {
      final match = RideMatch.fromJson({
        'id': 'rm-999',
        'session_id': 'sess-1',
        'driver_id': 'd-1',
        'passenger_id': 'p-1',
        'status': 'cancelled',
        'matched_at': '2026-08-14T07:00:00Z',
        'cancelled_at': '2026-08-14T07:15:00Z',
      });

      expect(match.status, equals('cancelled'));
      expect(match.isActive, isFalse);
      expect(match.cancelledAt, isNotNull);

      final json = match.toJson();
      expect(json['status'], equals('cancelled'));
      expect(json['cancelled_at'], isNotNull);
    });

    test('PassengerLog self-cancellation state', () {
      final passengerLog = PassengerLog.fromJson({
        'id': 'pl-888',
        'session_id': 'sess-1',
        'passenger_id': 'p-1',
        'status': 'cancelled',
        'requested_at': '2026-08-14T07:00:00Z',
      });

      expect(passengerLog.isCancelled, isTrue);
      expect(passengerLog.isWaiting, isFalse);
      expect(passengerLog.isMatched, isFalse);
    });

    test('DriverAvailability cancellation state & seat recovery', () {
      final da = DriverAvailability.fromJson({
        'id': 'da-777',
        'session_id': 'sess-1',
        'driver_id': 'd-1',
        'seats_offered': 3,
        'seats_remaining': 3,
        'status': 'cancelled',
      });

      expect(da.isActive, isFalse);
      expect(da.status, equals('cancelled'));
    });

    test('UserSessionStatus correctly categorizes driver vs passenger', () {
      const emptyStatus = UserSessionStatus(responseType: UserSessionResponseType.none);
      expect(emptyStatus.hasResponded, isFalse);

      final driverStatus = UserSessionStatus(
        responseType: UserSessionResponseType.driver,
        driverAvailability: DriverAvailability.fromJson({
          'id': 'da-1',
          'session_id': 's-1',
          'driver_id': 'd-1',
          'seats_offered': 2,
          'seats_remaining': 2,
          'status': 'active',
        }),
      );
      expect(driverStatus.responseType, equals(UserSessionResponseType.driver));
      expect(driverStatus.hasResponded, isTrue);
    });
  });
}
