import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ffl_smart_ride/core/models/user_profile.dart';
import 'package:ffl_smart_ride/core/models/vehicle.dart';
import 'package:ffl_smart_ride/core/widgets/profile_card.dart';

void main() {
  group('ProfileCard Widget Test Suite', () {
    testWidgets('Renders passenger details with stop badge and house address', (tester) async {
      const profile = UserProfile(
        id: 'p-101',
        employeeId: 'FFL-888',
        fullName: 'Sarah Ahmed',
        phone: '03009876543',
        homeAddress: 'House 45, Sector B',
        pickupStopOrder: 4,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ProfileCard(
              profile: profile,
              pickupStopName: 'Sector B (Staff Quarters / Club)',
              stopsAway: 1,
            ),
          ),
        ),
      );

      expect(find.text('Sarah Ahmed'), findsOneWidget);
      expect(find.textContaining('FFL-888'), findsOneWidget);
      expect(find.textContaining('House 45, Sector B'), findsOneWidget);
      expect(find.textContaining('Stop #4'), findsOneWidget);
      expect(find.text('1 Stop Away'), findsOneWidget);
    });

    testWidgets('Renders driver details with vehicle make, model, and plate', (tester) async {
      const vehicle = Vehicle(
        id: 'v-202',
        userId: 'd-101',
        vehicleType: 'Car',
        make: 'Toyota',
        model: 'Corolla',
        licensePlate: 'LEA-9999',
        capacity: 4,
      );

      const driverProfile = UserProfile(
        id: 'd-101',
        employeeId: 'FFL-777',
        fullName: 'Ali Khan',
        phone: '03001112233',
        vehicleNumber: 'LEA-9999',
        hasVehicle: true,
        vehicle: vehicle,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ProfileCard(
              profile: driverProfile,
              vehicle: vehicle,
              isDriver: true,
              seatsOffered: 4,
              seatsRemaining: 2,
            ),
          ),
        ),
      );

      expect(find.text('Ali Khan'), findsOneWidget);
      expect(find.textContaining('Toyota Corolla'), findsOneWidget);
      expect(find.text('LEA-9999'), findsOneWidget);
      expect(find.text('2 of 4 Seats'), findsOneWidget);
    });
  });
}
