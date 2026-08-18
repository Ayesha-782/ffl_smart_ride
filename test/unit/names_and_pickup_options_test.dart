import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ffl_smart_ride/core/models/ride_request.dart';
import 'package:ffl_smart_ride/core/models/user_profile.dart';
import 'package:ffl_smart_ride/core/widgets/profile_card.dart';
import 'package:ffl_smart_ride/features/rides/screens/create_request_screen.dart';

void main() {
  group('Names Display & Pickup Options Test Suite', () {
    testWidgets('ProfileCard displays passenger actual full name instead of Colleague', (tester) async {
      const profile = UserProfile(
        id: 'p-101',
        employeeId: 'FFL-555',
        fullName: 'Muhammad Usman',
        phone: '03001234567',
        homeAddress: 'House 12, D Type Quarters',
        pickupStopOrder: 1,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ProfileCard(
              profile: profile,
              pickupStopName: 'D Type Quarters',
            ),
          ),
        ),
      );

      expect(find.text('Muhammad Usman'), findsOneWidget);
      expect(find.text('Colleague'), findsNothing);
    });

    testWidgets('ProfileCard falls back to Employee ID when full name is empty', (tester) async {
      const profile = UserProfile(
        id: 'p-102',
        employeeId: 'FFL-888',
        fullName: '',
        phone: '03001234567',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ProfileCard(
              profile: profile,
            ),
          ),
        ),
      );

      expect(find.text('Employee (FFL-888)'), findsOneWidget);
      expect(find.text('Colleague'), findsNothing);
    });

    test('RideRequest correctly parses passenger and driver names from joined Supabase profiles', () {
      final json = {
        'id': 'req-999',
        'passenger_id': 'p-1',
        'driver_id': 'd-1',
        'pickup_location': 'D Type Quarters',
        'office_location': 'Factory Plant',
        'pickup_stop_order': 1,
        'leaving_time': '2026-08-18T09:00:00Z',
        'status': 'accepted',
        'passenger': {
          'id': 'p-1',
          'employee_id': 'FFL-101',
          'full_name': 'Zain Ul Abidin',
          'phone': '03001111111',
          'home_address': 'House 7, E Type',
        },
        'driver': {
          'id': 'd-1',
          'employee_id': 'FFL-202',
          'full_name': 'Kamran Tariq',
          'phone': '03002222222',
          'vehicle_number': 'LEA-1234',
        },
      };

      final ride = RideRequest.fromJson(json);
      expect(ride.passenger?.fullName, equals('Zain Ul Abidin'));
      expect(ride.driver?.fullName, equals('Kamran Tariq'));
    });

    testWidgets('CreateRequestScreen renders 2-way flow pickup and destination dropdowns with swap capability', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: CreateRequestScreen(),
        ),
      );

      // Verify the screen loads with 2-way flow title and dropdown fields
      expect(find.text('Create Ride Request'), findsOneWidget);
      expect(find.text('Pickup Landmark / Exact Address'), findsNothing);
      expect(find.text('Destination Landmark / Exact Address'), findsNothing);
      expect(find.text('Swap Direction (2-Way Flow)'), findsOneWidget);
      expect(find.text('D Type'), findsWidgets);
      expect(find.text('Gate 3 (Factory Gate)'), findsWidgets);

      // Test swap action
      await tester.tap(find.text('Swap Direction (2-Way Flow)'));
      await tester.pump();

      // Ensure swap button is interactive
      expect(find.text('Swap Direction (2-Way Flow)'), findsOneWidget);
    });
  });
}
