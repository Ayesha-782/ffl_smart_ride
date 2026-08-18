import 'package:flutter_test/flutter_test.dart';
import 'package:ffl_smart_ride/core/models/priority_passenger.dart';

void main() {
  group('Nearest-Passenger Priority Queue Test Suite', () {
    test('PriorityPassenger JSON mapping & stops away calculations', () {
      final passenger1 = PriorityPassenger.fromJson({
        'log_id': 'log-1',
        'passenger_id': 'pass-1',
        'passenger_name': 'Zain Malik',
        'employee_id': 'FFL-101',
        'phone': '03001234567',
        'home_address': 'House 12, Sector A',
        'pickup_stop_id': 'stop_sector_a',
        'pickup_stop_name': 'Sector A (Central Park / Mosque)',
        'passenger_stop_order': 2,
        'driver_stop_order': 2,
        'stops_away': 0,
        'requested_at': '2026-08-14T07:10:00Z',
        'status': 'waiting',
      });

      expect(passenger1.passengerName, equals('Zain Malik'));
      expect(passenger1.stopsAway, equals(0));
      expect(passenger1.stopsAwayDescription, contains('Same Stop'));
      expect(passenger1.stopDisplayTitle, contains('Stop #2: Sector A'));

      final json = passenger1.toJson();
      expect(json['passenger_id'], equals('pass-1'));
      expect(json['stops_away'], equals(0));
    });

    test('PriorityPassenger proximity sorting with tiebreaker', () {
      final p1 = PriorityPassenger(
        logId: '1',
        passengerId: 'p1',
        passengerName: 'Farhan',
        employeeId: 'E1',
        phone: '111',
        homeAddress: 'A',
        passengerStopOrder: 4,
        driverStopOrder: 2,
        stopsAway: 2,
        requestedAt: DateTime.parse('2026-08-14T07:05:00Z'),
      );

      final p2 = PriorityPassenger(
        logId: '2',
        passengerId: 'p2',
        passengerName: 'Bilal',
        employeeId: 'E2',
        phone: '222',
        homeAddress: 'B',
        passengerStopOrder: 2,
        driverStopOrder: 2,
        stopsAway: 0,
        requestedAt: DateTime.parse('2026-08-14T07:15:00Z'),
      );

      final p3 = PriorityPassenger(
        logId: '3',
        passengerId: 'p3',
        passengerName: 'Hamza',
        employeeId: 'E3',
        phone: '333',
        homeAddress: 'C',
        passengerStopOrder: 3,
        driverStopOrder: 2,
        stopsAway: 1,
        requestedAt: DateTime.parse('2026-08-14T07:00:00Z'),
      );

      final list = [p1, p2, p3];

      // Sort by proximity ascending, then requestedAt ascending
      list.sort((a, b) {
        final cmp = a.stopsAway.compareTo(b.stopsAway);
        if (cmp != 0) return cmp;
        return a.requestedAt.compareTo(b.requestedAt);
      });

      expect(list[0].passengerName, equals('Bilal')); // 0 stops away
      expect(list[1].passengerName, equals('Hamza')); // 1 stop away
      expect(list[2].passengerName, equals('Farhan')); // 2 stops away
    });
  });
}
