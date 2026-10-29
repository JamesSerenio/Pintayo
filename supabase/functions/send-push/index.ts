import { createClient } from "@supabase/supabase-js";
import { accessToken, type ServiceAccount } from "../_shared/fcm_client.ts";
import { authorized } from "../_shared/request_auth.ts";
import { dispatchEvent } from "../_shared/push_dispatcher.ts";
import { SupabasePushStore } from "../_shared/supabase_push_store.ts";

// Called by a trusted scheduled worker, never directly by the Flutter client.
// No untrusted payload selects a sender, recipient, notification text, or event.
Deno.serve(async (request: Request) => {
  if (request.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }
  if (!await authorized(request)) {
    return new Response("Unauthorized", { status: 401 });
  }
  const credentials = Deno.env.get("FCM_SERVICE_ACCOUNT");
  if (!credentials) return new Response("Push not configured", { status: 503 });
  try {
    const account: ServiceAccount = JSON.parse(credentials);
    const db = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
      {
        auth: { persistSession: false, autoRefreshToken: false },
      },
    );
    const { data: events, error } = await db.rpc("claim_push");
    if (error) throw error;
    if (!events?.length) return Response.json({ processed: 0 });
    const token = await accessToken(account);
    let processed = 0;
    const store = new SupabasePushStore(db);
    for (const event of events ?? []) {
      if (await dispatchEvent(store, event, token)) processed++;
    }
    await db.rpc("expire_sharing");
    return Response.json({ processed });
  } catch (_) {
    // Never log credentials, message contents, or device identifiers.
    return Response.json({
      error: "Dispatch failed; leased events will retry.",
    }, { status: 500 });
  }
});
