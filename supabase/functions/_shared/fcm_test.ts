import { authorized } from "./request_auth.ts";
import { fcmEndpoint, pushMessage } from "./fcm_client.ts";

Deno.test("dispatch requires the dedicated worker secret, not a client bearer key", async () => {
  Deno.env.set("PUSH_WORKER_SECRET", "test-only-worker-secret-12345");
  const missing = new Request("http://localhost", {
    method: "POST",
    headers: { authorization: "Bearer public-key" },
  });
  const wrong = new Request("http://localhost", {
    method: "POST",
    headers: { "x-worker-secret": "wrong" },
  });
  const valid = new Request("http://localhost", {
    method: "POST",
    headers: { "x-worker-secret": "test-only-worker-secret-12345" },
  });
  if (
    await authorized(missing) || await authorized(wrong) ||
    !await authorized(valid)
  ) {
    throw new Error("Worker authentication failed");
  }
  Deno.env.delete("PUSH_WORKER_SECRET");
});

Deno.test("FCM v1 payload targets the actual project and provides account-safe navigation", () => {
  if (
    fcmEndpoint !==
      "https://fcm.googleapis.com/v1/projects/pintayo/messages:send"
  ) throw new Error("Wrong Firebase target");
  const message = pushMessage(
    { id: "event-fixture", kind: "message", recipient: "recipient-fixture" },
    "test-only-fid",
    "conversation-fixture",
  );
  if (
    message.data.recipient_id !== "recipient-fixture" ||
    message.data.conversation_id !== "conversation-fixture"
  ) throw new Error("Missing navigation identity");
  if (message.android.notification.channel_id !== "pintayo_messages") {
    throw new Error("Wrong Android channel");
  }
  if ("token" in message || "delivered_at" in message || "seen_at" in message) {
    throw new Error("Incorrect registration/receipt semantics");
  }
});
