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

    // 3. Extract target_user_id & optional action (default: deactivate)
    const body = await req.json();
    const targetUserId = body.target_user_id;
    const action = body.action || "deactivate"; // 'deactivate' or 'reactivate'

    if (!targetUserId) {
      return new Response(
        JSON.stringify({ success: false, error: "Missing target_user_id" }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 400 }
      );
    }

    if (targetUserId === callerUser.id && action === "deactivate") {
      return new Response(
        JSON.stringify({ success: false, error: "You cannot deactivate your own admin account" }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 400 }
      );
    }

    // Fetch target user's profile to prevent hierarchy violation
    const { data: targetProfile } = await adminSupabase
      .from("profiles")
      .select("role")
      .eq("id", targetUserId)
      .single();

    if (targetProfile) {
      if (callerProfile.role === "admin" && ["admin", "super_admin"].includes(targetProfile.role)) {
        return new Response(
          JSON.stringify({ success: false, error: "Admins cannot deactivate other admins or super admins" }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 403 }
        );
      }
    }

    const isDeactivate = action === "deactivate";

    // 4. Soft deactivate/reactivate in public.profiles (WITHOUT touching ride_completion_log)
    const { error: updateProfileError } = await adminSupabase
      .from("profiles")
      .update({
        is_active: !isDeactivate,
        updated_at: new Date().toISOString(),
      })
      .eq("id", targetUserId);

    if (updateProfileError) {
      throw updateProfileError;
    }

    // 5. Lock/Unlock Auth account via Supabase Admin API
    try {
      await adminSupabase.auth.admin.updateUserById(targetUserId, {
        ban_duration: isDeactivate ? "876000h" : "none",
      });
    } catch (authBanErr) {
      console.warn("Could not update auth ban status:", authBanErr);
    }

    return new Response(
      JSON.stringify({
        success: true,
        message: isDeactivate
          ? "User deactivated successfully. Historical ride logs preserved."
          : "User reactivated successfully.",
        target_user_id: targetUserId,
        is_active: !isDeactivate,
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 200 }
    );
  } catch (error) {
    return new Response(
      JSON.stringify({ success: false, error: (error as Error).message }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 400 }
    );
  }
});
