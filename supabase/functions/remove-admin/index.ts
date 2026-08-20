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

    if (profileError || !callerProfile || callerProfile.role !== "super_admin" || !callerProfile.is_active) {
      return new Response(
        JSON.stringify({ success: false, error: "Forbidden: Super Admin privileges required" }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 403 }
      );
    }

    // 3. Process target user demotion
    const body = await req.json();
    const targetUserId = body.target_user_id;

    if (!targetUserId) {
      return new Response(
        JSON.stringify({ success: false, error: "Missing target_user_id" }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 400 }
      );
    }

    if (targetUserId === callerUser.id) {
      return new Response(
        JSON.stringify({ success: false, error: "Super Admin cannot demote themselves" }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 400 }
      );
    }

    const { error: updateError } = await adminSupabase
      .from("profiles")
      .update({ role: "user", updated_at: new Date().toISOString() })
      .eq("id", targetUserId);

    if (updateError) {
      throw updateError;
    }

    return new Response(
      JSON.stringify({
        success: true,
        message: "Admin demoted to regular user successfully",
        target_user_id: targetUserId,
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
