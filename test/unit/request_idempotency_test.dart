import 'dart:io';

import 'package:ffl_smart_ride/features/rides/data/ride_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regression tests for F5 — idempotency on ride-request creation.
///
/// The key generator is real Dart, so it is tested for real. The collision
/// behaviour depends on a Postgres unique index and cannot be exercised without
/// a live database — see `database/DEPLOY_PENDING.sql` post-condition 10 for
/// the deliberate-duplicate check.
void main() {
  group('generateClientRequestId', () {
    test('produces a well-formed v4 UUID', () {
      final pattern = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      );

      for (var i = 0; i < 200; i++) {
        final id = generateClientRequestId();
        expect(pattern.hasMatch(id), isTrue,
            reason: '"$id" is not a valid v4 UUID; Postgres will reject it as '
                'a UUID column value');
      }
    });

    test('sets the version and variant bits', () {
      // A hand-rolled generator that omits these produces strings that look
      // like UUIDs and pass a loose regex, but are not v4.
      final id = generateClientRequestId();
      expect(id[14], equals('4'), reason: 'version nibble must be 4');
      expect('89ab'.contains(id[19]), isTrue,
          reason: 'variant nibble must be 8, 9, a or b');
    });

    test('does not repeat', () {
      final ids = List.generate(5000, (_) => generateClientRequestId()).toSet();
      expect(ids.length, equals(5000),
          reason: 'a collision here would mean one passenger silently '
              "receiving another's request row");
    });
  });

  group('schema supports the key', () {
    late String schema;
    late String deploy;

    setUpAll(() {
      schema = File('database/supabase_schema.sql').readAsStringSync();
      deploy = File('database/DEPLOY_PENDING.sql').readAsStringSync();
    });

    test('the column is added nullably', () {
      // A NOT NULL column would fail to apply against existing rows.
      expect(schema, contains('ADD COLUMN IF NOT EXISTS client_request_id UUID'));
      expect(schema, isNot(contains('client_request_id UUID NOT NULL')));
    });

    test('the unique index is partial', () {
      final start =
          schema.indexOf('CREATE UNIQUE INDEX IF NOT EXISTS uq_ride_requests_client_request_id');
      expect(start, isNot(-1));
      final idx = schema.substring(start, schema.indexOf(';', start));
      expect(idx, contains('WHERE client_request_id IS NOT NULL'),
          reason: 'rows predating this column, and clients too old to send a '
              'key, must still be insertable');
    });

    test('DEPLOY_PENDING.sql carries F5', () {
      expect(deploy, contains('ADD COLUMN IF NOT EXISTS client_request_id UUID'));
      expect(deploy, contains('uq_ride_requests_client_request_id'));
    });
  });

  group('the client sends and honours the key', () {
    late String source;

    setUpAll(() {
      source =
          File('lib/features/rides/data/ride_repository.dart').readAsStringSync();
    });

    test('createRideRequest accepts a caller-supplied key', () {
      // Without this, every call generates a fresh key and a double-tapped
      // button still creates two requests -- the key would be decorative.
      expect(source, contains('String? clientRequestId'));
      expect(source, contains('clientRequestId ?? generateClientRequestId()'));
    });

    test('the key is included in the insert payload', () {
      expect(source, contains("'client_request_id': requestKey"));
    });

    test('a duplicate key is matched narrowly, not by loose string search', () {
      // Swallowing any unique violation would hide unrelated constraint
      // failures -- including F4's uq_active_match_per_passenger -- as though
      // they were successful retries.
      expect(source, contains("error.code != '23505'"));
      expect(source, contains("detail.contains('client_request_id')"));
    });

    test('a collision returns the existing row rather than throwing', () {
      expect(source, contains("_isDuplicateClientRequestId(e)"));
      expect(source, contains("eq('client_request_id', requestKey)"));
    });
  });
}
