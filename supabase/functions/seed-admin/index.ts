import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.14.0";

// ⚠️ WARNING: DEVELOPMENT & TESTING ONLY.
// Seeds a test admin account (admin11@gmail.com). Remove or rotate before production.

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

    const supabaseAdmin = createClient(supabaseUrl, supabaseServiceKey);

    const email = "admin11@gmail.com";
    const password = "admin11";

    // 1. Check if user already exists
    const { data: userList } = await supabaseAdmin.auth.admin.listUsers();
    const existingUser = userList?.users.find((u) => u.email === email);

    let userId = existingUser?.id;

    if (!existingUser) {
      // 2. Create Auth User via Admin API
      const { data: newUser, error: createError } = await supabaseAdmin.auth.admin.createUser({
        email: email,
        password: password,
        email_confirm: true,
        user_metadata: {
          full_name: "Test Administrator",
          employee_id: "ADM-0011",
        },
      });

      if (createError) throw createError;
      userId = newUser.user.id;
    } else {
      // Reset password if user already exists
      await supabaseAdmin.auth.admin.updateUserById(existingUser.id, {
        password: password,
        email_confirm: true,
      });
    }

    // 3. Upsert Profile with role = 'admin' and no vehicle
    const { error: profileError } = await supabaseAdmin.from("profiles").upsert({
      id: userId,
      employee_id: "ADM-0011",
      full_name: "Test Administrator",
      email: email,
      phone: "+923000000011",
      home_address: "Township Admin Block, Sector A",
      office_location: "Factory Main Plant",
      has_vehicle: false,
      role: "admin",
      is_active: true,
      updated_at: new Date().toISOString(),
    });

    if (profileError) throw profileError;

    return new Response(
      JSON.stringify({
        success: true,
        message: "Test admin account (admin11@gmail.com) seeded successfully with role 'admin'.",
        user: {
          id: userId,
          email: email,
          role: "admin",
          has_vehicle: false,
        },
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
