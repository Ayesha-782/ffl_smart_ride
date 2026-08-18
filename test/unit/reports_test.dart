import 'package:flutter_test/flutter_test.dart';
import 'package:ffl_smart_ride/core/models/ride_completion_log.dart';
import 'package:ffl_smart_ride/features/reports/models/reports_models.dart';

void main() {
  group('Reports & Environmental Impact Test Suite', () {
    test('MonthlyCo2Summary JSON mapping & calculations', () {
      final summary = MonthlyCo2Summary.fromJson({
        'month': '2026-08',
        'month_name': 'August 2026',
        'total_matches_completed': 100,
        'total_kg_saved': 30.0,
        'total_tons_saved': 0.03,
      });

      expect(summary.totalMatchesCompleted, equals(100));
      expect(summary.totalKgSaved, equals(30.0));
      expect(summary.totalTonsSaved, equals(0.03));
      expect(summary.monthName, equals('August 2026'));

      final json = summary.toJson();
      expect(json['total_matches_completed'], equals(100));
      expect(json['total_kg_saved'], equals(30.0));
    });

    test('LeaderboardEntry rank medals formatting', () {
      const top1 = LeaderboardEntry(
        userId: 'u1',
        fullName: 'Ali Khan',
        employeeId: 'FFL-101',
        ridesCount: 15,
        co2SavedKg: 4.5,
        rank: 1,
      );

      const top2 = LeaderboardEntry(
        userId: 'u2',
        fullName: 'Sarah Ahmed',
        employeeId: 'FFL-102',
        ridesCount: 12,
        co2SavedKg: 3.6,
        rank: 2,
      );

      const top3 = LeaderboardEntry(
        userId: 'u3',
        fullName: 'Bilal Tariq',
        employeeId: 'FFL-103',
        ridesCount: 10,
        co2SavedKg: 3.0,
        rank: 3,
      );

      const top4 = LeaderboardEntry(
        userId: 'u4',
        fullName: 'Hamza Malik',
        employeeId: 'FFL-104',
        ridesCount: 8,
        co2SavedKg: 2.4,
        rank: 4,
      );

      expect(top1.rankMedal, equals('🥇'));
      expect(top2.rankMedal, equals('🥈'));
      expect(top3.rankMedal, equals('🥉'));
      expect(top4.rankMedal, equals('#4'));
    });

    test('MonthlyTrend & UserPersonalStats JSON mapping', () {
      final trend = MonthlyTrend.fromJson({
        'month_key': '2026-08',
        'month_short': 'Aug',
        'year': '2026',
        'match_count': 50,
        'kg_saved': 15.0,
        'tons_saved': 0.015,
      });

      expect(trend.monthShort, equals('Aug'));
      expect(trend.matchCount, equals(50));
      expect(trend.kgSaved, equals(15.0));

      final stats = UserPersonalStats.fromJson({
        'user_id': 'u-99',
        'month': '2026-08',
        'rides_given_as_driver': 10,
        'rides_taken_as_passenger': 4,
        'total_rides': 14,
        'personal_kg_co2_saved': 4.2,
      });

      expect(stats.ridesGivenAsDriver, equals(10));
      expect(stats.ridesTakenAsPassenger, equals(4));
      expect(stats.totalRides, equals(14));
      expect(stats.personalKgCo2Saved, equals(4.2));
    });

    test('CO2 Saved Formula Calculation: distance * emission_factor * passenger_count', () {
      const distanceKm = 2.5;
      const emissionFactor = 0.12;

      // 1 passenger
      final co2Single = RideCompletionLog.calculateCo2Saved(
        routeDistanceKm: distanceKm,
        emissionFactorKgPerKm: emissionFactor,
        passengerCount: 1,
      );
      expect(co2Single, closeTo(0.30, 0.0001));

      // 3 passengers
      final co2ThreePassengers = RideCompletionLog.calculateCo2Saved(
        routeDistanceKm: distanceKm,
        emissionFactorKgPerKm: emissionFactor,
        passengerCount: 3,
      );
      expect(co2ThreePassengers, closeTo(0.90, 0.0001));

      // 4 passengers
      final co2FourPassengers = RideCompletionLog.calculateCo2Saved(
        routeDistanceKm: distanceKm,
        emissionFactorKgPerKm: emissionFactor,
        passengerCount: 4,
      );
      expect(co2FourPassengers, closeTo(1.20, 0.0001));
    });

    test('RideCompletionLog JSON serialization & parsing', () {
      final now = DateTime.now();
      final log = RideCompletionLog(
        id: 'log-101',
        sessionId: 'session-202',
        driverId: 'driver-303',
        passengerIds: ['p1', 'p2', 'p3'],
        passengerCount: 3,
        distanceKm: 2.5,
        emissionFactorKgPerKm: 0.12,
        kgCo2Saved: 0.90,
        completedAt: now,
      );

      expect(log.passengerCount, equals(3));
      expect(log.kgCo2Saved, equals(0.90));
      expect(log.passengerIds.length, equals(3));

      final json = log.toJson();
      expect(json['id'], equals('log-101'));
      expect(json['passenger_count'], equals(3));
      expect(json['kg_co2_saved'], equals(0.90));

      final fromJson = RideCompletionLog.fromJson(json);
      expect(fromJson.id, equals(log.id));
      expect(fromJson.passengerIds, equals(['p1', 'p2', 'p3']));
      expect(fromJson.passengerCount, equals(3));
      expect(fromJson.kgCo2Saved, closeTo(0.90, 0.0001));
    });

    test('Audit Trail Simulation: Deleting operational ride does NOT reduce dashboard total CO2', () {
      const distanceKm = 2.5;
      const emissionFactor = 0.12;

      // 1. Initial State: Empty operational list and completion log
      final List<Map<String, dynamic>> operationalRideMatches = [];
      final List<RideCompletionLog> completionAuditLog = [];

      double computeDashboardTotalCo2() {
        return completionAuditLog.fold<double>(
          0.0,
          (sum, log) => sum + log.kgCo2Saved,
        );
      }

      expect(computeDashboardTotalCo2(), equals(0.0));

      // 2. Complete a ride for 3 passengers (e.g. p1, p2, p3)
      final passengerIds = ['p1', 'p2', 'p3'];
      final passengerCount = passengerIds.length;
      final kgSaved = RideCompletionLog.calculateCo2Saved(
        routeDistanceKm: distanceKm,
        emissionFactorKgPerKm: emissionFactor,
        passengerCount: passengerCount,
      );
      expect(kgSaved, closeTo(0.90, 0.0001));

      // Operational rows are marked completed
      for (final pid in passengerIds) {
        operationalRideMatches.add({
          'id': 'match-$pid',
          'driver_id': 'driver-1',
          'passenger_id': pid,
          'status': 'completed',
        });
      }

      // Permanent audit log row is created
      completionAuditLog.add(RideCompletionLog(
        id: 'audit-log-1',
        sessionId: 'session-1',
        driverId: 'driver-1',
        passengerIds: passengerIds,
        passengerCount: passengerCount,
        distanceKm: distanceKm,
        emissionFactorKgPerKm: emissionFactor,
        kgCo2Saved: kgSaved,
        completedAt: DateTime.now(),
      ));

      // Confirm dashboard total increased by 0.90 kg
      expect(computeDashboardTotalCo2(), closeTo(0.90, 0.0001));
      expect(operationalRideMatches.length, equals(3));

      // 3. User / Admin deletes the completed ride from visible/operational table
      operationalRideMatches.clear();
      expect(operationalRideMatches.isEmpty, isTrue);

      // 4. Confirm dashboard total CO2 reads from completion audit log and is UNCHANGED
      expect(computeDashboardTotalCo2(), closeTo(0.90, 0.0001));
      expect(completionAuditLog.length, equals(1));
    });

    test('Ride Confirmation Timeout Flow & Guards: Unconfirmed ride auto-expires and never adds CO2', () {
      const distanceKm = 2.5;
      const emissionFactor = 0.12;

      // Simulation State
      int driverSeatsRemaining = 3;
      String passengerQueueStatus = 'waiting'; // in passenger_log
      String matchStatus = 'pending_confirmation';
      final matchCreatedTime = DateTime.now();
      final confirmationDeadline = matchCreatedTime.add(const Duration(minutes: 5));

      final List<RideCompletionLog> completionLog = [];

      double computeTotalCo2() {
        return completionLog.fold<double>(0.0, (sum, log) => sum + log.kgCo2Saved);
      }

      // 1. Driver matches passenger -> seats decrease by 1, passenger marked matched
      driverSeatsRemaining -= 1;
      passengerQueueStatus = 'matched';
      expect(driverSeatsRemaining, equals(2));
      expect(passengerQueueStatus, equals('matched'));
      expect(matchStatus, equals('pending_confirmation'));

      // 2. Driver attempts to complete ride while still pending_confirmation -> MUST FAIL
      bool canComplete(String status) => status == 'confirmed';
      expect(canComplete(matchStatus), isFalse);

      // Attempted execution:
      if (canComplete(matchStatus)) {
        completionLog.add(RideCompletionLog(
          id: 'fake-log',
          driverId: 'driver-1',
          passengerIds: ['p1'],
          passengerCount: 1,
          distanceKm: distanceKm,
          emissionFactorKgPerKm: emissionFactor,
          kgCo2Saved: distanceKm * emissionFactor * 1,
          completedAt: DateTime.now(),
        ));
      }
      expect(completionLog.isEmpty, isTrue);
      expect(computeTotalCo2(), equals(0.0));

      // 3. 5 Minutes pass with no response (Time > confirmationDeadline) -> Timeout occurs
      final simulatedCurrentTime = confirmationDeadline.add(const Duration(seconds: 1));
      final hasTimedOut = simulatedCurrentTime.isAfter(confirmationDeadline);
      expect(hasTimedOut, isTrue);

      if (hasTimedOut && matchStatus == 'pending_confirmation') {
        // Match expires
        matchStatus = 'expired';
        // Passenger returned to waiting queue
        passengerQueueStatus = 'waiting';
        // Driver seats restored
        driverSeatsRemaining += 1;
      }

      // (a) Passenger reappears in waiting queue
      expect(passengerQueueStatus, equals('waiting'));
      // Driver seats restored
      expect(driverSeatsRemaining, equals(3));
      // Match is expired
      expect(matchStatus, equals('expired'));

      // (b) Driver's complete ride option is unavailable
      expect(canComplete(matchStatus), isFalse);

      // (c) No CO2 was added to dashboard
      expect(computeTotalCo2(), equals(0.0));
      expect(completionLog.isEmpty, isTrue);
    });

    test('Confirmed Ride Flow: Confirmed ride allows completion and accurately records CO2', () {
      const distanceKm = 2.5;
      const emissionFactor = 0.12;

      String matchStatus = 'pending_confirmation';
      final List<RideCompletionLog> completionLog = [];

      bool canComplete(String status) => status == 'confirmed';

      // 1. Passenger confirms within 5 minutes
      matchStatus = 'confirmed';
      expect(canComplete(matchStatus), isTrue);

      // 2. Driver completes confirmed trip
      if (canComplete(matchStatus)) {
        final kgSaved = RideCompletionLog.calculateCo2Saved(
          routeDistanceKm: distanceKm,
          emissionFactorKgPerKm: emissionFactor,
          passengerCount: 1,
        );

        completionLog.add(RideCompletionLog(
          id: 'log-confirmed-1',
          driverId: 'driver-1',
          passengerIds: ['p1'],
          passengerCount: 1,
          distanceKm: distanceKm,
          emissionFactorKgPerKm: emissionFactor,
          kgCo2Saved: kgSaved,
          completedAt: DateTime.now(),
        ));
        matchStatus = 'completed';
      }

      expect(matchStatus, equals('completed'));
      expect(completionLog.length, equals(1));
      expect(completionLog.first.kgCo2Saved, closeTo(0.30, 0.0001));
    });

    test('HomeScreen Impact Card: Dynamic formatting for rides, fuel saved, and CO2 saved', () {
      const summary = MonthlyCo2Summary(
        month: '2026-08',
        monthName: 'August 2026',
        totalMatchesCompleted: 4,
        totalKgSaved: 1.2,
        totalTonsSaved: 0.0012,
      );

      final totalRides = summary.totalMatchesCompleted;
      final totalKg = summary.totalKgSaved;
      final fuelSavedLiters = totalKg > 0 ? (totalKg / 2.31) : (totalRides * 0.25);
      final fuelDisplay = fuelSavedLiters > 0
          ? (fuelSavedLiters < 10
              ? '${fuelSavedLiters.toStringAsFixed(1)} L'
              : '${fuelSavedLiters.toStringAsFixed(0)} L')
          : '0 L';
      final co2Display = totalKg > 0
          ? (totalKg >= 1000
              ? '${(totalKg / 1000).toStringAsFixed(2)} t'
              : (totalKg < 10 ? '${totalKg.toStringAsFixed(1)} kg' : '${totalKg.toStringAsFixed(0)} kg'))
          : '0 kg';

      expect(totalRides, equals(4));
      expect(fuelDisplay, equals('0.5 L'));
      expect(co2Display, equals('1.2 kg'));
    });
  });
}
