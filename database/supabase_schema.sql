-- ==============================================================================
-- FFL SMART RIDE - SUPABASE DATABASE SCHEMA (PRODUCTION-READY & HARDENED)
-- ==============================================================================
-- Run this script in the Supabase SQL Editor (https://supabase.com/dashboard/project/_/sql)

-- 1. EXTENSIONS
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ==============================================================================
-- 2. APP CONFIG TABLE (Admin-Editable Constants & Timezone Configuration)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.app_config (
    key TEXT PRIMARY KEY,
    value NUMERIC,
    text_value TEXT,
    description TEXT,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Enable RLS on app_config
ALTER TABLE public.app_config ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone authenticated can view app config"
    ON public.app_config FOR SELECT
    TO authenticated
    USING (true);

-- Seed default environmental constants and timezone
INSERT INTO public.app_config (key, value, text_value, description)
VALUES
    ('route_distance_km', 2.5, NULL, 'One-way distance between Township and Factory Main Plant in kilometers'),
    ('emission_factor_kg_per_km', 0.12, NULL, 'Average passenger vehicle CO2 emissions in kg per km'),
    ('timezone_name', NULL, 'Asia/Karachi', 'Local timezone for township-to-factory commute schedules (UTC+5)')
ON CONFLICT (key) DO UPDATE SET
    value = EXCLUDED.value,
    text_value = EXCLUDED.text_value,
    description = EXCLUDED.description,
    updated_at = now();

-- ==============================================================================
-- 3. PICKUP STOPS TABLE (Fixed Township-to-Factory Route with Proximity Ordering)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.pickup_stops (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    stop_order SMALLINT NOT NULL UNIQUE,
    description TEXT,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Enable RLS on pickup_stops
ALTER TABLE public.pickup_stops ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone authenticated can view pickup stops"
    ON public.pickup_stops FOR SELECT
    TO authenticated
    USING (true);

-- Seed predefined township-to-factory route stops
INSERT INTO public.pickup_stops (id, name, stop_order, description)
VALUES 
    ('stop_gate_1', 'Gate 1 (Township Main Entrance)', 1, 'Main residential entry gate, Security Post 1'),
    ('stop_sector_a', 'Sector A (Central Park / Mosque)', 2, 'Sector A roundabout, near Central Park'),
    ('stop_comm_center', 'Commercial Center (Township Market)', 3, 'Main marketplace parking area'),
    ('stop_sector_b', 'Sector B (Staff Quarters / Club)', 4, 'Executive club bus bay & Sector B junction'),
    ('stop_gate_2', 'Gate 2 (Township North Exit)', 5, 'Township exit towards Factory expressway'),
    ('stop_factory_main', 'Factory Main Plant Gate', 6, 'FFL Manufacturing Plant Employee Reception Gate')
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    stop_order = EXCLUDED.stop_order,
    description = EXCLUDED.description;

-- ==============================================================================
-- 4. PROFILES TABLE
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    employee_id TEXT NOT NULL UNIQUE,
    full_name TEXT NOT NULL,
    email TEXT UNIQUE,
    phone TEXT,
    home_address TEXT,
    pickup_stop_id TEXT REFERENCES public.pickup_stops(id) ON DELETE SET NULL,
    pickup_stop_order SMALLINT,
    office_location TEXT DEFAULT 'Factory Main Plant',
    vehicle_number TEXT,
    has_vehicle BOOLEAN DEFAULT false,
    avatar_url TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Enable RLS on profiles
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Authenticated users can read all employee profiles"
    ON public.profiles FOR SELECT
    TO authenticated
    USING (true);

CREATE POLICY "Users can insert their own profile"
    ON public.profiles FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = id);

CREATE POLICY "Users can update their own profile"
    ON public.profiles FOR UPDATE
    TO authenticated
    USING (auth.uid() = id);

-- ==============================================================================
-- 5. VEHICLES TABLE
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.vehicles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL UNIQUE REFERENCES public.profiles(id) ON DELETE CASCADE,
    vehicle_type TEXT NOT NULL DEFAULT 'Car',
    make TEXT NOT NULL,
    model TEXT NOT NULL,
    license_plate TEXT NOT NULL UNIQUE,
    color TEXT,
    capacity SMALLINT NOT NULL DEFAULT 3,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Enable RLS on vehicles
ALTER TABLE public.vehicles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Authenticated users can view registered vehicles"
    ON public.vehicles FOR SELECT
    TO authenticated
    USING (true);

CREATE POLICY "Users can insert their own vehicle"
    ON public.vehicles FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own vehicle"
    ON public.vehicles FOR UPDATE
    TO authenticated
    USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own vehicle"
    ON public.vehicles FOR DELETE
    TO authenticated
    USING (auth.uid() = user_id);

-- ==============================================================================
-- 6. SESSION SCHEDULE CONFIG TABLE (Admin-editable daily time windows)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.session_schedule (
    id TEXT PRIMARY KEY,
    slot TEXT NOT NULL CHECK (slot IN ('morning', 'afternoon', 'evening')),
    opens_at TIME NOT NULL,
    closes_at TIME NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Enable RLS on session_schedule
ALTER TABLE public.session_schedule ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone authenticated can view session schedule"
    ON public.session_schedule FOR SELECT
    TO authenticated
    USING (true);

-- Seed default daily session schedule
INSERT INTO public.session_schedule (id, slot, opens_at, closes_at, is_active)
VALUES
    ('sched_morning', 'morning', '07:00:00', '09:00:00', true),
    ('sched_afternoon', 'afternoon', '12:30:00', '14:30:00', true),
    ('sched_evening', 'evening', '16:30:00', '17:30:00', true)
ON CONFLICT (id) DO UPDATE SET
    opens_at = EXCLUDED.opens_at,
    closes_at = EXCLUDED.closes_at,
    is_active = EXCLUDED.is_active;

-- ==============================================================================
-- 7. RIDE SESSIONS TABLE (Daily Slots: morning, afternoon, evening)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.ride_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_date DATE NOT NULL DEFAULT CURRENT_DATE,
    slot TEXT NOT NULL CHECK (slot IN ('morning', 'afternoon', 'evening')),
    status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'closed')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    UNIQUE (session_date, slot)
);

-- Enable RLS on ride_sessions (HARDENED: Strict SELECT only for clients)
ALTER TABLE public.ride_sessions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Any authenticated user can view ride sessions"
    ON public.ride_sessions FOR SELECT
    TO authenticated
    USING (true);

-- NOTE: Direct client INSERT and UPDATE policies are purposely OMITTED.
-- Sessions are created and closed solely via PostgreSQL SECURITY DEFINER functions.

-- ==============================================================================
-- 8. DRIVER AVAILABILITY TABLE
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.driver_availability (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id UUID NOT NULL REFERENCES public.ride_sessions(id) ON DELETE CASCADE,
    driver_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    seats_offered INT NOT NULL CHECK (seats_offered > 0),
    seats_remaining INT NOT NULL CHECK (seats_remaining >= 0),
    status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'cancelled')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    UNIQUE (session_id, driver_id)
);

-- Enable RLS on driver_availability (HARDENED: Strictly scoped to driver_id)
ALTER TABLE public.driver_availability ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Drivers can view their own availability"
    ON public.driver_availability FOR SELECT
    TO authenticated
    USING (auth.uid() = driver_id);

CREATE POLICY "Drivers can insert their own availability"
    ON public.driver_availability FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = driver_id);

CREATE POLICY "Drivers can update their own availability"
    ON public.driver_availability FOR UPDATE
    TO authenticated
    USING (auth.uid() = driver_id);

-- ==============================================================================
-- 9. PASSENGER LOG TABLE
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.passenger_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id UUID NOT NULL REFERENCES public.ride_sessions(id) ON DELETE CASCADE,
    passenger_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    status TEXT NOT NULL DEFAULT 'waiting' CHECK (status IN ('waiting', 'matched', 'cancelled')),
    requested_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    UNIQUE (session_id, passenger_id)
);

-- Enable RLS on passenger_log (HARDENED)
ALTER TABLE public.passenger_log ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Passengers can view their own log"
    ON public.passenger_log FOR SELECT
    TO authenticated
    USING (auth.uid() = passenger_id);

CREATE POLICY "Passengers can insert their own log"
    ON public.passenger_log FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = passenger_id);

CREATE POLICY "Passengers can update their own log"
    ON public.passenger_log FOR UPDATE
    TO authenticated
    USING (auth.uid() = passenger_id);

CREATE POLICY "Active drivers can view session waiting passengers"
    ON public.passenger_log FOR SELECT
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.driver_availability da
            WHERE da.session_id = passenger_log.session_id
              AND da.driver_id = auth.uid()
              AND da.status = 'active'
        )
    );

-- ==============================================================================
-- 10. RIDE MATCHES TABLE
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.ride_matches (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id UUID NOT NULL REFERENCES public.ride_sessions(id) ON DELETE CASCADE,
    driver_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    passenger_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'cancelled', 'completed')),
    matched_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    cancelled_at TIMESTAMP WITH TIME ZONE
);

-- Enable RLS on ride_matches (HARDENED: Read-only for participants; no client writes)
ALTER TABLE public.ride_matches ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Participants can view their ride matches"
    ON public.ride_matches FOR SELECT
    TO authenticated
    USING (auth.uid() = driver_id OR auth.uid() = passenger_id);

-- NOTE: Direct client INSERT and UPDATE policies are purposely OMITTED.
-- Match creation, cancellation, and completion is strictly executed via SECURITY DEFINER functions.

-- ==============================================================================
-- 11. RIDE COMPLETION LOG TABLE (Permanent, Append-Only Environmental Audit Trail)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.ride_completion_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id UUID REFERENCES public.ride_sessions(id) ON DELETE SET NULL,
    driver_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    passenger_ids UUID[] NOT NULL DEFAULT '{}',
    passenger_count INT NOT NULL DEFAULT 1,
    distance_km NUMERIC(10, 2) NOT NULL DEFAULT 2.5,
    emission_factor_kg_per_km NUMERIC(10, 4) NOT NULL DEFAULT 0.12,
    kg_co2_saved NUMERIC(10, 4) NOT NULL,
    completed_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Enable RLS on ride_completion_log (Read-only for users; no client DELETE or UPDATE permitted)
ALTER TABLE public.ride_completion_log ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone authenticated can view completion logs" ON public.ride_completion_log;
CREATE POLICY "Anyone authenticated can view completion logs"
    ON public.ride_completion_log FOR SELECT
    TO authenticated
    USING (true);

DROP POLICY IF EXISTS "Disallow client direct deletes on completion log" ON public.ride_completion_log;
CREATE POLICY "Disallow client direct deletes on completion log"
    ON public.ride_completion_log FOR DELETE
    TO authenticated
    USING (false);

DROP POLICY IF EXISTS "Disallow client direct updates on completion log" ON public.ride_completion_log;
CREATE POLICY "Disallow client direct updates on completion log"
    ON public.ride_completion_log FOR UPDATE
    TO authenticated
    USING (false);

-- ==============================================================================
-- 11A. CO2 SAVINGS VIEW (Environmental Impact per Completed Commute from Audit Trail)
-- ==============================================================================
CREATE OR REPLACE VIEW public.co2_savings AS
SELECT 
    rcl.id AS match_id,
    rcl.session_id,
    rcl.driver_id,
    p_id AS passenger_id,
    'completed'::TEXT AS status,
    rcl.completed_at AS matched_at,
    (rcl.completed_at AT TIME ZONE 'Asia/Karachi')::DATE AS session_date,
    'shift'::TEXT AS slot,
    rcl.distance_km AS route_distance_km,
    rcl.emission_factor_kg_per_km,
    (rcl.kg_co2_saved / GREATEST(rcl.passenger_count, 1))::NUMERIC(10, 4) AS kg_co2_saved,
    ((rcl.kg_co2_saved / GREATEST(rcl.passenger_count, 1)) / 1000.0)::NUMERIC(10, 6) AS tons_co2_saved
FROM public.ride_completion_log rcl,
LATERAL unnest(rcl.passenger_ids) AS p_id;

-- ==============================================================================
-- 12. NOTIFICATIONS TABLE
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    ride_id UUID,
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    type TEXT NOT NULL DEFAULT 'info',
    is_read BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Enable RLS on notifications
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own notifications"
    ON public.notifications FOR SELECT
    TO authenticated
    USING (auth.uid() = user_id);

CREATE POLICY "Authenticated users can create notifications"
    ON public.notifications FOR INSERT
    TO authenticated
    WITH CHECK (true);

CREATE POLICY "Users can update their own notifications"
    ON public.notifications FOR UPDATE
    TO authenticated
    USING (auth.uid() = user_id);

-- ==============================================================================
-- 13. RIDE REQUESTS TABLE (Direct & Ad-Hoc Shift Ride Requests)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.ride_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    passenger_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    driver_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    pickup_location TEXT NOT NULL,
    office_location TEXT NOT NULL DEFAULT 'Factory Main Plant',
    pickup_stop_order SMALLINT,
    leaving_time TIMESTAMP WITH TIME ZONE NOT NULL,
    additional_note TEXT,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'completed', 'cancelled')),
    pickup_latitude DOUBLE PRECISION,
    pickup_longitude DOUBLE PRECISION,
    office_latitude DOUBLE PRECISION,
    office_longitude DOUBLE PRECISION,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Ensure all columns and valid statuses exist even if the table was created in an earlier migration
ALTER TABLE public.ride_requests 
    ADD COLUMN IF NOT EXISTS pickup_stop_order SMALLINT,
    ADD COLUMN IF NOT EXISTS pickup_latitude DOUBLE PRECISION,
    ADD COLUMN IF NOT EXISTS pickup_longitude DOUBLE PRECISION,
    ADD COLUMN IF NOT EXISTS office_latitude DOUBLE PRECISION,
    ADD COLUMN IF NOT EXISTS office_longitude DOUBLE PRECISION;

-- Update status check constraint to support 'confirmed' and 'expired'.
--
-- F3: 'expired' was missing here even though the application has always treated
-- it as a real status (RideRequest.isExpired in lib/core/models/ride_request.dart
-- tests status == 'expired', and available_requests_screen.dart renders an
-- 'expired' status chip). The consequence was that every writer of that status
-- failed the constraint:
--   * expire_past_slot_ride_requests() raised on every call, so the RPC F3
--     schedules has in fact never successfully expired anything;
--   * RideRepository.autoExpirePastRequests() hit the same error, swallowed by
--     an empty catch (_) {}, so it silently did nothing.
-- Scheduling the RPC without widening this constraint would just produce a
-- failing cron job every minute, forever.
ALTER TABLE public.ride_requests DROP CONSTRAINT IF EXISTS ride_requests_status_check;
ALTER TABLE public.ride_requests ADD CONSTRAINT ride_requests_status_check
    CHECK (status IN ('pending', 'accepted', 'confirmed', 'completed', 'cancelled', 'expired'));

-- Enable RLS on ride_requests
DROP POLICY IF EXISTS "allow_all_authenticated_ride_requests" ON public.ride_requests;
DROP POLICY IF EXISTS "Authenticated users can view pending ride requests" ON public.ride_requests;
DROP POLICY IF EXISTS "Passengers can create their own ride requests" ON public.ride_requests;
DROP POLICY IF EXISTS "Passengers or accepted drivers can update ride requests" ON public.ride_requests;
DROP POLICY IF EXISTS "Passengers can delete their own ride requests" ON public.ride_requests;
DROP POLICY IF EXISTS "Authenticated users can update ride requests" ON public.ride_requests;

-- F2: the previous policy on this table was
--
--     CREATE POLICY "allow_all_authenticated_ride_requests"
--         ON public.ride_requests FOR ALL
--         TO authenticated USING (true) WITH CHECK (true);
--
-- which let any authenticated user read, modify or delete any *other* user's
-- ride request straight through the REST API, with the app's logic bypassed
-- entirely. Replaced below with per-command policies matching the scoping
-- already used for driver_availability and passenger_log.
--
-- Driver-side transitions (accept / confirm / complete / cancel-offer) are
-- deliberately NOT granted here: they run through SECURITY DEFINER RPCs, which
-- are not subject to RLS. Granting drivers a direct UPDATE would re-open the
-- hole those RPCs exist to close.
DROP POLICY IF EXISTS "Authenticated users can view ride requests" ON public.ride_requests;
DROP POLICY IF EXISTS "Passengers can insert own ride requests" ON public.ride_requests;
DROP POLICY IF EXISTS "Passengers can update own ride requests" ON public.ride_requests;
DROP POLICY IF EXISTS "Passengers can delete own settled ride requests" ON public.ride_requests;

-- SELECT stays open to all authenticated users: drivers must be able to browse
-- the open request queue. This breadth is intentional, not an oversight.
CREATE POLICY "Authenticated users can view ride requests"
    ON public.ride_requests FOR SELECT
    TO authenticated
    USING (true);

-- INSERT: a passenger may only create requests in their own name.
CREATE POLICY "Passengers can insert own ride requests"
    ON public.ride_requests FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = passenger_id);

-- UPDATE: passenger-initiated changes to their own request only (edit, cancel,
-- decline an offer). WITH CHECK repeats the predicate so a passenger cannot
-- hand their row to someone else by rewriting passenger_id.
CREATE POLICY "Passengers can update own ride requests"
    ON public.ride_requests FOR UPDATE
    TO authenticated
    USING (auth.uid() = passenger_id)
    WITH CHECK (auth.uid() = passenger_id);

-- DELETE: own rows, and only once the request can no longer be acted on. An
-- 'accepted' or 'confirmed' request must be cancelled rather than deleted out
-- from under the driver who was offered it.
--
-- The third arm covers a request that is still 'pending' but whose departure
-- time has passed. The UI offers "Delete Expired Request" for exactly that case
-- (available_requests_screen.dart:920), and such a row has no driver attached,
-- so removing it harms nobody. Restricting DELETE to cancelled/completed alone
-- would leave that button silently deleting nothing.
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

-- ==============================================================================
-- 13A. RPC: ATOMIC ACCEPT RIDE REQUEST (Prevents Deadlocks & Sets 5-Min Deadline)
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.accept_ride_request(p_ride_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_driver_id UUID := auth.uid();
    v_driver_name TEXT;
    v_passenger_id UUID;
    v_status TEXT;
BEGIN
    IF v_driver_id IS NULL THEN
        RAISE EXCEPTION 'User is not authenticated';
    END IF;

    -- Lock the ride request row to prevent race condition between 2 drivers
    SELECT passenger_id, status INTO v_passenger_id, v_status
    FROM public.ride_requests
    WHERE id = p_ride_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Ride request not found';
    END IF;

    IF v_status <> 'pending' THEN
        RAISE EXCEPTION 'This ride request has already been accepted by another colleague';
    END IF;

    IF v_passenger_id = v_driver_id THEN
        RAISE EXCEPTION 'You cannot accept your own ride request';
    END IF;

    -- Update ride request status to accepted with 5-minute confirmation deadline
    UPDATE public.ride_requests
    SET driver_id = v_driver_id,
        status = 'accepted',
        confirmation_deadline = timezone('utc'::text, now()) + INTERVAL '5 minutes',
        updated_at = timezone('utc'::text, now())
    WHERE id = p_ride_id;

    -- Fetch driver name for notification
    SELECT full_name INTO v_driver_name
    FROM public.profiles
    WHERE id = v_driver_id;

    -- Insert notification for passenger
    INSERT INTO public.notifications (user_id, ride_id, title, message, type)
    VALUES (
        v_passenger_id,
        p_ride_id,
        'Ride Offer Received! 🚗',
        COALESCE(v_driver_name, 'A colleague') || ' has offered you a lift. Please confirm or decline your ride within 5 minutes on the Home Screen.',
        'ride_accepted'
    );

    RETURN jsonb_build_object('success', true, 'status', 'accepted', 'driver_id', v_driver_id);
END;
$$;

-- ==============================================================================
-- 13B. RPC: CONFIRM RIDE (Passenger confirms driver offer with 5-min timeout guard)
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.confirm_ride_request(p_ride_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_passenger_id UUID := auth.uid();
    v_passenger_name TEXT;
    v_driver_id UUID;
    v_status TEXT;
    v_deadline TIMESTAMP WITH TIME ZONE;
    v_updated_at TIMESTAMP WITH TIME ZONE;
BEGIN
    SELECT driver_id, status, confirmation_deadline, updated_at 
    INTO v_driver_id, v_status, v_deadline, v_updated_at
    FROM public.ride_requests
    WHERE id = p_ride_id AND passenger_id = v_passenger_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Ride request not found or not owned by you';
    END IF;

    IF v_status <> 'accepted' THEN
        RAISE EXCEPTION 'Ride is not in accepted status (current: %)', v_status;
    END IF;

    -- Check 5-minute timeout deadline
    IF (v_deadline IS NOT NULL AND v_deadline < timezone('utc'::text, now())) OR
       (v_deadline IS NULL AND v_updated_at < timezone('utc'::text, now()) - INTERVAL '5 minutes') THEN
        -- Revert back to open queue immediately
        UPDATE public.ride_requests
        SET driver_id = NULL,
            status = 'pending',
            confirmation_deadline = NULL,
            updated_at = timezone('utc'::text, now())
        WHERE id = p_ride_id;

        RAISE EXCEPTION 'The 5-minute confirmation window has expired. Your request has returned to open requests.';
    END IF;

    UPDATE public.ride_requests
    SET status = 'confirmed',
        updated_at = timezone('utc'::text, now())
    WHERE id = p_ride_id;

    -- Fetch passenger name
    SELECT full_name INTO v_passenger_name
    FROM public.profiles
    WHERE id = v_passenger_id;

    -- Notify driver that passenger confirmed
    IF v_driver_id IS NOT NULL THEN
        INSERT INTO public.notifications (user_id, ride_id, title, message, type)
        VALUES (
            v_driver_id,
            p_ride_id,
            'Ride Confirmed! ✅',
            COALESCE(v_passenger_name, 'Your passenger') || ' has confirmed their ride with you.',
            'ride_confirmed'
        );
    END IF;

    RETURN jsonb_build_object('success', true, 'status', 'confirmed');
END;
$$;

-- ==============================================================================
-- 13B2. RPC: EXPIRE UNCONFIRMED RIDE REQUESTS (Reverts to Open Requests)
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.expire_unconfirmed_ride_requests()
RETURNS INT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_count INT := 0;
BEGIN
    WITH expired_rows AS (
        UPDATE public.ride_requests
        SET driver_id = NULL,
            status = 'pending',
            confirmation_deadline = NULL,
            updated_at = timezone('utc'::text, now())
        WHERE status = 'accepted'
          AND (
            (confirmation_deadline IS NOT NULL AND confirmation_deadline <= timezone('utc'::text, now()))
            OR (confirmation_deadline IS NULL AND updated_at <= timezone('utc'::text, now()) - INTERVAL '5 minutes')
          )
        RETURNING id
    )
    SELECT count(*) INTO v_count FROM expired_rows;

    RETURN v_count;
END;
$$;

-- ==============================================================================
-- 13B3. RPC: EXPIRE UNACCEPTED PAST-SLOT RIDE REQUESTS (Auto-expire unaddressed)
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.expire_past_slot_ride_requests()
RETURNS INT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_count INT := 0;
BEGIN
    WITH expired_rows AS (
        UPDATE public.ride_requests
        SET status = 'expired',
            updated_at = timezone('utc'::text, now())
        WHERE status = 'pending'
          AND driver_id IS NULL
          AND leaving_time < timezone('utc'::text, now())
        RETURNING id
    )
    SELECT count(*) INTO v_count FROM expired_rows;

    RETURN v_count;
END;
$$;

-- ==============================================================================
-- 13B4. SCHEDULED EXPIRY (F3)
-- ==============================================================================
-- Both expiry RPCs above existed but nothing ever called them on a schedule.
-- Expiry happened only as a side effect of a user opening a screen that called
-- getAvailableRequests(); if nobody opened it, an unconfirmed 'accepted' ride
-- stayed stuck indefinitely, holding a request out of the open queue.
--
-- Single entry point so there is one cron job rather than two, and one place to
-- add future sweeps.
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

-- Scheduling. pg_cron is NOT enabled by default on Supabase and cannot be
-- enabled from SQL alone on all plan tiers -- see database/DEPLOY_PENDING.sql
-- and progress/03_server_side_expiry.md for the dashboard steps.
--
-- This block is deliberately conditional: if pg_cron is absent the script still
-- applies cleanly and raises a NOTICE, rather than aborting the whole migration
-- and taking the F1/F2 fixes down with it.
DO $do$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
        -- cron.unschedule errors if the job is absent, so guard on the catalog.
        IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'ride_request_expiry') THEN
            PERFORM cron.unschedule('ride_request_expiry');
        END IF;

        -- Every minute. The plan asks for 30-60s; 60s is the shortest interval
        -- standard five-field cron syntax expresses, and it is supported on
        -- every pg_cron version. For 30s, pg_cron >= 1.5 accepts '30 seconds'
        -- as the schedule instead -- switch only after confirming the version.
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

-- ==============================================================================
-- 13C. RPC: COMPLETE RIDE (Driver marks ad-hoc ride completed & logs CO2)
-- ==============================================================================
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
    -- Lock the row so a concurrent complete/cancel cannot interleave with the
    -- status guard below.
    SELECT passenger_id, driver_id, status INTO v_passenger_id, v_driver_id, v_status
    FROM public.ride_requests
    WHERE id = p_ride_id AND (driver_id = v_user_id OR passenger_id = v_user_id)
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Ride request not found or unauthorized';
    END IF;

    -- A ride may only be completed once the passenger has confirmed it. This
    -- guard previously existed only in the Flutter client, which meant a direct
    -- API call could complete an unconfirmed ride and log CO2 savings for a trip
    -- that was never agreed to.
    IF v_status <> 'confirmed' THEN
        RAISE EXCEPTION 'Cannot complete ride: passenger has not confirmed the ride offer yet (current status: %)', v_status;
    END IF;

    UPDATE public.ride_requests
    SET status = 'completed',
        updated_at = timezone('utc'::text, now())
    WHERE id = p_ride_id;

    -- Calculate and permanently log CO2 savings into ride_completion_log
    IF v_driver_id IS NOT NULL THEN
        SELECT COALESCE(value, 2.5) INTO v_dist FROM public.app_config WHERE key = 'route_distance_km' LIMIT 1;
        IF v_dist IS NULL THEN v_dist := 2.5; END IF;

        SELECT COALESCE(value, 0.12) INTO v_emiss FROM public.app_config WHERE key = 'emission_factor_kg_per_km' LIMIT 1;
        IF v_emiss IS NULL THEN v_emiss := 0.12; END IF;

        v_co2 := (v_dist * v_emiss * 1.0)::NUMERIC(10, 4);

        INSERT INTO public.ride_completion_log (
            session_id,
            driver_id,
            passenger_ids,
            passenger_count,
            distance_km,
            emission_factor_kg_per_km,
            kg_co2_saved,
            completed_at
        ) VALUES (
            NULL,
            v_driver_id,
            ARRAY[v_passenger_id],
            1,
            v_dist,
            v_emiss,
            v_co2,
            timezone('utc'::text, now())
        );
    END IF;

    -- Notify passenger
    INSERT INTO public.notifications (user_id, ride_id, title, message, type)
    VALUES (
        v_passenger_id,
        p_ride_id,
        'Trip Completed 🌿',
        'Your carpool trip is complete. Thank you for helping reduce emissions!',
        'ride_completed'
    );

    RETURN jsonb_build_object('success', true, 'status', 'completed', 'kg_co2_saved', v_co2);
END;
$$;

-- Database Trigger: Failsafe logging on direct ride_requests status -> completed
CREATE OR REPLACE FUNCTION public.trg_log_ride_request_completion()
RETURNS TRIGGER AS $$
DECLARE
    v_dist NUMERIC;
    v_emiss NUMERIC;
    v_co2 NUMERIC;
    v_already_logged BOOLEAN;
BEGIN
    IF NEW.status = 'completed' AND (OLD.status IS DISTINCT FROM 'completed') AND NEW.driver_id IS NOT NULL THEN
        SELECT EXISTS (
            SELECT 1 FROM public.ride_completion_log
            WHERE driver_id = NEW.driver_id
              AND NEW.passenger_id = ANY(passenger_ids)
              AND completed_at >= (now() - INTERVAL '10 seconds')
        ) INTO v_already_logged;

        IF NOT v_already_logged THEN
            SELECT COALESCE(value, 2.5) INTO v_dist FROM public.app_config WHERE key = 'route_distance_km' LIMIT 1;
            IF v_dist IS NULL THEN v_dist := 2.5; END IF;

            SELECT COALESCE(value, 0.12) INTO v_emiss FROM public.app_config WHERE key = 'emission_factor_kg_per_km' LIMIT 1;
            IF v_emiss IS NULL THEN v_emiss := 0.12; END IF;

            v_co2 := (v_dist * v_emiss * 1.0)::NUMERIC(10, 4);

            INSERT INTO public.ride_completion_log (
                session_id,
                driver_id,
                passenger_ids,
                passenger_count,
                distance_km,
                emission_factor_kg_per_km,
                kg_co2_saved,
                completed_at
            ) VALUES (
                NULL,
                NEW.driver_id,
                ARRAY[NEW.passenger_id],
                1,
                v_dist,
                v_emiss,
                v_co2,
                timezone('utc'::text, now())
            );
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_ride_requests_completion ON public.ride_requests;
CREATE TRIGGER trg_ride_requests_completion
    AFTER UPDATE OF status ON public.ride_requests
    FOR EACH ROW
    WHEN (NEW.status = 'completed')
    EXECUTE FUNCTION public.trg_log_ride_request_completion();

-- ==============================================================================
-- 13D. RPC: CANCEL RIDE OFFER (Driver releases ride back to open queue)
-- ==============================================================================
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
    -- Lock the row so this cannot interleave with a concurrent confirm.
    SELECT passenger_id INTO v_passenger_id
    FROM public.ride_requests
    WHERE id = p_ride_id AND driver_id = v_driver_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Ride request not found or you are not the assigned driver';
    END IF;

    -- confirmation_deadline must be cleared alongside the driver: leaving the
    -- previous driver's deadline on a row that is back to 'pending' leaves stale
    -- expiry state attached to an offer that no longer exists.
    UPDATE public.ride_requests
    SET driver_id = NULL,
        status = 'pending',
        confirmation_deadline = NULL,
        updated_at = timezone('utc'::text, now())
    WHERE id = p_ride_id;

    SELECT full_name INTO v_driver_name FROM public.profiles WHERE id = v_driver_id;

    INSERT INTO public.notifications (user_id, ride_id, title, message, type)
    VALUES (
        v_passenger_id,
        p_ride_id,
        'Ride Offer Cancelled',
        COALESCE(v_driver_name, 'The driver') || ' is unable to give a lift. Your request is now back in the open queue.',
        'ride_cancelled'
    );

    RETURN jsonb_build_object('success', true, 'status', 'pending');
END;
$$;

-- ==============================================================================
-- 14. AUTOMATIC PROFILE TRIGGER (AUTH -> PUBLIC)
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
    v_has_vehicle BOOLEAN;
    v_plate TEXT;
BEGIN
    v_has_vehicle := COALESCE((new.raw_user_meta_data->>'has_vehicle')::boolean, false);
    v_plate := new.raw_user_meta_data->>'license_plate';

    INSERT INTO public.profiles (
        id,
        employee_id,
        full_name,
        email,
        phone,
        home_address,
        pickup_stop_id,
        pickup_stop_order,
        office_location,
        vehicle_number,
        has_vehicle
    )
    VALUES (
        new.id,
        COALESCE(new.raw_user_meta_data->>'employee_id', 'FFL-' || substr(new.id::text, 1, 6)),
        COALESCE(new.raw_user_meta_data->>'full_name', 'Employee'),
        new.email,
        new.raw_user_meta_data->>'phone',
        new.raw_user_meta_data->>'home_address',
        new.raw_user_meta_data->>'pickup_stop_id',
        (new.raw_user_meta_data->>'pickup_stop_order')::smallint,
        COALESCE(new.raw_user_meta_data->>'office_location', 'Factory Main Plant'),
        v_plate,
        v_has_vehicle
    )
    ON CONFLICT (id) DO UPDATE SET
        full_name = EXCLUDED.full_name,
        employee_id = EXCLUDED.employee_id,
        phone = COALESCE(EXCLUDED.phone, profiles.phone),
        home_address = COALESCE(EXCLUDED.home_address, profiles.home_address),
        pickup_stop_id = COALESCE(EXCLUDED.pickup_stop_id, profiles.pickup_stop_id),
        pickup_stop_order = COALESCE(EXCLUDED.pickup_stop_order, profiles.pickup_stop_order),
        office_location = COALESCE(EXCLUDED.office_location, profiles.office_location),
        vehicle_number = COALESCE(EXCLUDED.vehicle_number, profiles.vehicle_number),
        has_vehicle = EXCLUDED.has_vehicle,
        updated_at = now();

    IF v_has_vehicle = true AND v_plate IS NOT NULL AND trim(v_plate) != '' THEN
        INSERT INTO public.vehicles (
            user_id,
            vehicle_type,
            make,
            model,
            license_plate
        )
        VALUES (
            new.id,
            COALESCE(new.raw_user_meta_data->>'vehicle_type', 'Car'),
            COALESCE(new.raw_user_meta_data->>'make', 'Unknown'),
            COALESCE(new.raw_user_meta_data->>'model', 'Standard'),
            upper(trim(v_plate))
        )
        ON CONFLICT (user_id) DO UPDATE SET
            vehicle_type = EXCLUDED.vehicle_type,
            make = EXCLUDED.make,
            model = EXCLUDED.model,
            license_plate = EXCLUDED.license_plate,
            updated_at = now();
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ==============================================================================
-- 15. NEAREST-PASSENGER PRIORITY QUEUE RPC
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.get_priority_queue(
    p_session_id UUID,
    p_driver_id UUID
)
RETURNS TABLE (
    log_id UUID,
    passenger_id UUID,
    passenger_name TEXT,
    employee_id TEXT,
    phone TEXT,
    home_address TEXT,
    pickup_stop_id TEXT,
    pickup_stop_name TEXT,
    passenger_stop_order SMALLINT,
    driver_stop_order SMALLINT,
    stops_away INT,
    requested_at TIMESTAMPTZ,
    status TEXT
) AS $$
DECLARE
    v_driver_stop SMALLINT;
BEGIN
    SELECT COALESCE(pickup_stop_order, 1) INTO v_driver_stop
    FROM public.profiles
    WHERE id = p_driver_id;

    IF v_driver_stop IS NULL THEN
        v_driver_stop := 1;
    END IF;

    RETURN QUERY
    SELECT 
        pl.id AS log_id,
        pl.passenger_id,
        p.full_name AS passenger_name,
        p.employee_id,
        p.phone,
        p.home_address,
        p.pickup_stop_id,
        ps.name AS pickup_stop_name,
        COALESCE(p.pickup_stop_order, 1) AS passenger_stop_order,
        v_driver_stop AS driver_stop_order,
        abs(COALESCE(p.pickup_stop_order, 1) - v_driver_stop)::INT AS stops_away,
        pl.requested_at,
        pl.status
    FROM public.passenger_log pl
    JOIN public.profiles p ON pl.passenger_id = p.id
    LEFT JOIN public.pickup_stops ps ON p.pickup_stop_id = ps.id
    WHERE pl.session_id = p_session_id
      AND LOWER(pl.status) = 'waiting'
      -- Passenger must NOT already be matched in this session
      AND NOT EXISTS (
          SELECT 1 FROM public.ride_matches rm 
          WHERE rm.session_id = p_session_id 
            AND rm.passenger_id = pl.passenger_id 
            AND rm.status IN ('active', 'completed')
      )
      -- Exclude driver themselves
      AND pl.passenger_id <> p_driver_id
    ORDER BY 
        abs(COALESCE(p.pickup_stop_order, 1) - v_driver_stop) ASC,
        pl.requested_at ASC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ==============================================================================
-- 16. ATOMIC PASSENGER ASSIGNMENT RPC (RACE-CONDITION SAFE CONFLICT HANDLING)
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.assign_passengers(
    p_session_id UUID,
    p_driver_id UUID,
    p_passenger_ids UUID[]
)
RETURNS VOID AS $$
DECLARE
    v_seats_remaining INT;
    v_passenger_count INT;
    v_curr_passenger UUID;
    v_curr_log_id UUID;
    v_passenger_status TEXT;
    v_driver_name TEXT;
    v_vehicle_info TEXT;
BEGIN
    v_passenger_count := array_length(p_passenger_ids, 1);

    IF v_passenger_count IS NULL OR v_passenger_count <= 0 THEN
        RAISE EXCEPTION 'No passengers selected for assignment.';
    END IF;

    -- Lock driver availability record (handle active/available status)
    SELECT seats_remaining INTO v_seats_remaining
    FROM public.driver_availability
    WHERE session_id = p_session_id 
      AND driver_id = p_driver_id 
      AND (status IS NULL OR LOWER(status) IN ('active', 'available'))
    FOR UPDATE;

    IF v_seats_remaining IS NULL THEN
        RAISE EXCEPTION 'Driver availability record not found for this shift session.';
    END IF;

    IF v_seats_remaining < v_passenger_count THEN
        RAISE EXCEPTION 'Insufficient seats remaining (Available: %, Requested: %).', v_seats_remaining, v_passenger_count;
    END IF;

    SELECT p.full_name, COALESCE(v.make || ' ' || v.model || ' (' || v.license_plate || ')', p.vehicle_number, 'Colleague Car')
    INTO v_driver_name, v_vehicle_info
    FROM public.profiles p
    LEFT JOIN public.vehicles v ON p.id = v.user_id
    WHERE p.id = p_driver_id;

    -- Lock and verify each passenger individually
    FOREACH v_curr_passenger IN ARRAY p_passenger_ids
    LOOP
        -- 1. Check if passenger already has a match in this session
        IF EXISTS (
            SELECT 1 FROM public.ride_matches 
            WHERE session_id = p_session_id 
              AND passenger_id = v_curr_passenger 
              AND status IN ('active', 'completed')
        ) THEN
            RAISE EXCEPTION 'A selected passenger has already been matched by another driver. Please refresh your queue.';
        END IF;

        -- 2. Lock waiting passenger_log record
        SELECT id, status INTO v_curr_log_id, v_passenger_status
        FROM public.passenger_log
        WHERE session_id = p_session_id 
          AND passenger_id = v_curr_passenger
          AND LOWER(status) = 'waiting'
        ORDER BY requested_at DESC
        LIMIT 1
        FOR UPDATE;

        IF v_curr_log_id IS NULL THEN
            RAISE EXCEPTION 'A selected passenger is no longer in the waiting queue. Please refresh your queue.';
        END IF;

        -- 3. Insert active ride match
        INSERT INTO public.ride_matches (
            session_id,
            driver_id,
            passenger_id,
            status,
            matched_at
        )
        VALUES (
            p_session_id,
            p_driver_id,
            v_curr_passenger,
            'active',
            now()
        );

        -- 4. Mark all passenger_log entries for this passenger in this session as matched
        UPDATE public.passenger_log
        SET status = 'matched'
        WHERE session_id = p_session_id AND passenger_id = v_curr_passenger;

        -- 5. Send notification to passenger
        INSERT INTO public.notifications (
            user_id,
            title,
            message,
            type
        )
        VALUES (
            v_curr_passenger,
            'Ride Matched! 🚗',
            COALESCE(v_driver_name, 'A colleague') || ' will pick you up in ' || COALESCE(v_vehicle_info, 'their car') || ' for today''s commute.',
            'ride_matched'
        );
    END LOOP;

    -- 6. Decrement seats remaining
    UPDATE public.driver_availability
    SET seats_remaining = seats_remaining - v_passenger_count
    WHERE session_id = p_session_id AND driver_id = p_driver_id;

END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ==============================================================================
-- 17. CANCELLATION RPC FUNCTIONS
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.cancel_match(p_match_id UUID)
RETURNS VOID AS $$
DECLARE
    v_session_id UUID;
    v_driver_id UUID;
    v_passenger_id UUID;
    v_status TEXT;
    v_driver_name TEXT;
BEGIN
    SELECT session_id, driver_id, passenger_id, status
    INTO v_session_id, v_driver_id, v_passenger_id, v_status
    FROM public.ride_matches
    WHERE id = p_match_id
    FOR UPDATE;

    IF v_status IS NULL THEN
        RAISE EXCEPTION 'Match record not found.';
    END IF;

    IF v_status != 'active' THEN
        RETURN;
    END IF;

    UPDATE public.ride_matches
    SET status = 'cancelled',
        cancelled_at = now()
    WHERE id = p_match_id;

    UPDATE public.passenger_log
    SET status = 'waiting'
    WHERE session_id = v_session_id AND passenger_id = v_passenger_id;

    UPDATE public.driver_availability
    SET seats_remaining = seats_remaining + 1
    WHERE session_id = v_session_id AND driver_id = v_driver_id;

    SELECT full_name INTO v_driver_name FROM public.profiles WHERE id = v_driver_id;

    INSERT INTO public.notifications (user_id, title, message, type)
    VALUES (
        v_passenger_id,
        'Ride Match Update ℹ️',
        COALESCE(v_driver_name, 'Your driver') || ' had to cancel the ride. You have been placed back at the front of the queue.',
        'match_cancelled'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.cancel_driver_availability(p_driver_availability_id UUID)
RETURNS VOID AS $$
DECLARE
    v_session_id UUID;
    v_driver_id UUID;
    v_match RECORD;
    v_driver_name TEXT;
BEGIN
    SELECT session_id, driver_id
    INTO v_session_id, v_driver_id
    FROM public.driver_availability
    WHERE id = p_driver_availability_id
    FOR UPDATE;

    IF v_session_id IS NULL THEN
        RAISE EXCEPTION 'Driver availability record not found.';
    END IF;

    UPDATE public.driver_availability
    SET status = 'cancelled'
    WHERE id = p_driver_availability_id;

    SELECT full_name INTO v_driver_name FROM public.profiles WHERE id = v_driver_id;

    FOR v_match IN
        SELECT id, passenger_id
        FROM public.ride_matches
        WHERE session_id = v_session_id 
          AND driver_id = v_driver_id 
          AND status = 'active'
        FOR UPDATE
    LOOP
        UPDATE public.ride_matches
        SET status = 'cancelled',
            cancelled_at = now()
        WHERE id = v_match.id;

        UPDATE public.passenger_log
        SET status = 'waiting'
        WHERE session_id = v_session_id AND passenger_id = v_match.passenger_id;

        INSERT INTO public.notifications (user_id, title, message, type)
        VALUES (
            v_match.passenger_id,
            'Ride Cancelled ℹ️',
            COALESCE(v_driver_name, 'Your driver') || ' is no longer available. You have been placed back in the waiting queue.',
            'ride_cancelled'
        );
    END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.switch_driver_to_passenger(
    p_session_id UUID,
    p_user_id UUID
)
RETURNS UUID AS $$
DECLARE
    v_avail_id UUID;
    v_log_id UUID;
BEGIN
    SELECT id INTO v_avail_id
    FROM public.driver_availability
    WHERE session_id = p_session_id AND driver_id = p_user_id AND status = 'active';

    IF v_avail_id IS NOT NULL THEN
        PERFORM public.cancel_driver_availability(v_avail_id);
    END IF;

    INSERT INTO public.passenger_log (
        session_id,
        passenger_id,
        status,
        requested_at
    )
    VALUES (
        p_session_id,
        p_user_id,
        'waiting',
        now()
    )
    ON CONFLICT (session_id, passenger_id) DO UPDATE
    SET status = 'waiting',
        requested_at = now()
    RETURNING id INTO v_log_id;

    RETURN v_log_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.cancel_passenger_request(p_passenger_log_id UUID)
RETURNS VOID AS $$
BEGIN
    UPDATE public.passenger_log
    SET status = 'cancelled'
    WHERE id = p_passenger_log_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ==============================================================================
-- 17A. RPC: COMPLETE DRIVER SHIFT COMMUTE TRIP (Manual Driver Action)
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.complete_driver_session_ride(p_session_id UUID)
RETURNS JSONB AS $$
DECLARE
    v_driver_id UUID := auth.uid();
    v_passenger_ids UUID[];
    v_p_count INT;
    v_pending_count INT;
    v_dist NUMERIC;
    v_emiss NUMERIC;
    v_co2 NUMERIC;
    v_match RECORD;
BEGIN
    IF v_driver_id IS NULL THEN
        RAISE EXCEPTION 'User is not authenticated';
    END IF;

    -- Check if there are any unconfirmed matches still pending
    SELECT COUNT(*)::INT INTO v_pending_count
    FROM public.ride_matches
    WHERE session_id = p_session_id AND driver_id = v_driver_id AND status = 'pending_confirmation';

    -- Get all CONFIRMED matches for this driver in this session
    SELECT array_agg(passenger_id), COUNT(*)::INT
    INTO v_passenger_ids, v_p_count
    FROM public.ride_matches
    WHERE session_id = p_session_id 
      AND driver_id = v_driver_id 
      AND status IN ('confirmed', 'active');

    IF v_p_count IS NULL OR v_p_count = 0 THEN
        IF v_pending_count > 0 THEN
            RAISE EXCEPTION 'Cannot complete ride: Passenger(s) have not confirmed the ride offer yet.';
        ELSE
            RAISE EXCEPTION 'No confirmed passenger matches found for this session.';
        END IF;
    END IF;

    -- Fetch route distance and emission factor from app_config
    SELECT COALESCE(value, 2.5) INTO v_dist FROM public.app_config WHERE key = 'route_distance_km' LIMIT 1;
    IF v_dist IS NULL THEN v_dist := 2.5; END IF;

    SELECT COALESCE(value, 0.12) INTO v_emiss FROM public.app_config WHERE key = 'emission_factor_kg_per_km' LIMIT 1;
    IF v_emiss IS NULL THEN v_emiss := 0.12; END IF;

    v_co2 := (v_dist * v_emiss * v_p_count)::NUMERIC(10, 4);

    -- Log permanently in append-only ride_completion_log
    INSERT INTO public.ride_completion_log (
        session_id,
        driver_id,
        passenger_ids,
        passenger_count,
        distance_km,
        emission_factor_kg_per_km,
        kg_co2_saved,
        completed_at
    ) VALUES (
        p_session_id,
        v_driver_id,
        v_passenger_ids,
        v_p_count,
        v_dist,
        v_emiss,
        v_co2,
        timezone('utc'::text, now())
    );

    -- Mark ONLY confirmed matches as completed
    UPDATE public.ride_matches
    SET status = 'completed'
    WHERE session_id = p_session_id 
      AND driver_id = v_driver_id 
      AND status IN ('confirmed', 'active');

    -- Notify all completed passengers
    FOR v_match IN
        SELECT passenger_id FROM public.ride_matches
        WHERE session_id = p_session_id AND driver_id = v_driver_id AND status = 'completed'
    LOOP
        INSERT INTO public.notifications (user_id, title, message, type)
        VALUES (
            v_match.passenger_id,
            'Trip Completed 🌿',
            'Your carpool commute is complete. Thank you for helping reduce emissions!',
            'ride_completed'
        );
    END LOOP;

    RETURN jsonb_build_object(
        'success', true,
        'passenger_count', v_p_count,
        'kg_co2_saved', v_co2
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ==============================================================================
-- 17B. RPC: CONFIRM PASSENGER MATCH (Shift Commute Session)
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.confirm_passenger_match(p_match_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_passenger_id UUID := auth.uid();
    v_passenger_name TEXT;
    v_driver_id UUID;
    v_status TEXT;
    v_deadline TIMESTAMPTZ;
BEGIN
    SELECT driver_id, status, confirmation_deadline INTO v_driver_id, v_status, v_deadline
    FROM public.ride_matches
    WHERE id = p_match_id AND passenger_id = v_passenger_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Ride match not found or unauthorized.';
    END IF;

    IF v_status = 'confirmed' OR v_status = 'active' THEN
        RETURN jsonb_build_object('success', true, 'status', 'confirmed');
    END IF;

    IF v_status <> 'pending_confirmation' THEN
        RAISE EXCEPTION 'Match cannot be confirmed (current status: %)', v_status;
    END IF;

    IF v_deadline IS NOT NULL AND v_deadline < timezone('utc'::text, now()) THEN
        RAISE EXCEPTION 'This ride confirmation window has expired.';
    END IF;

    UPDATE public.ride_matches
    SET status = 'confirmed'
    WHERE id = p_match_id;

    SELECT full_name INTO v_passenger_name FROM public.profiles WHERE id = v_passenger_id;

    IF v_driver_id IS NOT NULL THEN
        INSERT INTO public.notifications (user_id, title, message, type)
        VALUES (
            v_driver_id,
            'Ride Confirmed! ✅',
            COALESCE(v_passenger_name, 'Your passenger') || ' has confirmed the ride with you.',
            'ride_confirmed'
        );
    END IF;

    RETURN jsonb_build_object('success', true, 'status', 'confirmed');
END;
$$;

-- ==============================================================================
-- 17C. RPC: REJECT PASSENGER MATCH (Passenger Explicit Rejection)
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.reject_passenger_match(p_match_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_passenger_id UUID := auth.uid();
    v_session_id UUID;
    v_driver_id UUID;
    v_status TEXT;
    v_passenger_name TEXT;
BEGIN
    SELECT session_id, driver_id, status
    INTO v_session_id, v_driver_id, v_status
    FROM public.ride_matches
    WHERE id = p_match_id AND passenger_id = v_passenger_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Ride match not found or unauthorized.';
    END IF;

    -- Cancel the match
    UPDATE public.ride_matches
    SET status = 'cancelled',
        cancelled_at = timezone('utc'::text, now())
    WHERE id = p_match_id;

    -- Revert passenger to waiting in passenger_log
    UPDATE public.passenger_log
    SET status = 'waiting'
    WHERE session_id = v_session_id AND passenger_id = v_passenger_id;

    -- Increment driver seats_remaining
    UPDATE public.driver_availability
    SET seats_remaining = seats_remaining + 1
    WHERE session_id = v_session_id AND driver_id = v_driver_id;

    SELECT full_name INTO v_passenger_name FROM public.profiles WHERE id = v_passenger_id;

    -- Notify driver
    INSERT INTO public.notifications (user_id, title, message, type)
    VALUES (
        v_driver_id,
        'Ride Offer Declined ℹ️',
        COALESCE(v_passenger_name, 'A passenger') || ' was unable to accept your ride. Your seat has been freed up.',
        'match_cancelled'
    );

    RETURN jsonb_build_object('success', true, 'status', 'cancelled');
END;
$$;

-- ==============================================================================
-- 17D. RPC: EXPIRE UNCONFIRMED MATCHES & REQUESTS (Scheduled / Lazy Execution)
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.expire_unconfirmed_matches()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_match RECORD;
    v_req RECORD;
    v_driver_name TEXT;
    v_passenger_name TEXT;
    v_expired_matches_count INT := 0;
    v_expired_requests_count INT := 0;
BEGIN
    -- 1. Expire unconfirmed shift ride matches (pending_confirmation > 5 minutes)
    FOR v_match IN
        SELECT rm.id, rm.session_id, rm.driver_id, rm.passenger_id
        FROM public.ride_matches rm
        WHERE rm.status = 'pending_confirmation'
          AND rm.confirmation_deadline < timezone('utc'::text, now())
        FOR UPDATE
    LOOP
        UPDATE public.ride_matches
        SET status = 'expired',
            cancelled_at = timezone('utc'::text, now())
        WHERE id = v_match.id;

        -- Return passenger back to waiting queue
        UPDATE public.passenger_log
        SET status = 'waiting'
        WHERE session_id = v_match.session_id AND passenger_id = v_match.passenger_id;

        -- Restore driver seats_remaining
        UPDATE public.driver_availability
        SET seats_remaining = seats_remaining + 1
        WHERE session_id = v_match.session_id AND driver_id = v_match.driver_id;

        SELECT full_name INTO v_passenger_name FROM public.profiles WHERE id = v_match.passenger_id;
        SELECT full_name INTO v_driver_name FROM public.profiles WHERE id = v_match.driver_id;

        -- Notify driver
        INSERT INTO public.notifications (user_id, title, message, type)
        VALUES (
            v_match.driver_id,
            'Ride Offer Expired ⏳',
            COALESCE(v_passenger_name, 'A passenger') || ' did not confirm within 5 minutes. The seat has been restored to your vehicle.',
            'ride_expired'
        );

        -- Notify passenger
        INSERT INTO public.notifications (user_id, title, message, type)
        VALUES (
            v_match.passenger_id,
            'Ride Request Timed Out ⏳',
            'Your ride offer from ' || COALESCE(v_driver_name, 'the driver') || ' timed out. You are back in the waiting queue for another driver.',
            'ride_expired'
        );

        v_expired_matches_count := v_expired_matches_count + 1;
    END LOOP;

    -- 2. Expire unconfirmed ad-hoc ride requests
    FOR v_req IN
        SELECT rr.id, rr.passenger_id, rr.driver_id
        FROM public.ride_requests rr
        WHERE rr.status IN ('accepted', 'pending_confirmation')
          AND (
              (rr.confirmation_deadline IS NOT NULL AND rr.confirmation_deadline < timezone('utc'::text, now()))
              OR (rr.confirmation_deadline IS NULL AND rr.updated_at < timezone('utc'::text, now()) - INTERVAL '5 minutes')
          )
        FOR UPDATE
    LOOP
        UPDATE public.ride_requests
        SET driver_id = NULL,
            status = 'pending',
            confirmation_deadline = NULL,
            updated_at = timezone('utc'::text, now())
        WHERE id = v_req.id;

        SELECT full_name INTO v_passenger_name FROM public.profiles WHERE id = v_req.passenger_id;
        SELECT full_name INTO v_driver_name FROM public.profiles WHERE id = v_req.driver_id;

        IF v_req.driver_id IS NOT NULL THEN
            INSERT INTO public.notifications (user_id, ride_id, title, message, type)
            VALUES (
                v_req.driver_id,
                v_req.id,
                'Ride Offer Expired ⏳',
                'Your lift offer for ' || COALESCE(v_passenger_name, 'the passenger') || ' expired because they did not confirm within 5 minutes.',
                'ride_expired'
            );
        END IF;

        INSERT INTO public.notifications (user_id, ride_id, title, message, type)
        VALUES (
            v_req.passenger_id,
            v_req.id,
            'Ride Offer Expired ⏳',
            'The 5-minute confirmation window expired. Your request is now back in the open requests queue.',
            'ride_expired'
        );

        v_expired_requests_count := v_expired_requests_count + 1;
    END LOOP;

    RETURN jsonb_build_object(
        'expired_matches', v_expired_matches_count,
        'expired_requests', v_expired_requests_count
    );
END;
$$;

-- Database Trigger: Failsafe logging when ride_matches rows are updated to 'completed'
-- CRITICAL GUARD: Only logs CO2 from 'confirmed' or 'active' status. NEVER from 'pending_confirmation' or 'expired'.
CREATE OR REPLACE FUNCTION public.trg_log_ride_match_completion()
RETURNS TRIGGER AS $$
DECLARE
    v_dist NUMERIC;
    v_emiss NUMERIC;
    v_co2 NUMERIC;
    v_already_logged BOOLEAN;
BEGIN
    IF NEW.status = 'completed' AND (OLD.status IN ('confirmed', 'active')) AND NEW.driver_id IS NOT NULL THEN
        SELECT EXISTS (
            SELECT 1 FROM public.ride_completion_log
            WHERE session_id = NEW.session_id
              AND driver_id = NEW.driver_id
              AND NEW.passenger_id = ANY(passenger_ids)
        ) INTO v_already_logged;

        IF NOT v_already_logged THEN
            SELECT COALESCE(value, 2.5) INTO v_dist FROM public.app_config WHERE key = 'route_distance_km' LIMIT 1;
            IF v_dist IS NULL THEN v_dist := 2.5; END IF;

            SELECT COALESCE(value, 0.12) INTO v_emiss FROM public.app_config WHERE key = 'emission_factor_kg_per_km' LIMIT 1;
            IF v_emiss IS NULL THEN v_emiss := 0.12; END IF;

            v_co2 := (v_dist * v_emiss * 1.0)::NUMERIC(10, 4);

            INSERT INTO public.ride_completion_log (
                session_id,
                driver_id,
                passenger_ids,
                passenger_count,
                distance_km,
                emission_factor_kg_per_km,
                kg_co2_saved,
                completed_at
            ) VALUES (
                NEW.session_id,
                NEW.driver_id,
                ARRAY[NEW.passenger_id],
                1,
                v_dist,
                v_emiss,
                v_co2,
                timezone('utc'::text, now())
            );
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_ride_matches_completion ON public.ride_matches;
CREATE TRIGGER trg_ride_matches_completion
    AFTER UPDATE OF status ON public.ride_matches
    FOR EACH ROW
    WHEN (NEW.status = 'completed')
    EXECUTE FUNCTION public.trg_log_ride_match_completion();

-- ==============================================================================
-- 18. REPORTING & ENVIRONMENTAL IMPACT RPCS (READING DIRECTLY FROM AUDIT LOG)
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.monthly_co2_summary(p_month DATE DEFAULT CURRENT_DATE)
RETURNS JSON AS $$
DECLARE
    v_start_date TIMESTAMPTZ;
    v_end_date TIMESTAMPTZ;
    v_count INT;
    v_kg NUMERIC;
    v_tons NUMERIC;
BEGIN
    v_start_date := date_trunc('month', (p_month AT TIME ZONE 'Asia/Karachi'));
    v_end_date := date_trunc('month', (p_month AT TIME ZONE 'Asia/Karachi')) + INTERVAL '1 month';

    SELECT 
        COALESCE(SUM(passenger_count), 0)::INT,
        COALESCE(SUM(kg_co2_saved), 0)::NUMERIC(10, 2),
        (COALESCE(SUM(kg_co2_saved), 0) / 1000.0)::NUMERIC(10, 4)
    INTO v_count, v_kg, v_tons
    FROM public.ride_completion_log
    WHERE completed_at >= v_start_date AND completed_at < v_end_date;

    RETURN json_build_object(
        'month', to_char(p_month, 'YYYY-MM'),
        'month_name', to_char(p_month, 'FMMonth YYYY'),
        'total_matches_completed', v_count,
        'total_kg_saved', v_kg,
        'total_tons_saved', v_tons
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.monthly_leaderboard(p_month DATE DEFAULT CURRENT_DATE)
RETURNS JSON AS $$
DECLARE
    v_start_date TIMESTAMPTZ;
    v_end_date TIMESTAMPTZ;
    v_drivers JSON;
    v_passengers JSON;
BEGIN
    v_start_date := date_trunc('month', (p_month AT TIME ZONE 'Asia/Karachi'));
    v_end_date := date_trunc('month', (p_month AT TIME ZONE 'Asia/Karachi')) + INTERVAL '1 month';

    -- Top Drivers
    SELECT json_agg(t) INTO v_drivers FROM (
        SELECT 
            rcl.driver_id AS user_id,
            p.full_name,
            p.employee_id,
            p.avatar_url,
            COUNT(*)::INT AS rides_count,
            SUM(rcl.kg_co2_saved)::NUMERIC(10, 2) AS co2_saved_kg,
            DENSE_RANK() OVER (ORDER BY SUM(rcl.kg_co2_saved) DESC, COUNT(*) DESC) AS rank
        FROM public.ride_completion_log rcl
        JOIN public.profiles p ON rcl.driver_id = p.id
        WHERE rcl.completed_at >= v_start_date AND rcl.completed_at < v_end_date
        GROUP BY rcl.driver_id, p.full_name, p.employee_id, p.avatar_url
        ORDER BY co2_saved_kg DESC, rides_count DESC
        LIMIT 10
    ) t;

    -- Top Passengers
    SELECT json_agg(t) INTO v_passengers FROM (
        SELECT 
            p_id AS user_id,
            p.full_name,
            p.employee_id,
            p.avatar_url,
            COUNT(*)::INT AS rides_count,
            SUM(rcl.kg_co2_saved / GREATEST(rcl.passenger_count, 1))::NUMERIC(10, 2) AS co2_saved_kg,
            DENSE_RANK() OVER (
                ORDER BY SUM(rcl.kg_co2_saved / GREATEST(rcl.passenger_count, 1)) DESC, COUNT(*) DESC
            ) AS rank
        FROM public.ride_completion_log rcl,
        LATERAL unnest(rcl.passenger_ids) AS p_id
        JOIN public.profiles p ON p.id = p_id
        WHERE rcl.completed_at >= v_start_date AND rcl.completed_at < v_end_date
        GROUP BY p_id, p.full_name, p.employee_id, p.avatar_url
        ORDER BY co2_saved_kg DESC, rides_count DESC
        LIMIT 10
    ) t;

    RETURN json_build_object(
        'month', to_char(p_month, 'YYYY-MM'),
        'top_drivers', COALESCE(v_drivers, '[]'::JSON),
        'top_passengers', COALESCE(v_passengers, '[]'::JSON)
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.get_last_6_months_co2_trend()
RETURNS JSON AS $$
DECLARE
    v_trends JSON;
BEGIN
    SELECT json_agg(t) INTO v_trends FROM (
        WITH months AS (
            SELECT generate_series(
                date_trunc('month', (now() AT TIME ZONE 'Asia/Karachi')::DATE - INTERVAL '5 months'),
                date_trunc('month', (now() AT TIME ZONE 'Asia/Karachi')::DATE),
                INTERVAL '1 month'
            )::DATE AS m_date
        )
        SELECT 
            to_char(m.m_date, 'YYYY-MM') AS month_key,
            to_char(m.m_date, 'Mon') AS month_short,
            to_char(m.m_date, 'YYYY') AS year,
            COALESCE(SUM(rcl.passenger_count), 0)::INT AS match_count,
            COALESCE(SUM(rcl.kg_co2_saved), 0)::NUMERIC(10, 2) AS kg_saved,
            (COALESCE(SUM(rcl.kg_co2_saved), 0) / 1000.0)::NUMERIC(10, 4) AS tons_saved
        FROM months m
        LEFT JOIN public.ride_completion_log rcl 
            ON date_trunc('month', (rcl.completed_at AT TIME ZONE 'Asia/Karachi')::DATE) = m.m_date
        GROUP BY m.m_date
        ORDER BY m.m_date ASC
    ) t;

    RETURN COALESCE(v_trends, '[]'::JSON);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.get_user_monthly_stats(
    p_user_id UUID,
    p_month DATE DEFAULT CURRENT_DATE
)
RETURNS JSON AS $$
DECLARE
    v_start_date TIMESTAMPTZ;
    v_end_date TIMESTAMPTZ;
    v_as_driver INT;
    v_as_passenger INT;
    v_driver_co2 NUMERIC;
    v_passenger_co2 NUMERIC;
    v_total_co2 NUMERIC;
BEGIN
    v_start_date := date_trunc('month', (p_month AT TIME ZONE 'Asia/Karachi'));
    v_end_date := date_trunc('month', (p_month AT TIME ZONE 'Asia/Karachi')) + INTERVAL '1 month';

    -- As Driver
    SELECT 
        COUNT(*)::INT,
        COALESCE(SUM(kg_co2_saved), 0)::NUMERIC(10, 2)
    INTO v_as_driver, v_driver_co2
    FROM public.ride_completion_log
    WHERE driver_id = p_user_id
      AND completed_at >= v_start_date AND completed_at < v_end_date;

    -- As Passenger
    SELECT 
        COUNT(*)::INT,
        COALESCE(SUM(kg_co2_saved / GREATEST(passenger_count, 1)), 0)::NUMERIC(10, 2)
    INTO v_as_passenger, v_passenger_co2
    FROM public.ride_completion_log
    WHERE p_user_id = ANY(passenger_ids)
      AND completed_at >= v_start_date AND completed_at < v_end_date;

    v_total_co2 := (COALESCE(v_driver_co2, 0) + COALESCE(v_passenger_co2, 0))::NUMERIC(10, 2);

    RETURN json_build_object(
        'user_id', p_user_id,
        'month', to_char(p_month, 'YYYY-MM'),
        'rides_given_as_driver', COALESCE(v_as_driver, 0),
        'rides_taken_as_passenger', COALESCE(v_as_passenger, 0),
        'total_rides', (COALESCE(v_as_driver, 0) + COALESCE(v_as_passenger, 0)),
        'personal_kg_co2_saved', v_total_co2
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ==============================================================================
-- 19. AUTOMATION FUNCTIONS FOR SESSION LIFECYCLE (TIMEZONE CONSISTENT: Asia/Karachi)
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.open_daily_session_rpc(p_slot TEXT)
RETURNS UUID AS $$
DECLARE
    v_session_id UUID;
    v_local_date DATE;
    v_slot_title TEXT;
BEGIN
    IF p_slot NOT IN ('morning', 'afternoon', 'evening') THEN
        RAISE EXCEPTION 'Invalid slot: %', p_slot;
    END IF;

    -- Timezone-consistent local date (Asia/Karachi)
    v_local_date := (now() AT TIME ZONE 'Asia/Karachi')::DATE;

    INSERT INTO public.ride_sessions (session_date, slot, status)
    VALUES (v_local_date, p_slot, 'open')
    ON CONFLICT (session_date, slot) DO UPDATE
    SET status = 'open'
    RETURNING id INTO v_session_id;

    v_slot_title := CASE 
        WHEN p_slot = 'morning' THEN 'Morning Commute'
        WHEN p_slot = 'afternoon' THEN 'Afternoon Shift'
        ELSE 'Evening Return'
    END;

    INSERT INTO public.notifications (user_id, title, message, type)
    SELECT 
        p.id,
        v_slot_title || ' Session Open! 🚗',
        'Ride session open — are you riding or do you need a lift?',
        'session_open'
    FROM public.profiles p;

    RETURN v_session_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.close_daily_session_rpc(p_slot TEXT)
RETURNS VOID AS $$
DECLARE
    v_session_id UUID;
    v_local_date DATE;
    v_driver RECORD;
    v_dist NUMERIC;
    v_emiss NUMERIC;
    v_co2 NUMERIC;
BEGIN
    v_local_date := (now() AT TIME ZONE 'Asia/Karachi')::DATE;

    -- First run expiry on any lingering unconfirmed matches
    PERFORM public.expire_unconfirmed_matches();

    SELECT id INTO v_session_id
    FROM public.ride_sessions
    WHERE session_date = v_local_date AND slot = p_slot;

    IF v_session_id IS NOT NULL THEN
        -- Fetch route distance and emission factor
        SELECT COALESCE(value, 2.5) INTO v_dist FROM public.app_config WHERE key = 'route_distance_km' LIMIT 1;
        IF v_dist IS NULL THEN v_dist := 2.5; END IF;

        SELECT COALESCE(value, 0.12) INTO v_emiss FROM public.app_config WHERE key = 'emission_factor_kg_per_km' LIMIT 1;
        IF v_emiss IS NULL THEN v_emiss := 0.12; END IF;

        -- For each driver in this session with CONFIRMED matches, record in ride_completion_log
        FOR v_driver IN
            SELECT driver_id, array_agg(passenger_id) AS p_ids, COUNT(*)::INT AS p_cnt
            FROM public.ride_matches
            WHERE session_id = v_session_id AND status IN ('confirmed', 'active')
            GROUP BY driver_id
        LOOP
            v_co2 := (v_dist * v_emiss * v_driver.p_cnt)::NUMERIC(10, 4);

            INSERT INTO public.ride_completion_log (
                session_id,
                driver_id,
                passenger_ids,
                passenger_count,
                distance_km,
                emission_factor_kg_per_km,
                kg_co2_saved,
                completed_at
            ) VALUES (
                v_session_id,
                v_driver.driver_id,
                v_driver.p_ids,
                v_driver.p_cnt,
                v_dist,
                v_emiss,
                v_co2,
                timezone('utc'::text, now())
            );
        END LOOP;

        UPDATE public.ride_sessions
        SET status = 'closed'
        WHERE id = v_session_id;

        UPDATE public.ride_matches
        SET status = 'completed'
        WHERE session_id = v_session_id AND status IN ('confirmed', 'active');
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ==============================================================================
-- 20. ENABLE REALTIME REPLICATION
-- ==============================================================================
ALTER PUBLICATION supabase_realtime ADD TABLE public.app_config;
ALTER PUBLICATION supabase_realtime ADD TABLE public.session_schedule;
ALTER PUBLICATION supabase_realtime ADD TABLE public.ride_sessions;
ALTER PUBLICATION supabase_realtime ADD TABLE public.driver_availability;
ALTER PUBLICATION supabase_realtime ADD TABLE public.passenger_log;
ALTER PUBLICATION supabase_realtime ADD TABLE public.ride_matches;
ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
ALTER PUBLICATION supabase_realtime ADD TABLE public.profiles;
ALTER PUBLICATION supabase_realtime ADD TABLE public.vehicles;
ALTER PUBLICATION supabase_realtime ADD TABLE public.ride_requests;
ALTER PUBLICATION supabase_realtime ADD TABLE public.ride_completion_log;


-- ==============================================================================
-- 20. DEFENSE-IN-DEPTH CONSTRAINTS (F4)
-- ==============================================================================
-- Backstops that hold even when the application logic above is wrong. These
-- duplicate rules already enforced in assign_passengers() and in the Flutter
-- client on purpose: the point is that they survive a bug in either.

-- F4.1 -- One active match per passenger per session.
--
-- assign_passengers() is supposed to guarantee this, but nothing outside that
-- function enforces it: a second code path, a retry, or a direct API call could
-- leave a passenger matched to two drivers in the same session. Partial, so
-- cancelled and completed history is unaffected -- a passenger can legitimately
-- have many non-active rows for one session.
CREATE UNIQUE INDEX IF NOT EXISTS uq_active_match_per_passenger
    ON public.ride_matches (session_id, passenger_id)
    WHERE status = 'active';

-- F4.2 -- A driver cannot offer more seats than their vehicle holds.
--
-- driver_availability.seats_offered is validated only in the UI. A stale client
-- or a direct API call can offer more seats than exist, which then over-fills
-- the priority queue and strands passengers who were told they had a seat.
--
-- Deliberately enforced only when a vehicle row exists. Accounts without a
-- registered vehicle -- the README's test admin account among them -- must not
-- be blocked from creating availability, so a missing vehicle is a pass, not a
-- failure. This is a trigger rather than a CHECK constraint because the limit
-- lives in another table and CHECK cannot reference one.
CREATE OR REPLACE FUNCTION public.trg_validate_seats_offered()
RETURNS TRIGGER AS $$
DECLARE
    v_capacity SMALLINT;
BEGIN
    SELECT capacity INTO v_capacity
    FROM public.vehicles
    WHERE user_id = NEW.driver_id;

    -- No vehicle registered: nothing to validate against.
    IF NOT FOUND OR v_capacity IS NULL THEN
        RETURN NEW;
    END IF;

    IF NEW.seats_offered > v_capacity THEN
        RAISE EXCEPTION
            'Cannot offer % seats: your registered vehicle holds % (driver %)',
            NEW.seats_offered, v_capacity, NEW.driver_id
            USING ERRCODE = 'check_violation';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_driver_availability_seats ON public.driver_availability;
CREATE TRIGGER trg_driver_availability_seats
    BEFORE INSERT OR UPDATE OF seats_offered ON public.driver_availability
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_validate_seats_offered();

-- ==============================================================================
-- 21. IDEMPOTENT RIDE-REQUEST CREATION (F5)
-- ==============================================================================
-- createRideRequest() had no idempotency key, so a retried insert on a flaky
-- connection -- or a passenger double-tapping "Create Request" -- produced two
-- identical open requests, each of which a different driver could then accept.
--
-- The client supplies a UUID it generates once per logical request. A retry
-- carrying the same key collides with this index instead of inserting again,
-- and the client treats the collision as "already created" and returns the
-- existing row.
--
-- Nullable, and unique only when present: rows created before this column
-- existed, and any client too old to send a key, must still be insertable.
ALTER TABLE public.ride_requests
    ADD COLUMN IF NOT EXISTS client_request_id UUID;

CREATE UNIQUE INDEX IF NOT EXISTS uq_ride_requests_client_request_id
    ON public.ride_requests (client_request_id)
    WHERE client_request_id IS NOT NULL;
