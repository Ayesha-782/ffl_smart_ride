import 'package:ffl_smart_ride/core/models/ride_completion_log.dart';
import 'package:flutter_test/flutter_test.dart';

/// TEST_PLAN.md §7 — environmental calculations, boundary and invalid input.
///
/// The existing suite (`reports_test.dart`, `admin_test.dart`) covers the normal
/// path and multiple passengers well. Neither covers zero, negative, or extreme
/// inputs, which §7 asks for specifically.
///
/// These are real behavioural tests against real Dart, not shape assertions —
/// this is one of the few sections of the plan that can be genuinely verified
/// without a live database.
void main() {
  group('§7 CO2 — normal path (confirming existing coverage still holds)', () {
    test('one passenger over the default route', () {
      expect(
        RideCompletionLog.calculateCo2Saved(
          routeDistanceKm: 2.5,
          emissionFactorKgPerKm: 0.12,
          passengerCount: 1,
        ),
        closeTo(0.30, 0.0001),
      );
    });

    test('scales linearly with passenger count', () {
      final one = RideCompletionLog.calculateCo2Saved(
          routeDistanceKm: 2.5, emissionFactorKgPerKm: 0.12, passengerCount: 1);
      final four = RideCompletionLog.calculateCo2Saved(
          routeDistanceKm: 2.5, emissionFactorKgPerKm: 0.12, passengerCount: 4);
      expect(four, closeTo(one * 4, 0.0001));
    });
  });

  group('§7 CO2 — zero and boundary inputs', () {
    test('zero distance yields zero saving', () {
      expect(
        RideCompletionLog.calculateCo2Saved(
            routeDistanceKm: 0, emissionFactorKgPerKm: 0.12, passengerCount: 3),
        equals(0.0),
      );
    });

    test('zero passengers yields zero saving', () {
      // A completed ride with no passengers saved nothing: the driver drove
      // anyway. Zero is the correct answer here.
      expect(
        RideCompletionLog.calculateCo2Saved(
            routeDistanceKm: 2.5, emissionFactorKgPerKm: 0.12, passengerCount: 0),
        equals(0.0),
      );
    });

    test('a very large distance stays finite', () {
      final result = RideCompletionLog.calculateCo2Saved(
        routeDistanceKm: 1e6,
        emissionFactorKgPerKm: 0.12,
        passengerCount: 4,
      );
      expect(result.isFinite, isTrue);
      expect(result, closeTo(480000.0, 1.0));
    });

    test('a very small distance does not underflow to zero', () {
      final result = RideCompletionLog.calculateCo2Saved(
        routeDistanceKm: 0.001,
        emissionFactorKgPerKm: 0.12,
        passengerCount: 1,
      );
      expect(result, greaterThan(0.0));
    });
  });

  group('§7 fuel — zero and boundary inputs', () {
    test('zero distance yields zero fuel saved', () {
      expect(
        RideCompletionLog.calculateFuelSaved(
            routeDistanceKm: 0,
            fuelConsumptionLPerKm: 0.08,
            passengerCount: 3),
        equals(0.0),
      );
    });

    test('a very large distance stays finite', () {
      final result = RideCompletionLog.calculateFuelSaved(
        routeDistanceKm: 1e6,
        fuelConsumptionLPerKm: 0.08,
        passengerCount: 4,
      );
      expect(result.isFinite, isTrue);
    });
  });

  group('§7 — invalid (negative) inputs', () {
    // A "saving" cannot be negative. These records feed the audit trail
    // (ride_completion_log) and the public leaderboard, so a negative value is
    // not a cosmetic problem: it silently subtracts from a driver's lifetime
    // total. See TEST_RESULTS.md §7 for the disposition of these.

    test('negative distance must not produce a negative CO2 saving', () {
      final result = RideCompletionLog.calculateCo2Saved(
        routeDistanceKm: -2.5,
        emissionFactorKgPerKm: 0.12,
        passengerCount: 1,
      );
      expect(result, greaterThanOrEqualTo(0.0),
          reason: 'a negative distance is not physically meaningful; the '
              'calculation should clamp or reject it rather than return a '
              'negative saving that reduces the audit total');
    });

    test('negative passenger count must not produce a negative CO2 saving', () {
      final result = RideCompletionLog.calculateCo2Saved(
        routeDistanceKm: 2.5,
        emissionFactorKgPerKm: 0.12,
        passengerCount: -3,
      );
      expect(result, greaterThanOrEqualTo(0.0),
          reason: 'passenger count cannot be negative');
    });

    test('negative distance must not produce a negative fuel saving', () {
      final result = RideCompletionLog.calculateFuelSaved(
        routeDistanceKm: -2.5,
        fuelConsumptionLPerKm: 0.08,
        passengerCount: 1,
      );
      expect(result, greaterThanOrEqualTo(0.0));
    });
  });

  group('§7 — fromJson defaulting', () {
    test('missing distance falls back to the documented 2.5 km default', () {
      final log = RideCompletionLog.fromJson({
        'id': 'x',
        'driver_id': 'd',
        'passenger_ids': ['p'],
      });
      expect(log.distanceKm, equals(2.5));
      expect(log.emissionFactorKgPerKm, equals(0.12));
    });

    test('passenger_count is derived from passenger_ids when absent', () {
      final log = RideCompletionLog.fromJson({
        'id': 'x',
        'driver_id': 'd',
        'passenger_ids': ['p1', 'p2', 'p3'],
      });
      expect(log.passengerCount, equals(3));
    });

    test('liters_fuel_saved is computed when the column is absent', () {
      final log = RideCompletionLog.fromJson({
        'id': 'x',
        'driver_id': 'd',
        'passenger_ids': ['p1', 'p2'],
        'distance_km': 2.5,
      });
      // 2.5 km * 0.08 L/km * 2 passengers
      expect(log.litersFuelSaved, closeTo(0.40, 0.0001));
    });
  });
}
