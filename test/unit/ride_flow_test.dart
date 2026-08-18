import 'package:flutter_test/flutter_test.dart';
import 'package:ffl_smart_ride/core/models/ride_request.dart';
import 'package:ffl_smart_ride/core/models/app_notification.dart';

void main() {
  group('Ride Flow & Matching State Lifecycle Tests', () {
    final now = DateTime.now();

    final openRequest = RideRequest(
      id: 'req-1',
      passengerId: 'user-passenger',
      pickupLocation: 'Township Gate 1',
      officeLocation: 'Factory Main Plant',
      leavingTime: now.add(const Duration(hours: 1)),
      status: 'pending',
      createdAt: now,
    );

    final acceptedRequest = RideRequest(
      id: 'req-1',
      passengerId: 'user-passenger',
      driverId: 'user-driver-1',
      pickupLocation: 'Township Gate 1',
      officeLocation: 'Factory Main Plant',
      leavingTime: now.add(const Duration(hours: 1)),
      status: 'accepted',
      createdAt: now,
      updatedAt: now,
    );

    final confirmedRequest = RideRequest(
      id: 'req-1',
      passengerId: 'user-passenger',
      driverId: 'user-driver-1',
      pickupLocation: 'Township Gate 1',
      officeLocation: 'Factory Main Plant',
      leavingTime: now.add(const Duration(hours: 1)),
      status: 'confirmed',
      createdAt: now,
      updatedAt: now.add(const Duration(minutes: 2)),
    );

    test('Open Request is visible in available requests filter', () {
      final allRequests = [openRequest, acceptedRequest, confirmedRequest];

      // getAvailableRequests filter: status == 'pending' && driverId == null
      final available = allRequests
          .where((r) => r.status == 'pending' && r.driverId == null)
          .toList();

      expect(available.length, 1);
      expect(available.first.id, 'req-1');
      expect(available.first.driverId, isNull);
    });

    test('Accepted Request disappears from open requests and appears in driver roster', () {
      final allRequests = [acceptedRequest];

      // 1. Must NOT appear in open requests
      final open = allRequests
          .where((r) => r.status == 'pending' && r.driverId == null)
          .toList();
      expect(open.isEmpty, isTrue);

      // 2. MUST appear in driver's roster
      final driverRoster = allRequests
          .where((r) => r.driverId == 'user-driver-1' && (r.status == 'accepted' || r.status == 'confirmed'))
          .toList();
      expect(driverRoster.length, 1);
      expect(driverRoster.first.status, 'accepted');
    });

    test('Active Ride Offer detection for Passenger Home Screen', () {
      final myRequests = [acceptedRequest];

      // Passenger Home Screen checks for status == 'accepted' and driverId != null
      final activeOffer = myRequests
          .where((r) => r.status == 'accepted' && r.driverId != null)
          .firstOrNull;

      expect(activeOffer, isNotNull);
      expect(activeOffer!.driverId, 'user-driver-1');
      expect(activeOffer.status, 'accepted');
    });

    test('5-Minute Confirmation Timer calculation', () {
      final acceptedAt = DateTime.now().toUtc().subtract(const Duration(minutes: 2, seconds: 30));
      final elapsed = DateTime.now().toUtc().difference(acceptedAt).inSeconds;
      final remaining = (300 - elapsed).clamp(0, 300);

      expect(remaining, greaterThan(140));
      expect(remaining, lessThan(160));
      final mins = (remaining ~/ 60).toString().padLeft(2, '0');
      expect(mins, '02');
    });

    test('RideRequest isConfirmationExpired and remainingConfirmationSeconds getters', () {
      final activeOffer = RideRequest(
        id: 'req-active',
        passengerId: 'p-1',
        driverId: 'd-1',
        pickupLocation: 'Township Gate 1',
        officeLocation: 'Factory Main Plant',
        leavingTime: now.add(const Duration(hours: 1)),
        status: 'accepted',
        confirmationDeadline: DateTime.now().toUtc().add(const Duration(minutes: 4)),
        createdAt: now,
      );

      expect(activeOffer.isConfirmationExpired, isFalse);
      expect(activeOffer.remainingConfirmationSeconds, greaterThan(200));

      final expiredOffer = RideRequest(
        id: 'req-expired',
        passengerId: 'p-1',
        driverId: 'd-1',
        pickupLocation: 'Township Gate 1',
        officeLocation: 'Factory Main Plant',
        leavingTime: now.add(const Duration(hours: 1)),
        status: 'accepted',
        confirmationDeadline: DateTime.now().toUtc().subtract(const Duration(seconds: 10)),
        createdAt: now.subtract(const Duration(minutes: 6)),
      );

      expect(expiredOffer.isConfirmationExpired, isTrue);
      expect(expiredOffer.remainingConfirmationSeconds, equals(0));
    });

    test('Expired unconfirmed ride offer reverts to open request for other drivers', () {
      final expiredOffer = RideRequest(
        id: 'req-1',
        passengerId: 'p-1',
        driverId: 'd-1',
        pickupLocation: 'Township Gate 1',
        officeLocation: 'Factory Main Plant',
        leavingTime: now.add(const Duration(hours: 1)),
        status: 'accepted',
        confirmationDeadline: DateTime.now().toUtc().subtract(const Duration(minutes: 1)),
      );

      // Simulation of autoReleaseExpiredOffers
      final releasedRequest = expiredOffer.isConfirmationExpired
          ? expiredOffer.copyWith(
              clearDriver: true,
              status: 'pending',
              clearDeadline: true,
            )
          : expiredOffer;

      expect(releasedRequest.status, equals('pending'));
      expect(releasedRequest.driverId, isNull);
      expect(releasedRequest.isPending, isTrue);

      // Verify it appears in open requests filter for other drivers
      final openRequests = [releasedRequest]
          .where((r) => r.status == 'pending' && r.driverId == null)
          .toList();

      expect(openRequests.length, equals(1));
      expect(openRequests.first.id, equals('req-1'));
    });

    test('Accept button is disabled when 5-minute timeout expires', () {
      final expiredOffer = RideRequest(
        id: 'req-1',
        passengerId: 'p-1',
        driverId: 'd-1',
        pickupLocation: 'Township Gate 1',
        officeLocation: 'Factory Main Plant',
        leavingTime: now.add(const Duration(hours: 1)),
        status: 'accepted',
        confirmationDeadline: DateTime.now().toUtc().subtract(const Duration(seconds: 5)),
      );

      final remainSec = expiredOffer.remainingConfirmationSeconds;
      final isExpired = remainSec <= 0 || expiredOffer.isConfirmationExpired;
      final isButtonEnabled = !isExpired;

      expect(isExpired, isTrue);
      expect(isButtonEnabled, isFalse);
    });

    test('AppNotification model serialization for ride offer', () {
      final notif = AppNotification(
        id: 'notif-1',
        userId: 'user-passenger',
        rideId: 'req-1',
        title: 'Ride Offer Received! 🚗',
        message: 'A colleague has offered you a lift.',
        type: 'ride_accepted',
        isRead: false,
        createdAt: now,
      );

      final json = notif.toJson();
      expect(json['title'], 'Ride Offer Received! 🚗');
      expect(json['type'], 'ride_accepted');
      expect(json['is_read'], isFalse);

      final deserialized = AppNotification.fromJson({
        'id': 'notif-1',
        'user_id': 'user-passenger',
        'ride_id': 'req-1',
        'title': 'Ride Offer Received! 🚗',
        'message': 'A colleague has offered you a lift.',
        'type': 'ride_accepted',
        'is_read': false,
        'created_at': now.toIso8601String(),
      });

      expect(deserialized.id, 'notif-1');
      expect(deserialized.type, 'ride_accepted');
    });
  });
}
