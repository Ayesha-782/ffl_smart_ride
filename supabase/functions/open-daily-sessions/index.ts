// Follow Deno and Supabase Edge Function standards
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
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const fcmServerKey = Deno.env.get("FCM_SERVER_KEY");

    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // Read payload or determine current slot from schedule
    let slot = "morning";
    try {
      const body = await req.json();
      if (body.slot) {
        slot = body.slot;
      }
    } catch {
      // Default based on current UTC+5 / local hour
      const hour = new Date().getHours();
      if (hour >= 6 && hour < 12) slot = "morning";
      else if (hour >= 12 && hour < 16) slot = "afternoon";
      else slot = "evening";
    }

    // Call open_daily_session_rpc
    const { data: sessionId, error: rpcError } = await supabase.rpc(
      "open_daily_session_rpc",
      { p_slot: slot }
    );

    if (rpcError) {
      throw rpcError;
    }

    const slotTitle =
      slot === "morning"
        ? "Morning Commute"
        : slot === "afternoon"
        ? "Afternoon Shift"
        : "Evening Return";

    // Broadcast FCM push notification if FCM server key is configured
    if (fcmServerKey) {
      const pushPayload = {
        to: "/topics/all_employees",
        notification: {
          title: `${slotTitle} Session Open! 🚗`,
          body: "Ride session open — are you riding or do you need a lift?",
          sound: "default",
        },
        data: {
          type: "session_open",
          session_id: sessionId,
          slot: slot,
        },
      };

      await fetch("https://fcm.googleapis.com/fcm/send", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `key=${fcmServerKey}`,
        },
        body: JSON.stringify(pushPayload),
      });
    }

    return new Response(
      JSON.stringify({
        success: true,
        session_id: sessionId,
        slot: slot,
        message: `Ride session '${slot}' opened successfully.`,
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 200,
      }
    );
  } catch (error) {
    return new Response(
      JSON.stringify({ success: false, error: (error as Error).message }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 400,
      }
    );
  }
});
