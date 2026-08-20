-- ==============================================================================
-- FFL SMART RIDE - ADMIN & SUPER ADMIN MIGRATION SCRIPT
-- ==============================================================================
-- Run this in the Supabase SQL Editor (https://supabase.com/dashboard/project/_/sql)

-- 1. PROFILES EXTENSIONS FOR ROLES & ACCESS CONTROL
ALTER TABLE public.profiles
ADD COLUMN IF NOT EXISTS employee_id TEXT,
ADD COLUMN IF NOT EXISTS full_name TEXT,
ADD COLUMN IF NOT EXISTS email TEXT,
ADD COLUMN IF NOT EXISTS phone TEXT,
ADD COLUMN IF NOT EXISTS home_address TEXT,
ADD COLUMN IF NOT EXISTS pickup_stop_id TEXT,
ADD COLUMN IF NOT EXISTS pickup_stop_order SMALLINT,
ADD COLUMN IF NOT EXISTS office_location TEXT DEFAULT 'Factory Main Plant',
ADD COLUMN IF NOT EXISTS vehicle_number TEXT,
ADD COLUMN IF NOT EXISTS has_vehicle BOOLEAN DEFAULT false,
ADD COLUMN IF NOT EXISTS national_id TEXT,
ADD COLUMN IF NOT EXISTS role TEXT NOT NULL DEFAULT 'user',
ADD COLUMN IF NOT EXISTS is_active BOOLEAN NOT NULL DEFAULT true,
ADD COLUMN IF NOT EXISTS created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now());

-- Add check constraint for role if not present
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'profiles_role_check'
  ) THEN
    ALTER TABLE public.profiles ADD CONSTRAINT profiles_role_check CHECK (role IN ('user', 'admin', 'super_admin'));
  END IF;
EXCEPTION
  WHEN OTHERS THEN NULL;
END $$;

-- Index for admin queries & auth lookups
CREATE INDEX IF NOT EXISTS idx_profiles_role_active ON public.profiles(role, is_active);

-- 2. HARDENED TRIGGER: PREVENT CLIENT-SIDE ROLE OR STATUS TAMPERING
-- Ensures NO regular client session can ever modify their own role or active status
CREATE OR REPLACE FUNCTION public.trg_protect_profile_role()
RETURNS TRIGGER AS $$
BEGIN
    IF auth.role() = 'authenticated' THEN
        IF NEW.role IS DISTINCT FROM OLD.role THEN
            RAISE EXCEPTION 'Modifying profile role directly from client is strictly forbidden.';
        END IF;
        IF NEW.is_active IS DISTINCT FROM OLD.is_active THEN
            RAISE EXCEPTION 'Modifying profile active status directly from client is strictly forbidden.';
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_protect_profile_role ON public.profiles;
CREATE TRIGGER trg_protect_profile_role
    BEFORE UPDATE ON public.profiles
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_protect_profile_role();

-- 3. EXTEND APP CONFIG WITH FUEL CONSUMPTION CONSTANT
INSERT INTO public.app_config (key, value, text_value, description)
VALUES ('fuel_consumption_l_per_km', 0.08, NULL, 'Average passenger vehicle fuel consumption in liters per km (0.08 L/km = 8L/100km)')
ON CONFLICT (key) DO UPDATE SET
    value = EXCLUDED.value,
    description = EXCLUDED.description,
    updated_at = now();

-- 4. EXTEND RIDE COMPLETION LOG WITH FUEL SAVED
ALTER TABLE public.ride_completion_log
ADD COLUMN IF NOT EXISTS liters_fuel_saved NUMERIC(10, 4) NOT NULL DEFAULT 0.0;

-- Backfill any existing historical rows with default 0.08 L/km if zero
UPDATE public.ride_completion_log
SET liters_fuel_saved = (distance_km * 0.08 * passenger_count)::NUMERIC(10, 4)
WHERE liters_fuel_saved = 0.0;

-- 5. UPDATE CO2 & FUEL SAVINGS VIEW
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
    ((rcl.kg_co2_saved / GREATEST(rcl.passenger_count, 1)) / 1000.0)::NUMERIC(10, 6) AS tons_co2_saved,
    (rcl.liters_fuel_saved / GREATEST(rcl.passenger_count, 1))::NUMERIC(10, 4) AS liters_fuel_saved
FROM public.ride_completion_log rcl,
LATERAL unnest(rcl.passenger_ids) AS p_id;

-- 6. UPDATE PROCEDURES & TRIGGERS TO COMPUTE FUEL SAVED AT COMPLETION

-- 6A. Update complete_driver_session_ride
CREATE OR REPLACE FUNCTION public.complete_driver_session_ride(p_session_id UUID)
RETURNS JSONB AS $$
DECLARE
    v_driver_id UUID := auth.uid();
    v_passenger_ids UUID[];
    v_p_count INT;
    v_pending_count INT;
    v_dist NUMERIC;
    v_emiss NUMERIC;
    v_fuel_rate NUMERIC;
    v_co2 NUMERIC;
    v_fuel NUMERIC;
    v_match RECORD;
BEGIN
    IF v_driver_id IS NULL THEN
        RAISE EXCEPTION 'User is not authenticated';
    END IF;

    SELECT COUNT(*)::INT INTO v_pending_count
    FROM public.ride_matches
    WHERE session_id = p_session_id AND driver_id = v_driver_id AND status = 'pending_confirmation';

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

    SELECT COALESCE(value, 2.5) INTO v_dist FROM public.app_config WHERE key = 'route_distance_km' LIMIT 1;
    IF v_dist IS NULL THEN v_dist := 2.5; END IF;

    SELECT COALESCE(value, 0.12) INTO v_emiss FROM public.app_config WHERE key = 'emission_factor_kg_per_km' LIMIT 1;
    IF v_emiss IS NULL THEN v_emiss := 0.12; END IF;

    SELECT COALESCE(value, 0.08) INTO v_fuel_rate FROM public.app_config WHERE key = 'fuel_consumption_l_per_km' LIMIT 1;
    IF v_fuel_rate IS NULL THEN v_fuel_rate := 0.08; END IF;

    v_co2 := (v_dist * v_emiss * v_p_count)::NUMERIC(10, 4);
    v_fuel := (v_dist * v_fuel_rate * v_p_count)::NUMERIC(10, 4);

    INSERT INTO public.ride_completion_log (
        session_id,
        driver_id,
        passenger_ids,
        passenger_count,
        distance_km,
        emission_factor_kg_per_km,
        kg_co2_saved,
        liters_fuel_saved,
        completed_at
    ) VALUES (
        p_session_id,
        v_driver_id,
        v_passenger_ids,
        v_p_count,
        v_dist,
        v_emiss,
        v_co2,
        v_fuel,
        timezone('utc'::text, now())
    );

    UPDATE public.ride_matches
    SET status = 'completed'
    WHERE session_id = p_session_id 
      AND driver_id = v_driver_id 
      AND status IN ('confirmed', 'active');

    FOR v_match IN
        SELECT passenger_id FROM public.ride_matches
        WHERE session_id = p_session_id AND driver_id = v_driver_id AND status = 'completed'
    LOOP
        INSERT INTO public.notifications (user_id, title, message, type)
        VALUES (
            v_match.passenger_id,
            'Trip Completed 🌿',
            format('Your carpool ride has concluded. Thank you for contributing to FFL sustainability! (Saved %s kg CO2 & %s L fuel)', v_co2 / v_p_count, v_fuel / v_p_count),
            'ride_completed'
        );
    END LOOP;

    RETURN jsonb_build_object(
        'success', true,
        'passengers_completed', v_p_count,
        'kg_co2_saved', v_co2,
        'liters_fuel_saved', v_fuel
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 6B. Update complete_ride
CREATE OR REPLACE FUNCTION public.complete_ride(p_ride_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_driver_id UUID := auth.uid();
    v_passenger_id UUID;
    v_dist NUMERIC;
    v_emiss NUMERIC;
    v_fuel_rate NUMERIC;
    v_co2 NUMERIC;
    v_fuel NUMERIC;
BEGIN
    SELECT passenger_id INTO v_passenger_id
    FROM public.ride_requests
    WHERE id = p_ride_id AND driver_id = v_driver_id AND status = 'accepted';

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Ride request not found or unauthorized';
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

        SELECT COALESCE(value, 0.08) INTO v_fuel_rate FROM public.app_config WHERE key = 'fuel_consumption_l_per_km' LIMIT 1;
        IF v_fuel_rate IS NULL THEN v_fuel_rate := 0.08; END IF;

        v_co2 := (v_dist * v_emiss * 1.0)::NUMERIC(10, 4);
        v_fuel := (v_dist * v_fuel_rate * 1.0)::NUMERIC(10, 4);

        INSERT INTO public.ride_completion_log (
            session_id,
            driver_id,
            passenger_ids,
            passenger_count,
            distance_km,
            emission_factor_kg_per_km,
            kg_co2_saved,
            liters_fuel_saved,
            completed_at
        ) VALUES (
            NULL,
            v_driver_id,
            ARRAY[v_passenger_id],
            1,
            v_dist,
            v_emiss,
            v_co2,
            v_fuel,
            timezone('utc'::text, now())
        );
    END IF;

    INSERT INTO public.notifications (user_id, ride_id, title, message, type)
    VALUES (
        v_passenger_id,
        p_ride_id,
        'Trip Completed 🌿',
        'Your carpool trip is complete. Thank you for helping reduce emissions!',
        'ride_completed'
    );

    RETURN jsonb_build_object('success', true, 'status', 'completed', 'kg_co2_saved', v_co2, 'liters_fuel_saved', v_fuel);
END;
$$;

-- 6C. Update trg_log_ride_request_completion
CREATE OR REPLACE FUNCTION public.trg_log_ride_request_completion()
RETURNS TRIGGER AS $$
DECLARE
    v_dist NUMERIC;
    v_emiss NUMERIC;
    v_fuel_rate NUMERIC;
    v_co2 NUMERIC;
    v_fuel NUMERIC;
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

            SELECT COALESCE(value, 0.08) INTO v_fuel_rate FROM public.app_config WHERE key = 'fuel_consumption_l_per_km' LIMIT 1;
            IF v_fuel_rate IS NULL THEN v_fuel_rate := 0.08; END IF;

            v_co2 := (v_dist * v_emiss * 1.0)::NUMERIC(10, 4);
            v_fuel := (v_dist * v_fuel_rate * 1.0)::NUMERIC(10, 4);

            INSERT INTO public.ride_completion_log (
                session_id,
                driver_id,
                passenger_ids,
                passenger_count,
                distance_km,
                emission_factor_kg_per_km,
                kg_co2_saved,
                liters_fuel_saved,
                completed_at
            ) VALUES (
                NULL,
                NEW.driver_id,
                ARRAY[NEW.passenger_id],
                1,
                v_dist,
                v_emiss,
                v_co2,
                v_fuel,
                timezone('utc'::text, now())
            );
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 6D. Update close_daily_session_rpc
CREATE OR REPLACE FUNCTION public.close_daily_session_rpc(p_slot TEXT)
RETURNS VOID AS $$
DECLARE
    v_session_id UUID;
    v_local_date DATE;
    v_driver RECORD;
    v_dist NUMERIC;
    v_emiss NUMERIC;
    v_fuel_rate NUMERIC;
    v_co2 NUMERIC;
    v_fuel NUMERIC;
BEGIN
    v_local_date := (now() AT TIME ZONE 'Asia/Karachi')::DATE;

    PERFORM public.expire_unconfirmed_matches();

    SELECT id INTO v_session_id
    FROM public.ride_sessions
    WHERE session_date = v_local_date AND slot = p_slot;

    IF v_session_id IS NOT NULL THEN
        SELECT COALESCE(value, 2.5) INTO v_dist FROM public.app_config WHERE key = 'route_distance_km' LIMIT 1;
        IF v_dist IS NULL THEN v_dist := 2.5; END IF;

        SELECT COALESCE(value, 0.12) INTO v_emiss FROM public.app_config WHERE key = 'emission_factor_kg_per_km' LIMIT 1;
        IF v_emiss IS NULL THEN v_emiss := 0.12; END IF;

        SELECT COALESCE(value, 0.08) INTO v_fuel_rate FROM public.app_config WHERE key = 'fuel_consumption_l_per_km' LIMIT 1;
        IF v_fuel_rate IS NULL THEN v_fuel_rate := 0.08; END IF;

        FOR v_driver IN
            SELECT driver_id, array_agg(passenger_id) AS p_ids, COUNT(*)::INT AS p_cnt
            FROM public.ride_matches
            WHERE session_id = v_session_id AND status IN ('confirmed', 'active')
            GROUP BY driver_id
        LOOP
            v_co2 := (v_dist * v_emiss * v_driver.p_cnt)::NUMERIC(10, 4);
            v_fuel := (v_dist * v_fuel_rate * v_driver.p_cnt)::NUMERIC(10, 4);

            INSERT INTO public.ride_completion_log (
                session_id,
                driver_id,
                passenger_ids,
                passenger_count,
                distance_km,
                emission_factor_kg_per_km,
                kg_co2_saved,
                liters_fuel_saved,
                completed_at
            ) VALUES (
                v_session_id,
                v_driver.driver_id,
                v_driver.p_ids,
                v_driver.p_cnt,
                v_dist,
                v_emiss,
                v_co2,
                v_fuel,
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
-- 7. SECURE ADMIN RPC PROCEDURES (NATIVE SUPABASE POSTGRESQL)
-- ==============================================================================

-- A. CREATE USER (ADMIN & SUPER ADMIN)
CREATE OR REPLACE FUNCTION public.admin_create_user(
    p_email TEXT,
    p_password TEXT,
    p_full_name TEXT,
    p_employee_id TEXT,
    p_national_id TEXT,
    p_phone TEXT DEFAULT NULL,
    p_home_address TEXT DEFAULT NULL,
    p_has_vehicle BOOLEAN DEFAULT false,
    p_vehicle_type TEXT DEFAULT 'Car',
    p_make TEXT DEFAULT NULL,
    p_model TEXT DEFAULT NULL,
    p_license_plate TEXT DEFAULT NULL,
    p_color TEXT DEFAULT 'White',
    p_capacity INT DEFAULT 3
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
DECLARE
    v_caller_role TEXT;
    v_user_id UUID;
    v_encrypted_pw TEXT;
BEGIN
    SELECT role INTO v_caller_role
    FROM public.profiles
    WHERE id = auth.uid();

    IF v_caller_role NOT IN ('admin', 'super_admin') THEN
        RAISE EXCEPTION 'Unauthorized: Only admins can pre-register employees.';
    END IF;

    -- Check if user already exists
    SELECT id INTO v_user_id FROM auth.users WHERE email = lower(trim(p_email));

    IF v_user_id IS NULL THEN
        v_user_id := gen_random_uuid();
        v_encrypted_pw := crypt(p_password, gen_salt('bf'));

        INSERT INTO auth.users (
            instance_id,
            id,
            aud,
            role,
            email,
            encrypted_password,
            email_confirmed_at,
            raw_app_meta_data,
            raw_user_meta_data,
            created_at,
            updated_at,
            confirmation_token,
            email_change,
            email_change_token_new,
            recovery_token
        ) VALUES (
            '00000000-0000-0000-0000-000000000000',
            v_user_id,
            'authenticated',
            'authenticated',
            lower(trim(p_email)),
            v_encrypted_pw,
            now(),
            '{"provider":"email","providers":["email"]}',
            jsonb_build_object('full_name', trim(p_full_name), 'employee_id', trim(p_employee_id)),
            now(),
            now(),
            '',
            '',
            '',
            ''
        );
    ELSE
        v_encrypted_pw := crypt(p_password, gen_salt('bf'));
        UPDATE auth.users
        SET encrypted_password = v_encrypted_pw,
            email_confirmed_at = COALESCE(email_confirmed_at, now()),
            updated_at = now()
        WHERE id = v_user_id;
    END IF;

    INSERT INTO public.profiles (
        id,
        employee_id,
        full_name,
        email,
        phone,
        home_address,
        national_id,
        office_location,
        has_vehicle,
        vehicle_number,
        role,
        is_active,
        created_at,
        updated_at
    ) VALUES (
        v_user_id,
        trim(p_employee_id),
        trim(p_full_name),
        lower(trim(p_email)),
        trim(p_phone),
        trim(p_home_address),
        trim(p_national_id),
        'Factory Main Plant',
        p_has_vehicle,
        CASE WHEN p_has_vehicle THEN upper(trim(p_license_plate)) ELSE NULL END,
        'user',
        true,
        now(),
        now()
    )
    ON CONFLICT (id) DO UPDATE SET
        employee_id = EXCLUDED.employee_id,
        full_name = EXCLUDED.full_name,
        email = EXCLUDED.email,
        phone = EXCLUDED.phone,
        home_address = EXCLUDED.home_address,
        national_id = EXCLUDED.national_id,
        has_vehicle = EXCLUDED.has_vehicle,
        vehicle_number = EXCLUDED.vehicle_number,
        role = 'user',
        is_active = true,
        updated_at = now();

    IF p_has_vehicle AND p_license_plate IS NOT NULL AND trim(p_license_plate) <> '' THEN
        INSERT INTO public.vehicles (
            id,
            user_id,
            vehicle_type,
            make,
            model,
            license_plate,
            color,
            capacity,
            created_at,
            updated_at
        ) VALUES (
            gen_random_uuid(),
            v_user_id,
            COALESCE(p_vehicle_type, 'Car'),
            COALESCE(trim(p_make), ''),
            COALESCE(trim(p_model), ''),
            upper(trim(p_license_plate)),
            COALESCE(trim(p_color), 'White'),
            COALESCE(p_capacity, 3),
            now(),
            now()
        )
        ON CONFLICT (user_id) DO UPDATE SET
            vehicle_type = EXCLUDED.vehicle_type,
            make = EXCLUDED.make,
            model = EXCLUDED.model,
            license_plate = EXCLUDED.license_plate,
            color = EXCLUDED.color,
            capacity = EXCLUDED.capacity,
            updated_at = now();
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'user_id', v_user_id,
        'email', lower(trim(p_email)),
        'full_name', trim(p_full_name)
    );
END;
$$;

-- B. REMOVE / DEACTIVATE USER (ADMIN & SUPER ADMIN)
CREATE OR REPLACE FUNCTION public.admin_remove_user(
    p_target_user_id UUID,
    p_deactivate BOOLEAN DEFAULT true
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
DECLARE
    v_caller_role TEXT;
    v_target_role TEXT;
BEGIN
    SELECT role INTO v_caller_role
    FROM public.profiles
    WHERE id = auth.uid();

    IF v_caller_role NOT IN ('admin', 'super_admin') THEN
        RAISE EXCEPTION 'Unauthorized: Only admins can deactivate users.';
    END IF;

    SELECT role INTO v_target_role
    FROM public.profiles
    WHERE id = p_target_user_id;

    IF v_target_role = 'super_admin' THEN
        RAISE EXCEPTION 'Super admins cannot be deactivated.';
    END IF;

    IF v_target_role = 'admin' AND v_caller_role <> 'super_admin' THEN
        RAISE EXCEPTION 'Only super admins can deactivate other administrators.';
    END IF;

    UPDATE public.profiles
    SET is_active = NOT p_deactivate,
        updated_at = now()
    WHERE id = p_target_user_id;

    IF p_deactivate THEN
        UPDATE auth.users
        SET banned_until = '2099-01-01 00:00:00+00'
        WHERE id = p_target_user_id;
    ELSE
        UPDATE auth.users
        SET banned_until = NULL
        WHERE id = p_target_user_id;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'user_id', p_target_user_id,
        'is_active', NOT p_deactivate
    );
END;
$$;

-- C. PROMOTE ADMIN (SUPER ADMIN ONLY)
CREATE OR REPLACE FUNCTION public.admin_add_admin(
    p_target_user_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
DECLARE
    v_caller_role TEXT;
BEGIN
    SELECT role INTO v_caller_role
    FROM public.profiles
    WHERE id = auth.uid();

    IF v_caller_role <> 'super_admin' THEN
        RAISE EXCEPTION 'Unauthorized: Only super admins can promote users to admin.';
    END IF;

    UPDATE public.profiles
    SET role = 'admin',
        is_active = true,
        updated_at = now()
    WHERE id = p_target_user_id;

    RETURN jsonb_build_object(
        'success', true,
        'user_id', p_target_user_id,
        'role', 'admin'
    );
END;
$$;

-- D. DEMOTE ADMIN (SUPER ADMIN ONLY)
CREATE OR REPLACE FUNCTION public.admin_remove_admin(
    p_target_user_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
DECLARE
    v_caller_role TEXT;
BEGIN
    SELECT role INTO v_caller_role
    FROM public.profiles
    WHERE id = auth.uid();

    IF v_caller_role <> 'super_admin' THEN
        RAISE EXCEPTION 'Unauthorized: Only super admins can remove admin permissions.';
    END IF;

    IF p_target_user_id = auth.uid() THEN
        RAISE EXCEPTION 'Cannot demote your own account.';
    END IF;

    UPDATE public.profiles
    SET role = 'user',
        updated_at = now()
    WHERE id = p_target_user_id;

    RETURN jsonb_build_object(
        'success', true,
        'user_id', p_target_user_id,
        'role', 'user'
    );
END;
$$;

-- ==============================================================================
-- 8. ONE-TIME FIRST SUPER ADMIN PROMOTION COMMAND
-- ==============================================================================
-- Run this replacing the placeholder with your registered employee email:
-- UPDATE public.profiles
-- SET role = 'super_admin', is_active = true
-- WHERE email = 'your_email@example.com';
