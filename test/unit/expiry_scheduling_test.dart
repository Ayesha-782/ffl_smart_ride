import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Regression tests for F3 — server-side expiry scheduling.
///
/// These cannot prove a cron job runs; that needs a live instance with pg_cron
/// enabled (see `progress/03_server_side_expiry.md`). They guard the two things
/// that were actually wrong and could silently regress: the status CHECK
/// constraint that made the expiry RPC impossible to run successfully, and the
/// absence of any schedule at all.
///
/// They also keep `database/DEPLOY_PENDING.sql` honest. That file is the only
/// artefact anyone will actually run, so it drifting out of sync with the
/// schema is the most likely way these fixes get half-deployed.
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

  group('status constraint permits every status the app writes', () {
    test("CHECK constraint includes 'expired'", () {
      // expire_past_slot_ride_requests() writes status = 'expired'. Until this
      // was widened the RPC raised on every call, so scheduling it would have
      // produced a failing cron job every minute forever.
      final constraint = schema.substring(
          schema.indexOf('ADD CONSTRAINT ride_requests_status_check'));
      expect(constraint.substring(0, constraint.indexOf(';')),
          contains("'expired'"));
    });

    test('the app treats expired as a real status', () {
      // Corroborates that widening the constraint is the correct fix, rather
      // than changing the RPC to write some other status.
      final model =
          File('lib/core/models/ride_request.dart').readAsStringSync();
      expect(model, contains("status == 'expired'"));
    });
  });

  group('expiry is scheduled server-side', () {
    test('a single entry point wraps both expiry RPCs', () {
      final fn = schema
          .substring(schema.indexOf('FUNCTION public.run_ride_request_expiry'));
      final body = fn.substring(0, fn.indexOf(r'$$;'));
      expect(body, contains('expire_unconfirmed_ride_requests()'));
      expect(body, contains('expire_past_slot_ride_requests()'));
    });

    test('a cron job is registered', () {
      expect(schema, contains("cron.schedule("));
      expect(schema, contains("'ride_request_expiry'"));
    });

    test('scheduling is guarded on pg_cron being present', () {
      // pg_cron is not enabled by default on Supabase. An unguarded
      // cron.schedule would abort the whole migration and take F1/F2 with it.
      expect(schema, contains("FROM pg_extension WHERE extname = 'pg_cron'"));
    });

    test('rescheduling is idempotent', () {
      // cron.unschedule raises if the job is absent, so it must be guarded on
      // the catalog rather than called unconditionally.
      expect(schema, contains('cron.unschedule'));
      expect(schema, contains("FROM cron.job WHERE jobname = 'ride_request_expiry'"));
    });

    test('the expiry entry point is not callable by clients', () {
      expect(schema,
          contains('REVOKE ALL ON FUNCTION public.run_ride_request_expiry() FROM authenticated'));
    });
  });

  group('DEPLOY_PENDING.sql stays in sync with the schema', () {
    test('carries the F1 guards', () {
      expect(deploy, contains("v_status <> 'confirmed'"));
      expect(deploy, contains('confirmation_deadline = NULL'));
    });

    test('carries the F2 policies', () {
      for (final policy in const [
        'Authenticated users can view ride requests',
        'Passengers can insert own ride requests',
        'Passengers can update own ride requests',
        'Passengers can delete own settled ride requests',
      ]) {
        expect(deploy, contains('CREATE POLICY "$policy"'));
      }
      expect(deploy,
          contains('DROP POLICY IF EXISTS "allow_all_authenticated_ride_requests"'));
    });

    test('carries the F3 constraint and schedule', () {
      expect(deploy, contains("'expired'"));
      expect(deploy, contains('cron.schedule('));
    });

    test('widens the status constraint before the policies that depend on it',
        () {
      // The DELETE policy references status = 'pending', and the expiry RPC
      // cannot run at all until 'expired' is permitted. Order matters when this
      // is applied as a single script.
      expect(deploy.indexOf('ADD CONSTRAINT ride_requests_status_check'),
          lessThan(deploy.indexOf('CREATE POLICY "Passengers can delete')));
    });

    test('is safe to run more than once', () {
      // Every statement that could collide must be guarded, or a re-run fails
      // halfway and leaves the database in a partial state.
      expect(deploy, isNot(contains('CREATE FUNCTION public.')),
          reason: 'functions must use CREATE OR REPLACE');
      for (final policy in const [
        'Authenticated users can view ride requests',
        'Passengers can insert own ride requests',
        'Passengers can update own ride requests',
        'Passengers can delete own settled ride requests',
      ]) {
        expect(deploy, contains('DROP POLICY IF EXISTS "$policy"'),
            reason: 'policy "$policy" is created without a preceding guarded '
                'drop, so a second run would fail');
      }
      expect(deploy, contains('DROP CONSTRAINT IF EXISTS ride_requests_status_check'));
    });
  });
}
