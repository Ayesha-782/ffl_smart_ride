import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.14.0";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(
        JSON.stringify({ success: false, error: "Missing Authorization header" }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 401 }
      );
    }

    const token = authHeader.replace("Bearer ", "");
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

    // 1. Verify caller identity using JWT
    const clientSupabase = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: `Bearer ${token}` } },
    });

    const { data: { user: callerUser }, error: authError } = await clientSupabase.auth.getUser();
    if (authError || !callerUser) {
      return new Response(
        JSON.stringify({ success: false, error: "Unauthorized: Invalid JWT token" }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 401 }
      );
    }

    // 2. Query caller's profile role using Admin Client
    const adminSupabase = createClient(supabaseUrl, supabaseServiceKey);

    const { data: callerProfile, error: profileError } = await adminSupabase
      .from("profiles")
      .select("role, is_active")
      .eq("id", callerUser.id)
      .single();

    if (
      profileError ||
      !callerProfile ||
      !["admin", "super_admin"].includes(callerProfile.role) ||
      !callerProfile.is_active
    ) {
      return new Response(
        JSON.stringify({ success: false, error: "Forbidden: Admin or Super Admin privileges required" }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 403 }
      );
    }

    // 3. Extract user payload
    const body = await req.json();
    const {
      name,
      email,
      house_address,
      national_id,
      employee_id,
      phone,
      password = "FFLSmartRide2025!",
      pickup_stop_id,
      vehicle_details,
    } = body;

    if (!name || !email) {
      return new Response(
        JSON.stringify({ success: false, error: "Name and email are required" }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 400 }
      );
    }

    // Generate clean employee ID fallback if omitted
    const empId = employee_id || `EMP-${Date.now().toString().slice(-6)}`;

    // 4. Create Auth user via Supabase Admin API
    const { data: authData, error: createAuthError } = await adminSupabase.auth.admin.createUser({
      email: email.trim().toLowerCase(),
      password: password,
      email_confirm: true,
      user_metadata: {
        full_name: name.trim(),
        employee_id: empId,
      },
    });

    if (createAuthError) {
      throw createAuthError;
    }

    const newUserId = authData.user.id;
    const hasVehicle = !!(vehicle_details && (vehicle_details.license_plate || vehicle_details.make));

    // 5. Upsert profile row
    const profilePayload: Record<string, any> = {
      id: newUserId,
      employee_id: empId,
      full_name: name.trim(),
      email: email.trim().toLowerCase(),
      phone: phone || null,
      home_address: house_address || null,
      national_id: national_id || null,
      pickup_stop_id: pickup_stop_id || null,
      office_location: "Factory Main Plant",
      has_vehicle: hasVehicle,
      role: "user",
      is_active: true,
      updated_at: new Date().toISOString(),
    };

    const { error: profileUpsertError } = await adminSupabase
      .from("profiles")
      .upsert(profilePayload);

    if (profileUpsertError) {
      throw profileUpsertError;
    }

    // 6. If vehicle details provided, insert into vehicles table
    if (hasVehicle) {
      const vehiclePayload = {
        user_id: newUserId,
        vehicle_type: vehicle_details.vehicle_type || "Car",
        make: vehicle_details.make || "Unknown",
        model: vehicle_details.model || "Unknown",
        license_plate: (vehicle_details.license_plate || `FFL-${Date.now().toString().slice(-4)}`).toUpperCase(),
        color: vehicle_details.color || "Standard",
        capacity: Number(vehicle_details.capacity) || 3,
        updated_at: new Date().toISOString(),
      };

      const { error: vehicleError } = await adminSupabase
        .from("vehicles")
        .upsert(vehiclePayload, { onConflict: "user_id" });

      if (vehicleError) {
        console.error("Vehicle creation warning:", vehicleError);
      }
    }

    return new Response(
      JSON.stringify({
        success: true,
        message: "Employee user created and pre-registered successfully",
        user: {
          id: newUserId,
          name: name.trim(),
          email: email.trim().toLowerCase(),
          employee_id: empId,
          role: "user",
          is_active: true,
          has_vehicle: hasVehicle,
        },
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 201 }
    );
  } catch (error) {
    return new Response(
      JSON.stringify({ success: false, error: (error as Error).message }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 400 }
    );
  }
});
