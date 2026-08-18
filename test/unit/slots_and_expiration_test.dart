import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ffl_smart_ride/core/models/ride_request.dart';
import 'package:ffl_smart_ride/core/models/ride_slot.dart';
import 'package:ffl_smart_ride/features/rides/screens/create_request_screen.dart';

void main() {
  group('Ride Slots & Expiration Logic Tests', () {
    test('RideSlot definitions match official 3 operating windows', () {
      expect(RideSlot.slots.length, equals(3));

      final morning = RideSlot.slots[0];
      expect(morning.name, equals('morning'));
      expect(morning.start, equals(const TimeOfDay(hour: 7, minute: 0)));
      expect(morning.end, equals(const TimeOfDay(hour: 9, minute: 0)));

      final lunch = RideSlot.slots[1];
      expect(lunch.name, equals('afternoon'));
      expect(lunch.start, equals(const TimeOfDay(hour: 12, minute: 30)));
      expect(lunch.end, equals(const TimeOfDay(hour: 14, minute: 30)));

      final evening = RideSlot.slots[2];
      expect(evening.name, equals('evening'));
      expect(evening.start, equals(const TimeOfDay(hour: 16, minute: 30)));
      expect(evening.end, equals(const TimeOfDay(hour: 17, minute: 30)));
    });

    test('RideSlot containment and matching checks', () {
      // 1. Morning Slot (07:00 to 09:00)
      expect(RideSlot.isTimeInAnySlot(const TimeOfDay(hour: 7, minute: 0)), isTrue);
      expect(RideSlot.isTimeInAnySlot(const TimeOfDay(hour: 8, minute: 15)), isTrue);
      expect(RideSlot.isTimeInAnySlot(const TimeOfDay(hour: 9, minute: 0)), isTrue);
      expect(RideSlot.getMatchingSlot(const TimeOfDay(hour: 8, minute: 0))?.name, equals('morning'));

      // Outside morning
      expect(RideSlot.isTimeInAnySlot(const TimeOfDay(hour: 6, minute: 59)), isFalse);
      expect(RideSlot.isTimeInAnySlot(const TimeOfDay(hour: 9, minute: 1)), isFalse);
      expect(RideSlot.isTimeInAnySlot(const TimeOfDay(hour: 10, minute: 0)), isFalse);

      // 2. Lunch / Afternoon Slot (12:30 to 14:30)
      expect(RideSlot.isTimeInAnySlot(const TimeOfDay(hour: 12, minute: 30)), isTrue);
      expect(RideSlot.isTimeInAnySlot(const TimeOfDay(hour: 13, minute: 0)), isTrue);
      expect(RideSlot.isTimeInAnySlot(const TimeOfDay(hour: 14, minute: 30)), isTrue);
      expect(RideSlot.getMatchingSlot(const TimeOfDay(hour: 13, minute: 15))?.name, equals('afternoon'));

      // Outside lunch
      expect(RideSlot.isTimeInAnySlot(const TimeOfDay(hour: 12, minute: 29)), isFalse);
      expect(RideSlot.isTimeInAnySlot(const TimeOfDay(hour: 14, minute: 31)), isFalse);
      expect(RideSlot.isTimeInAnySlot(const TimeOfDay(hour: 15, minute: 30)), isFalse);

      // 3. Evening Slot (16:30 to 17:30)
      expect(RideSlot.isTimeInAnySlot(const TimeOfDay(hour: 16, minute: 30)), isTrue);
      expect(RideSlot.isTimeInAnySlot(const TimeOfDay(hour: 17, minute: 0)), isTrue);
      expect(RideSlot.isTimeInAnySlot(const TimeOfDay(hour: 17, minute: 30)), isTrue);
      expect(RideSlot.getMatchingSlot(const TimeOfDay(hour: 17, minute: 10))?.name, equals('evening'));

      // Outside evening
      expect(RideSlot.isTimeInAnySlot(const TimeOfDay(hour: 16, minute: 29)), isFalse);
      expect(RideSlot.isTimeInAnySlot(const TimeOfDay(hour: 17, minute: 31)), isFalse);
      expect(RideSlot.isTimeInAnySlot(const TimeOfDay(hour: 20, minute: 0)), isFalse);
    });

    test('RideSlot expiration detection for pending unaccepted requests', () {
      final now = DateTime.now();

      // Ride from 2 hours in the past
      final pastLeavingTime = now.subtract(const Duration(hours: 3));
      final pastRequest = RideRequest(
        id: 'req-past',
        passengerId: 'p-1',
        pickupLocation: 'D Type',
        officeLocation: 'Gate 3 (Factory Gate)',
        leavingTime: pastLeavingTime,
        status: 'pending',
      );

      expect(pastRequest.isSlotExpired, isTrue);
      expect(pastRequest.isExpired, isTrue);

      // Ride in future
      final futureLeavingTime = now.add(const Duration(days: 1));
      final futureRequest = RideRequest(
        id: 'req-future',
        passengerId: 'p-2',
        pickupLocation: 'C Type',
        officeLocation: 'CCR-1',
        leavingTime: futureLeavingTime,
        status: 'pending',
      );

      expect(futureRequest.isSlotExpired, isFalse);
    });

    test('RideSlot getIntervals returns valid 15-minute time intervals inside slot', () {
      final morning = RideSlot.slots[0];
      final morningIntervals = morning.getIntervals();
      expect(morningIntervals.length, equals(9));
      expect(RideSlot.formatTimeOfDay(morningIntervals.first), equals('7:00 AM'));
      expect(RideSlot.formatTimeOfDay(morningIntervals.last), equals('9:00 AM'));

      final lunch = RideSlot.slots[1];
      final lunchIntervals = lunch.getIntervals();
      expect(lunchIntervals.length, equals(9));
      expect(RideSlot.formatTimeOfDay(lunchIntervals.first), equals('12:30 PM'));
      expect(RideSlot.formatTimeOfDay(lunchIntervals.last), equals('2:30 PM'));

      final evening = RideSlot.slots[2];
      final eveningIntervals = evening.getIntervals();
      expect(eveningIntervals.length, equals(5));
      expect(RideSlot.formatTimeOfDay(eveningIntervals.first), equals('4:30 PM'));
      expect(RideSlot.formatTimeOfDay(eveningIntervals.last), equals('5:30 PM'));
    });

    testWidgets('CreateRequestScreen renders slot selection and departure time chips strictly within slots', (tester) async {
      tester.view.physicalSize = const Size(1200, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: CreateRequestScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Verify slot selection & time selection headers
      expect(find.text('1. Official Operating Slot'), findsOneWidget);
      expect(find.text('Morning Commute (07:00 AM – 09:00 AM)'), findsWidgets);
      expect(find.text('Lunch / Afternoon (12:30 PM – 02:30 PM)'), findsWidgets);
      expect(find.text('Evening Return (04:30 PM – 05:30 PM)'), findsWidgets);
      expect(find.textContaining('2. Select Departure Time'), findsOneWidget);

      // Tap Morning slot and verify morning time chips are displayed
      final morningFinder = find.text('Morning Commute (07:00 AM – 09:00 AM)').first;
      await tester.ensureVisible(morningFinder);
      await tester.tap(morningFinder);
      await tester.pumpAndSettle();

      expect(find.text('7:00 AM'), findsOneWidget);
      expect(find.text('8:00 AM'), findsOneWidget);
      expect(find.text('9:00 AM'), findsOneWidget);

      // Tap Evening slot and verify evening time chips are displayed
      final eveningFinder = find.text('Evening Return (04:30 PM – 05:30 PM)').first;
      await tester.ensureVisible(eveningFinder);
      await tester.tap(eveningFinder);
      await tester.pumpAndSettle();

      expect(find.text('4:30 PM'), findsOneWidget);
      expect(find.text('5:00 PM'), findsOneWidget);
      expect(find.text('5:30 PM'), findsOneWidget);

      // Verify Scheduled summary displays active slot
      expect(find.textContaining('Evening Return'), findsWidgets);
    });
  });
}
