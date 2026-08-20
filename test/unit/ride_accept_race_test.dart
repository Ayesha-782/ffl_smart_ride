import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Regression tests for F1 — the ad-hoc ride-request double-booking race.
///
/// The race itself is resolved inside Postgres: `accept_ride_request` takes a
/// `SELECT ... FOR UPDATE` row lock so two concurrent accepts are serialised.
/// Exercising that for real needs a live database and two concurrent sessions,
/// which these unit tests have no access to — see `progress/01_*.md` for the
/// end-to-end concurrency check that belongs in the integration pass.
///
/// What *is* checkable here, and what actually regressed before, is the shape of
/// the client: the bug was not that the lock was missing, but that the Flutter
/// client bypassed the locking RPC entirely with a read-then-write, and that the
/// other three mutations silently fell back to unsafe client writes whenever the
/// RPC errored. These tests fail if any of that comes back.
void main() {
  late String repositorySource;
  late String schemaSource;

  setUpAll(() {
    repositorySource =
        File('lib/features/rides/data/ride_repository.dart').readAsStringSync();
    schemaSource = File('database/supabase_schema.sql').readAsStringSync();
  });

  /// Extracts the body of a method declared as `Future<void> <name>({`.
  String methodBody(String source, String name) {
    final start = source.indexOf('Future<void> $name({');
    expect(start, isNot(-1), reason: 'method $name not found in repository');

    final bodyStart = source.indexOf('{', source.indexOf(') async', start));
    var depth = 0;
    for (var i = bodyStart; i < source.length; i++) {
      if (source[i] == '{') depth++;
      if (source[i] == '}') {
        depth--;
        if (depth == 0) return source.substring(bodyStart, i + 1);
      }
    }
    fail('could not find end of $name body');
  }

  group('F1 — accept path goes through the locking RPC only', () {
    test('acceptRide calls accept_ride_request', () {
      expect(methodBody(repositorySource, 'acceptRide'),
          contains("'accept_ride_request'"));
    });

    test('acceptRide performs no direct write to ride_requests', () {
      final body = methodBody(repositorySource, 'acceptRide');

      // The original bug: read the row, check status in Dart, then UPDATE.
      // Whichever driver lost the race still saw a silent success because the
      // affected-row count was never inspected.
      expect(body, isNot(contains(".from('ride_requests')")),
          reason: 'acceptRide must not read or write ride_requests directly; '
              'the accept_ride_request RPC holds the row lock');
    });

    test('acceptRide does not insert a duplicate notification', () {
      // accept_ride_request already inserts the passenger notification.
      expect(methodBody(repositorySource, 'acceptRide'),
          isNot(contains("from('notifications')")),
          reason: 'the RPC notifies the passenger; doing it here too would '
              'deliver two notifications per accept');
    });
  });

  group('F1 — no unsafe client-side fallbacks remain', () {
    for (final method in const [
      'acceptRide',
      'confirmRide',
      'completeRide',
      'cancelRideOffer',
    ]) {
      test('$method has no swallow-and-degrade fallback', () {
        final body = methodBody(repositorySource, method);
        expect(body, isNot(contains('catch (_)')),
            reason: '$method must surface RPC failures to the caller rather '
                'than silently degrading to a client-side write');
      });

      test('$method writes through an RPC, not a table update', () {
        final body = methodBody(repositorySource, method);
        expect(body, isNot(contains(".update({")),
            reason: '$method must not write to ride_requests from the client');
      });
    }
  });

  group('F1 — database guards the client no longer duplicates', () {
    test('accept_ride_request serialises concurrent accepts', () {
      final fn = schemaSource.substring(
          schemaSource.indexOf('FUNCTION public.accept_ride_request'));
      expect(fn.substring(0, fn.indexOf(r'$$;')), contains('FOR UPDATE'));
    });

    test('complete_ride_request enforces confirmed status', () {
      // This guard used to live only in Dart, so a direct API call could
      // complete a ride the passenger never confirmed — and log CO2 for it.
      final fn = schemaSource.substring(
          schemaSource.indexOf('FUNCTION public.complete_ride_request'));
      final body = fn.substring(0, fn.indexOf(r'$$;'));
      expect(body, contains("v_status <> 'confirmed'"));
      expect(body, contains('FOR UPDATE'));
    });

    test('cancel_ride_offer clears the confirmation deadline', () {
      final fn = schemaSource
          .substring(schemaSource.indexOf('FUNCTION public.cancel_ride_offer'));
      final body = fn.substring(0, fn.indexOf(r'$$;'));
      expect(body, contains('confirmation_deadline = NULL'),
          reason: 'a row returned to pending must not keep the previous '
              "driver's expiry deadline");
      expect(body, contains('FOR UPDATE'));
    });
  });
}
