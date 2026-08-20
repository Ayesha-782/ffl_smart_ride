import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Regression tests for F4 — defense-in-depth constraints.
///
/// These are backstops for rules the application already enforces, so the thing
/// worth guarding is that they stay *independent* of that application logic:
/// partial rather than total, permissive where the plan says to be permissive,
/// and reachable from the deploy script.
///
/// As with F1-F3 these assert SQL shape, not enforcement. Proving the index
/// rejects a duplicate needs a live database — the deliberate-violation
/// smoke tests are written out in `database/DEPLOY_PENDING.sql` post-conditions
/// 7 and 8 for whoever applies it.
void main() {
  late String schema;
  late String deploy;

  String stripComments(String source) => source
      .split('\n')
      .map((line) {
        final comment = line.indexOf('--');
        return comment == -1 ? line : line.substring(0, comment);
      })
      .join('\n');

  setUpAll(() {
    schema = stripComments(
        File('database/supabase_schema.sql').readAsStringSync());
    deploy =
        stripComments(File('database/DEPLOY_PENDING.sql').readAsStringSync());
  });

  String statement(String source, String needle) {
    final start = source.indexOf(needle);
    expect(start, isNot(-1), reason: '"$needle" not found');
    return source.substring(start, source.indexOf(';', start));
  }

  group('F4.1 — one active match per passenger per session', () {
    test('the unique index exists on the right columns', () {
      final idx = statement(schema, 'CREATE UNIQUE INDEX IF NOT EXISTS uq_active_match_per_passenger');
      expect(idx, contains('ON public.ride_matches'));
      expect(idx, contains('(session_id, passenger_id)'));
    });

    test('the index is partial, not total', () {
      // Without the WHERE clause this would forbid a passenger from ever being
      // re-matched in a session after a cancellation, since cancelled and
      // completed rows stay in the table as history.
      final idx = statement(schema, 'CREATE UNIQUE INDEX IF NOT EXISTS uq_active_match_per_passenger');
      expect(idx, contains("WHERE status = 'active'"));
    });

    test('it is guarded so a re-run does not fail', () {
      expect(schema, contains('CREATE UNIQUE INDEX IF NOT EXISTS uq_active_match_per_passenger'));
    });
  });

  group('F4.2 — seats offered cannot exceed vehicle capacity', () {
    test('a BEFORE INSERT OR UPDATE trigger is installed', () {
      final trg = statement(schema, 'CREATE TRIGGER trg_driver_availability_seats');
      expect(trg, contains('BEFORE INSERT OR UPDATE'));
      expect(trg, contains('ON public.driver_availability'));
      expect(trg, contains('FOR EACH ROW'));
    });

    test('the trigger is dropped before being created', () {
      expect(schema,
          contains('DROP TRIGGER IF EXISTS trg_driver_availability_seats ON public.driver_availability'));
    });

    test('it compares against the vehicle capacity', () {
      final fn = schema.substring(schema.indexOf('FUNCTION public.trg_validate_seats_offered'));
      final body = fn.substring(0, fn.indexOf(r'$$ LANGUAGE'));
      expect(body, contains('FROM public.vehicles'));
      expect(body, contains('NEW.seats_offered > v_capacity'));
    });

    test('a driver with no registered vehicle is NOT blocked', () {
      // The README's test admin account has no vehicle row. Failing closed here
      // would lock those accounts out of creating availability entirely.
      final fn = schema.substring(schema.indexOf('FUNCTION public.trg_validate_seats_offered'));
      final body = fn.substring(0, fn.indexOf(r'$$ LANGUAGE'));
      expect(body, contains('IF NOT FOUND'));
      expect(body, contains('RETURN NEW'));

      final guardIndex = body.indexOf('IF NOT FOUND');
      final raiseIndex = body.indexOf('RAISE EXCEPTION');
      expect(guardIndex, lessThan(raiseIndex),
          reason: 'the missing-vehicle escape must come before the capacity '
              'check, or drivers without a vehicle would be rejected');
    });
  });

  group('DEPLOY_PENDING.sql carries F4', () {
    test('index and trigger are both present', () {
      expect(deploy, contains('uq_active_match_per_passenger'));
      expect(deploy, contains('CREATE TRIGGER trg_driver_availability_seats'));
    });

    test('the deploy copy is also partial and permissive', () {
      // Drift between the two files is the most likely way a constraint gets
      // deployed in a stricter form than it was designed in.
      final idx = statement(deploy, 'CREATE UNIQUE INDEX IF NOT EXISTS uq_active_match_per_passenger');
      expect(idx, contains("WHERE status = 'active'"));

      final fn = deploy.substring(deploy.indexOf('FUNCTION public.trg_validate_seats_offered'));
      expect(fn.substring(0, fn.indexOf(r'$$ LANGUAGE')), contains('IF NOT FOUND'));
    });
  });
}
