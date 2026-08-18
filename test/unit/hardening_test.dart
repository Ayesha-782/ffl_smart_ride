import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ffl_smart_ride/features/rides/widgets/no_session_open_card.dart';

void main() {
  group('System Hardening & Empty State Test Suite', () {
    testWidgets('NoSessionOpenCard renders shift windows and refresh trigger', (tester) async {
      bool refreshed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NoSessionOpenCard(
              onRefresh: () => refreshed = true,
            ),
          ),
        ),
      );

      expect(find.text('No Active Ride Session Right Now'), findsOneWidget);
      expect(find.text('Morning Commute'), findsOneWidget);
      expect(find.text('07:00 AM – 09:00 AM'), findsOneWidget);
      expect(find.text('Lunch / Afternoon'), findsOneWidget);
      expect(find.text('Evening Return'), findsOneWidget);

      await tester.tap(find.byType(IconButton));
      expect(refreshed, isTrue);
    });

    test('Conflict detection recognizes concurrent match race conditions', () {
      const conflictError1 = 'One or more selected passengers have already been matched with another driver. Please refresh your queue.';
      const conflictError2 = 'Passenger 3a9c7b12 is not in the queue for this session.';
      const networkError = 'Connection failed, please check your internet.';

      bool isConflict(String msg) {
        final lower = msg.toLowerCase();
        return lower.contains('already been matched') || lower.contains('not in the queue');
      }

      expect(isConflict(conflictError1), isTrue);
      expect(isConflict(conflictError2), isTrue);
      expect(isConflict(networkError), isFalse);
    });
  });
}
