import { copyForwardedAttachment } from "../_shared/message_attachment_copy.ts";
import { createClient } from "@supabase/supabase-js";
import { cleanupAttachments } from "../_shared/attachment_cleanup.ts";
import { authorized } from "../_shared/request_auth.ts";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, apikey, content-type, x-client-info",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
Deno.serve(async (request: Request) => {
  if (request.method === "OPTIONS") {
    return new Response(null, { headers: cors });
  }
  const reply = (body: unknown, status = 200) =>
    Response.json(body, { status, headers: cors });
  if (request.method !== "POST") return reply({ error: "POST required" }, 405);
  const url = Deno.env.get("SUPABASE_URL")!;
  const admin = createClient(url, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  try {
    if (await authorized(request)) {
      return reply({ removed: await cleanupAttachments(admin) });
    }
    const token = request.headers.get("authorization")?.replace(
      /^Bearer\s+/i,
      "",
    );
    if (!token) return reply({ error: "Sign in required" }, 401);
    const identity = await admin.auth.getUser(token);
    if (identity.error || !identity.data.user) {
      return reply({ error: "Sign in required" }, 401);
    }
    const user = createClient(url, Deno.env.get("SUPABASE_ANON_KEY")!, {
      global: { headers: { Authorization: `Bearer ${token}` } },
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const body = await request.json();
    if (body.action === "delete_everyone" && uuid.test(body.message_id ?? "")) {
      const result = await user.rpc("delete_message_everyone", {
        message_id: body.message_id,
      });
      if (result.error) {
        return reply({
          error: "Only the original sender can delete this message.",
        }, 403);
      }
      // Global redaction already committed. Cleanup failures stay queued for retry.
      await cleanupAttachments(admin).catch(() => 0);
      return reply({ ok: true });
    }
    if (
      body.action !== "forward" ||
      ![body.request_id, body.source_id, body.destination].every((v) =>
        typeof v === "string" && uuid.test(v)
      )
    ) {
      return reply({ error: "Invalid message action" }, 400);
    }
    const prepared = await user.rpc("prepare_message_forward", {
      request_id: body.request_id,
      source_message: body.source_id,
      destination_chat: body.destination,
    });
    if (prepared.error) {
      return reply(
        { error: "Message or destination is no longer available." },
        403,
      );
    }
    const job = prepared.data;
    if (!job.complete) {
      if (job.source_path && !job.copied) {
        await copyForwardedAttachment(
          admin,
          job.source_path,
          job.destination_path,
        );
      }
      const finished = await admin.rpc("finish_message_forward", {
        request_id: body.request_id,
        acting_user: identity.data.user.id,
      });
      if (finished.error) {
        return reply({
          error:
            "Forward could not complete. The source or destination may have changed.",
        }, 409);
      }
    }
    await cleanupAttachments(admin).catch(() => 0);
    return reply({ ok: true, message_id: body.request_id });
  } catch (_) {
    // Do not expose private paths, signed URLs, message contents or credentials.
    return reply({ error: "Message action failed. Please retry." }, 500);
  }
});
