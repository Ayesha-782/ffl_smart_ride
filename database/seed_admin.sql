-- ==============================================================================
-- FFL SMART RIDE - SEED PRE-MADE TEST ADMIN ACCOUNT (SERVER-SIDE / SQL EDITOR)
-- ==============================================================================
-- ⚠️ WARNING: DEVELOPMENT & TESTING ONLY.
-- Contains a known password ('admin11'). MUST BE REMOVED OR ROTATED BEFORE PRODUCTION DEPLOYMENT.
-- Run this script in the Supabase SQL Editor: https://supabase.com/dashboard/project/_/sql

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- 1. Bulletproof Schema Sync: Ensure all expected columns exist on public.profiles
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

-- 2. Seed or update the test admin user
DO $$
DECLARE
  v_admin_id UUID;
  v_encrypted_pw TEXT;
BEGIN
  -- Check if admin11@gmail.com exists in auth.users
  SELECT id INTO v_admin_id FROM auth.users WHERE email = 'admin11@gmail.com';

  -- Encrypt password 'admin11' with Blowfish salt
  v_encrypted_pw := crypt('admin11', gen_salt('bf'));

  IF v_admin_id IS NULL THEN
    v_admin_id := gen_random_uuid();

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
      v_admin_id,
      'authenticated',
      'authenticated',
      'admin11@gmail.com',
      v_encrypted_pw,
      now(),
      '{"provider":"email","providers":["email"]}',
      '{"full_name":"Test Administrator","employee_id":"ADM-0011"}',
      now(),
      now(),
      '',
      '',
      '',
      ''
    );
  ELSE
    UPDATE auth.users
    SET encrypted_password = v_encrypted_pw,
        email_confirmed_at = COALESCE(email_confirmed_at, now()),
        updated_at = now()
    WHERE id = v_admin_id;
  END IF;

  -- 3. Upsert profile with role = 'admin' and no vehicle
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
    has_vehicle,
    role,
    is_active,
    created_at,
    updated_at
  ) VALUES (
    v_admin_id,
    'ADM-0011',
    'Test Administrator',
    'admin11@gmail.com',
    '+923000000011',
    'Township Admin Block, Sector A',
    NULL,
    NULL,
    'Factory Main Plant',
    NULL,
    false,
    'admin',
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
    role = 'admin',
    is_active = true,
    has_vehicle = false,
    updated_at = now();

  RAISE NOTICE 'Successfully seeded test admin user: admin11@gmail.com (ID: %)', v_admin_id;
END $$;
