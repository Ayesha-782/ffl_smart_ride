import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// TEST_PLAN.md §4 — ride status transitions may only move forward through the
/// legal state machine, and illegal transitions must be rejected.
///
/// The state machine is enforced in the RPCs, so these verify each transition
/// carries its guard in `database/supabase_schema.sql`. **This is a static
/// assertion over SQL text.** It catches a guard being deleted or weakened,
/// which is the realistic regression. It does NOT prove Postgres rejects an
/// illegal transition at runtime — that needs a live instance and is recorded
/// as BLOCKED in TEST_RESULTS.md §4.
///
/// Legal machine: pending -> accepted -> confirmed -> completed,
/// plus accepted -> pending (cancel offer / expiry) and -> cancelled.
void main() {
  late String sql;

  setUpAll(() {
    sql = File('database/supabase_schema.sql')
        .readAsStringSync()
        .split('\n')
        .map((line) {
          final c = line.indexOf('--');
          return c == -1 ? line : line.substring(0, c);
        })
        .join('\n');
  });

  String functionBody(String name) {
    final start = sql.indexOf('FUNCTION public.$name');
    expect(start, isNot(-1), reason: 'function $name not found');
    final tail = sql.substring(start);
    final end = tail.indexOf(r'$$;');
    return tail.substring(0, end == -1 ? tail.length : end);
  }

  group('§4 — each transition guards its source status', () {
    test('accept requires pending', () {
      // Blocks accepted -> accepted (double booking) and completed -> accepted.
      expect(functionBody('accept_ride_request'), contains("v_status <> 'pending'"));
    });

    test('confirm requires accepted', () {
      // Blocks pending -> confirmed, skipping the driver offer entirely.
      expect(functionBody('confirm_ride_request'), contains("v_status <> 'accepted'"));
    });

    test('complete requires confirmed', () {
      // Blocks the illegal pending -> completed jump TEST_PLAN §4 names
      // explicitly, and accepted -> completed.
      expect(functionBody('complete_ride_request'), contains("v_status <> 'confirmed'"));
    });

    test('cancel offer requires the caller to be the assigned driver', () {
      expect(functionBody('cancel_ride_offer'), contains('driver_id = v_driver_id'));
    });
  });

  group('§4 — transitions are serialised against concurrent writers', () {
    for (final fn in const [
      'accept_ride_request',
      'confirm_ride_request',
      'complete_ride_request',
      'cancel_ride_offer',
    ]) {
      test('$fn locks the row before deciding', () {
        // Without FOR UPDATE the guard is checked against a value that another
        // transaction may already be changing -- the guard becomes advisory.
        expect(functionBody(fn), contains('FOR UPDATE'));
      });
    }
  });

  group('§4 — the illegal jump TEST_PLAN calls out by name', () {
    test('pending -> completed is rejected', () {
      final body = functionBody('complete_ride_request');

      // Both halves matter: the guard must exist, and it must sit before the
      // UPDATE. A guard after the write would not prevent anything.
      final guard = body.indexOf("v_status <> 'confirmed'");
      final update = body.indexOf("SET status = 'completed'");

      expect(guard, isNot(-1), reason: 'no confirmed-status guard');
      expect(update, isNot(-1), reason: 'no completion UPDATE found');
      expect(guard, lessThan(update),
          reason: 'the status guard must precede the UPDATE it protects');
    });

    test('the CO2 log write sits behind the same guard', () {
      // A completion that is rejected must not still write a saving row.
      final body = functionBody('complete_ride_request');
      expect(body.indexOf("v_status <> 'confirmed'"),
          lessThan(body.indexOf('INSERT INTO public.ride_completion_log')),
          reason: 'an unconfirmed ride must not produce an audit/CO2 record');
    });
  });

  group('§4 — status vocabulary is consistent between app and database', () {
    test('every status the app writes is permitted by the CHECK constraint', () {
      final constraintStart = sql.indexOf('ADD CONSTRAINT ride_requests_status_check');
      final constraint =
          sql.substring(constraintStart, sql.indexOf(';', constraintStart));

      for (final status in const [
        'pending',
        'accepted',
        'confirmed',
        'completed',
        'cancelled',
        'expired',
      ]) {
        expect(constraint, contains("'$status'"),
            reason: "status '$status' is written by the app but would be "
                'rejected by the CHECK constraint');
      }
    });
  });
}
