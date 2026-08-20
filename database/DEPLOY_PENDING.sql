-- =============================================================================
-- DEPLOY_PENDING.sql — consolidated, not-yet-applied database changes
-- =============================================================================
--
-- Every schema / RPC / policy change made by the Claude Code fix pass, in the
-- order they must be applied, as one runnable script.
--
-- Covers: F1, F2, F3.   Last updated: 2026-08-21
--
-- WHY THIS FILE EXISTS
--   None of these changes have been applied to any live database. They were
--   authored without Supabase dashboard access. `database/supabase_schema.sql`
--   is the full schema and is the source of truth; this file is the delta from
--   what is currently deployed, so it can be run in one pass without replaying
--   the entire schema.
--
-- HOW TO RUN
--   Supabase dashboard -> SQL Editor -> paste -> Run. Everything is guarded with
--   DROP ... IF EXISTS / CREATE OR REPLACE and is safe to run more than once.
--   Wrap in BEGIN; ... COMMIT; if you want all-or-nothing (see the pg_cron note
--   in section F3 first — that section is deliberately non-fatal).
--
-- READ BEFORE RUNNING — behaviour changes, not just additions:
--   * F1 makes complete_ride_request reject any ride that is not 'confirmed'.
--     Any flow that completes an unconfirmed ride starts failing loudly.
--   * F2 removes a blanket allow-all policy. Any direct client write to
--     ride_requests that is not the passenger acting on their own row will
--     start being denied — this is the point of the fix, but it will surface
--     as behaviour change in anything relying on the old permissiveness.
--   * F3 widens the status CHECK constraint. Rows may now legitimately hold
--     status 'expired', which previously could never be written.
--
-- VERIFICATION STATUS — read this honestly:
--   None of this SQL has been executed anywhere. It has been reviewed by
--   reading only. The Dart-side tests assert the *shape* of this file's
--   statements, not their runtime behaviour. Whoever applies this should treat
--   it as unvalidated and check the post-conditions at the end.
-- =============================================================================


-- =============================================================================
-- F1 — Double-booking race condition
-- =============================================================================
-- The Flutter client no longer writes ride_requests directly for accept /
-- confirm / complete / cancel-offer; it calls these RPCs only. Two guards that
-- previously lived in Dart therefore have to exist here, or they exist nowhere.

-- F1.1 — complete_ride_request: add the 'must be confirmed' guard and a row lock.
-- Previously this function checked only that the caller was the driver or the
-- passenger. The status rule lived solely in the Dart client, so a direct API
-- call could complete an unconfirmed ride AND write a CO2 saving row for a trip
-- that was never agreed to.
CREATE OR REPLACE FUNCTION public.complete_ride_request(p_ride_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_passenger_id UUID;
    v_driver_id UUID;
    v_status TEXT;
    v_dist NUMERIC;
    v_emiss NUMERIC;
    v_co2 NUMERIC;
BEGIN
    SELECT passenger_id, driver_id, status INTO v_passenger_id, v_driver_id, v_status
    FROM public.ride_requests
    WHERE id = p_ride_id AND (driver_id = v_user_id OR passenger_id = v_user_id)
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Ride request not found or unauthorized';
    END IF;

    IF v_status <> 'confirmed' THEN
        RAISE EXCEPTION 'Cannot complete ride: passenger has not confirmed the ride offer yet (current status: %)', v_status;
    END IF;

    UPDATE public.ride_requests
    SET status = 'completed',
        updated_at = timezone('utc'::text, now())
    WHERE id = p_ride_id;

    IF v_driver_id IS NOT NULL THEN
        SELECT COALESCE(value, 2.5) INTO v_dist FROM public.app_config WHERE key = 'route_distance_km' LIMIT 1;
        IF v_dist IS NULL THEN v_dist := 2.5; END IF;

        SELECT COALESCE(value, 0.12) INTO v_emiss FROM public.app_config WHERE key = 'emission_factor_kg_per_km' LIMIT 1;
        IF v_emiss IS NULL THEN v_emiss := 0.12; END IF;

        v_co2 := (v_dist * v_emiss * 1.0)::NUMERIC(10, 4);

        INSERT INTO public.ride_completion_log (
            session_id, driver_id, passenger_ids, passenger_count,
            distance_km, emission_factor_kg_per_km, kg_co2_saved, completed_at
        ) VALUES (
            NULL, v_driver_id, ARRAY[v_passenger_id], 1,
            v_dist, v_emiss, v_co2, timezone('utc'::text, now())
        );
    END IF;

    INSERT INTO public.notifications (user_id, ride_id, title, message, type)
    VALUES (
        v_passenger_id, p_ride_id, 'Trip Completed 🌿',
        'Your carpool trip is complete. Thank you for helping reduce emissions!',
        'ride_completed'
    );

    RETURN jsonb_build_object('success', true, 'status', 'completed', 'kg_co2_saved', v_co2);
END;
$$;

-- F1.2 — cancel_ride_offer: clear confirmation_deadline, and lock the row.
-- Returning a row to 'pending' while leaving the previous driver's deadline
-- attached leaves stale expiry state pointing at an offer that no longer exists.
CREATE OR REPLACE FUNCTION public.cancel_ride_offer(p_ride_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_driver_id UUID := auth.uid();
    v_passenger_id UUID;
    v_driver_name TEXT;
BEGIN
    SELECT passenger_id INTO v_passenger_id
    FROM public.ride_requests
    WHERE id = p_ride_id AND driver_id = v_driver_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Ride request not found or you are not the assigned driver';
    END IF;

    UPDATE public.ride_requests
    SET driver_id = NULL,
        status = 'pending',
        confirmation_deadline = NULL,
        updated_at = timezone('utc'::text, now())
    WHERE id = p_ride_id;

    SELECT full_name INTO v_driver_name FROM public.profiles WHERE id = v_driver_id;

    INSERT INTO public.notifications (user_id, ride_id, title, message, type)
    VALUES (
        v_passenger_id, p_ride_id, 'Ride Offer Cancelled',
        COALESCE(v_driver_name, 'The driver') || ' is unable to give a lift. Your request is now back in the open queue.',
        'ride_cancelled'
    );

    RETURN jsonb_build_object('success', true, 'status', 'pending');
END;
$$;


-- =============================================================================
-- F3 (constraint) — widen the status CHECK
-- =============================================================================
-- Applied BEFORE the F2 policies because the F2 DELETE policy references
-- status = 'pending', and because expire_past_slot_ride_requests() cannot
-- succeed at all until 'expired' is permitted.
--
-- 'expired' was missing even though the app has always treated it as real
-- (RideRequest.isExpired, and the 'expired' status chip in the UI). Every
-- writer of that status has therefore always failed:
--   * expire_past_slot_ride_requests() raised on every call — the RPC F3
--     schedules has never successfully expired anything;
--   * RideRepository.autoExpirePastRequests() hit the same error, swallowed by
--     an empty catch (_) {}.
ALTER TABLE public.ride_requests DROP CONSTRAINT IF EXISTS ride_requests_status_check;
ALTER TABLE public.ride_requests ADD CONSTRAINT ride_requests_status_check
    CHECK (status IN ('pending', 'accepted', 'confirmed', 'completed', 'cancelled', 'expired'));


-- =============================================================================
-- F2 — Replace the blanket RLS policy on ride_requests
-- =============================================================================
-- Was: FOR ALL TO authenticated USING (true) WITH CHECK (true) — i.e. any
-- authenticated user could read, modify or delete any other user's request
-- straight through the REST API, bypassing the app entirely.
--
-- Drivers deliberately get no direct UPDATE grant: their transitions run
-- through the SECURITY DEFINER RPCs above, which are not subject to RLS.

DROP POLICY IF EXISTS "allow_all_authenticated_ride_requests" ON public.ride_requests;
DROP POLICY IF EXISTS "Authenticated users can view ride requests" ON public.ride_requests;
DROP POLICY IF EXISTS "Passengers can insert own ride requests" ON public.ride_requests;
DROP POLICY IF EXISTS "Passengers can update own ride requests" ON public.ride_requests;
DROP POLICY IF EXISTS "Passengers can delete own settled ride requests" ON public.ride_requests;

ALTER TABLE public.ride_requests ENABLE ROW LEVEL SECURITY;

-- SELECT stays open to all authenticated users: drivers must be able to browse
-- the open request queue. Intentional, not an oversight.
CREATE POLICY "Authenticated users can view ride requests"
    ON public.ride_requests FOR SELECT
    TO authenticated
    USING (true);

-- NOTE: the fix plan did not specify an INSERT policy, but the FOR ALL policy
-- being dropped was the only INSERT grant on this table. Without this, every
-- call to createRideRequest() would be denied.
CREATE POLICY "Passengers can insert own ride requests"
    ON public.ride_requests FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = passenger_id);

-- WITH CHECK repeats the predicate so a passenger cannot rewrite passenger_id
-- and hand their row to another user.
CREATE POLICY "Passengers can update own ride requests"
    ON public.ride_requests FOR UPDATE
    TO authenticated
    USING (auth.uid() = passenger_id)
    WITH CHECK (auth.uid() = passenger_id);

-- The third arm covers a request still 'pending' whose departure time has
-- passed: the UI offers "Delete Expired Request" for exactly that case, and
-- such a row has no driver attached. 'accepted' and 'confirmed' stay
-- undeletable so a request cannot vanish out from under its driver.
CREATE POLICY "Passengers can delete own settled ride requests"
    ON public.ride_requests FOR DELETE
    TO authenticated
    USING (
        auth.uid() = passenger_id
        AND (
            status IN ('cancelled', 'completed')
            OR (status = 'pending' AND leaving_time < timezone('utc'::text, now()))
        )
    );


-- =============================================================================
-- F3 — Server-side expiry scheduling
-- =============================================================================
-- expire_unconfirmed_ride_requests() and expire_past_slot_ride_requests()
-- existed but nothing called them on a schedule. Expiry happened only when a
-- user happened to open a screen calling getAvailableRequests(); if nobody did,
-- an unconfirmed 'accepted' ride stayed stuck indefinitely.

CREATE OR REPLACE FUNCTION public.run_ride_request_expiry()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_unconfirmed INT;
    v_past_slot INT;
BEGIN
    v_unconfirmed := public.expire_unconfirmed_ride_requests();
    v_past_slot := public.expire_past_slot_ride_requests();

    RETURN jsonb_build_object(
        'unconfirmed_reverted', v_unconfirmed,
        'past_slot_expired', v_past_slot,
        'ran_at', timezone('utc'::text, now())
    );
END;
$$;

REVOKE ALL ON FUNCTION public.run_ride_request_expiry() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.run_ride_request_expiry() FROM authenticated;

-- -----------------------------------------------------------------------------
-- ACTION REQUIRED — pg_cron is assumed NOT to be enabled
-- -----------------------------------------------------------------------------
-- This was written without database access, so the extension's state could not
-- be checked. Before running, confirm:
--
--     SELECT * FROM pg_extension WHERE extname = 'pg_cron';
--
-- If that returns no rows, enable pg_cron in the Supabase dashboard:
--     Database -> Extensions -> search "pg_cron" -> enable
-- (On some plan tiers `CREATE EXTENSION pg_cron;` also works from the SQL
-- editor. If neither is available on your tier, see the fallback in
-- progress/03_server_side_expiry.md — this becomes a NEEDS_DECISION.)
--
-- The block below is intentionally conditional and non-fatal: if pg_cron is
-- absent it raises a NOTICE and continues, rather than aborting the migration
-- and taking the F1/F2 fixes down with it. That means a successful run does NOT
-- by itself prove the job was scheduled — check the post-conditions below.
DO $do$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
        IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'ride_request_expiry') THEN
            PERFORM cron.unschedule('ride_request_expiry');
        END IF;

        -- Every minute. The plan asks for 30-60s; 60s is the shortest interval
        -- standard five-field cron syntax expresses and works on every pg_cron
        -- version. pg_cron >= 1.5 also accepts '30 seconds' — switch only after
        -- confirming the version with: SELECT extversion FROM pg_extension
        -- WHERE extname = 'pg_cron';
        PERFORM cron.schedule(
            'ride_request_expiry',
            '* * * * *',
            $job$SELECT public.run_ride_request_expiry();$job$
        );

        RAISE NOTICE 'pg_cron: scheduled job ride_request_expiry (every minute)';
    ELSE
        RAISE NOTICE 'pg_cron is NOT installed - ride_request_expiry was NOT scheduled. '
                     'Enable it in the Supabase dashboard (Database -> Extensions -> pg_cron), '
                     'then re-run this block. Until then expiry remains client-triggered only.';
    END IF;
END
$do$;


-- =============================================================================
-- POST-CONDITIONS — run these after applying, and actually read the output
-- =============================================================================
-- A clean run is not proof the fixes are in force; the pg_cron block above
-- succeeds even when it schedules nothing.
--
-- 1. Four policies on ride_requests, and no FOR ALL among them:
--      SELECT policyname, cmd, qual, with_check
--      FROM pg_policies WHERE tablename = 'ride_requests' ORDER BY cmd;
--
-- 2. The status constraint permits 'expired':
--      SELECT pg_get_constraintdef(oid) FROM pg_constraint
--      WHERE conname = 'ride_requests_status_check';
--
-- 3. The cron job exists and is active (EMPTY RESULT = expiry is still
--    client-triggered only, i.e. F3 is not actually in force):
--      SELECT jobid, jobname, schedule, active FROM cron.job
--      WHERE jobname = 'ride_request_expiry';
--
-- 4. After a minute or two, confirm it is running without error:
--      SELECT status, return_message, start_time FROM cron.job_run_details
--      WHERE jobid = (SELECT jobid FROM cron.job WHERE jobname = 'ride_request_expiry')
--      ORDER BY start_time DESC LIMIT 5;
--
-- 5. Smoke-test the F1 guard — this should RAISE, not succeed:
--      SELECT public.complete_ride_request('<id of a ride whose status is pending>');
--
-- 6. Smoke-test the F2 hole is closed — as user A, attempt to update user B's
--    request through the REST API. It should affect zero rows.
-- =============================================================================
