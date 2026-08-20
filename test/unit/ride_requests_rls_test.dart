import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Regression tests for F2 — the RLS hole on `public.ride_requests`.
///
/// The table previously carried a single `FOR ALL ... USING (true) WITH CHECK
/// (true)` policy, so any authenticated user could read, modify or delete any
/// other user's ride request directly through the REST API.
///
/// These assert the shape of the policy block in the schema file. They cannot
/// prove enforcement — that needs a live database and two authenticated roles
/// (see `progress/02_*.md`). What they do catch is the permissive policy being
/// reintroduced, or a per-command policy being dropped, which is how this class
/// of hole reappears in practice.
void main() {
  late String schema;

  /// `schema` with `--` line comments stripped. The schema documents the old
  /// permissive policy in a comment so future readers know what was removed and
  /// why; matching on raw text would find that prose and report the hole as
  /// still open. These assertions must look at executable SQL only.
  late String sql;

  setUpAll(() {
    schema = File('database/supabase_schema.sql').readAsStringSync();
    sql = schema
        .split('\n')
        .map((line) {
          final comment = line.indexOf('--');
          return comment == -1 ? line : line.substring(0, comment);
        })
        .join('\n');
  });

  /// The text of a `CREATE POLICY "<name>"` statement, up to its terminating `;`.
  String policy(String name) {
    final start = sql.indexOf('CREATE POLICY "$name"');
    expect(start, isNot(-1), reason: 'policy "$name" not found in schema');
    return sql.substring(start, sql.indexOf(';', start));
  }

  test('the blanket allow-all policy is gone', () {
    // Only the commented-out description of the old policy may mention it, and
    // the DROP that removes it -- never a live CREATE.
    expect(sql, isNot(contains('CREATE POLICY "allow_all_authenticated_ride_requests"')),
        reason: 'the permissive FOR ALL policy must not be recreated');
  });

  test('no policy on ride_requests grants FOR ALL', () {
    final matches = RegExp(
      r'CREATE POLICY[^;]*ON public\.ride_requests FOR ALL',
      multiLine: true,
    ).allMatches(sql);
    expect(matches, isEmpty,
        reason: 'ride_requests must use per-command policies, not FOR ALL');
  });

  group('per-command policies exist and are correctly scoped', () {
    test('SELECT stays open to authenticated users', () {
      // Deliberate: drivers must be able to browse the open request queue.
      final p = policy('Authenticated users can view ride requests');
      expect(p, contains('FOR SELECT'));
      expect(p, contains('USING (true)'));
    });

    test('INSERT is scoped to the caller', () {
      // Omitting an INSERT policy entirely would deny all request creation,
      // since removing the FOR ALL policy removes the only INSERT grant.
      final p = policy('Passengers can insert own ride requests');
      expect(p, contains('FOR INSERT'));
      expect(p, contains('WITH CHECK (auth.uid() = passenger_id)'));
    });

    test('UPDATE is scoped to the caller, and cannot reassign ownership', () {
      final p = policy('Passengers can update own ride requests');
      expect(p, contains('FOR UPDATE'));
      expect(p, contains('USING (auth.uid() = passenger_id)'));
      expect(p, contains('WITH CHECK (auth.uid() = passenger_id)'),
          reason: 'without WITH CHECK a passenger could rewrite passenger_id '
              'and hand the row to another user');
    });

    test('DELETE is scoped to the caller and to non-actionable rows', () {
      final p = policy('Passengers can delete own settled ride requests');
      expect(p, contains('FOR DELETE'));
      expect(p, contains('auth.uid() = passenger_id'));
      expect(p, contains("status IN ('cancelled', 'completed')"));
    });

    test('DELETE still covers an expired pending request', () {
      // The UI offers "Delete Expired Request" for a pending row whose
      // departure time has passed; excluding it would make that button a no-op.
      final p = policy('Passengers can delete own settled ride requests');
      expect(p, contains("status = 'pending'"));
      expect(p, contains('leaving_time <'));
    });
  });

  test('drivers get no direct UPDATE grant', () {
    // Driver-side transitions run through SECURITY DEFINER RPCs, which bypass
    // RLS. A driver_id-based UPDATE policy would reopen the F1 hole.
    expect(sql, isNot(contains('USING (auth.uid() = driver_id)\n    WITH CHECK')),
        reason: 'drivers must transition rides via RPC, not direct UPDATE');
  });
}
