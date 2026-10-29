import {
  dispatchEvent,
  type PushDevice,
  type PushDispatchStore,
} from "./push_dispatcher.ts";

class Store implements PushDispatchStore {
  current: PushDevice[] = [{
    installation: "test-installation",
    token: "test-only-fid",
    generation: "generation-a",
  }];
  receipts = new Set<string>();
  completed = 0;
  blocked = false;
  deviceReads = 0;
  switchDuringDispatch = false;
  // Durable message fixture is independent of notification transport.
  messages = new Map([["saved-message", {
    body: "Test message",
    delivered: false,
    seen: false,
  }]]);
  payload(_event: string): Promise<{ conversation_id?: string } | null> {
    return Promise.resolve(
      this.blocked ? null : { conversation_id: "test-conversation" },
    );
  }
  devices(_event: string) {
    this.deviceReads++;
    return Promise.resolve(
      this.switchDuringDispatch && this.deviceReads > 1 ? [] : this.current,
    );
  }
  accepted(_event: string, installation: string) {
    return Promise.resolve(this.receipts.has(installation));
  }
  accept(_event: string, installation: string) {
    this.receipts.add(installation);
    return Promise.resolve();
  }
  invalidate(_recipient: string, device: PushDevice) {
    this.current = this.current.filter((d) =>
      d.generation !== device.generation
    );
    return Promise.resolve();
  }
  complete(_event: string) {
    this.completed++;
    return Promise.resolve();
  }
}
const event = {
  id: "test-event",
  kind: "message",
  recipient: "test-recipient",
};
Deno.test("FCM failure preserves saved messages and leaves the event retryable", async () => {
  const store = new Store();
  const send: typeof fetch = () =>
    Promise.resolve(new Response("{}", { status: 503 }));
  const done = await dispatchEvent(
    store,
    event,
    "test-only-authorization",
    send,
  );
  if (
    done || store.completed || store.receipts.size || store.messages.size !== 1
  ) throw new Error("Failure changed durable state");
  const message = store.messages.get("saved-message")!;
  if (message.delivered || message.seen) {
    throw new Error("Push transport changed chat receipts");
  }
});
Deno.test("accepted events deduplicate per device without marking chat delivered", async () => {
  const store = new Store();
  let sends = 0;
  const send: typeof fetch = () => {
    sends++;
    return Promise.resolve(new Response("{}"));
  };
  await dispatchEvent(store, event, "test-only-authorization", send);
  await dispatchEvent(store, event, "test-only-authorization", send);
  if (sends !== 1 || store.messages.get("saved-message")!.delivered) {
    throw new Error("Deduplication or receipt semantics failed");
  }
});
Deno.test("revoked permissions and switched installations prevent dispatch", async () => {
  let sends = 0;
  const send: typeof fetch = () => {
    sends++;
    return Promise.resolve(new Response("{}"));
  };
  const blocked = new Store();
  blocked.blocked = true;
  await dispatchEvent(blocked, event, "test-only-authorization", send);
  const switched = new Store();
  switched.switchDuringDispatch = true;
  await dispatchEvent(switched, event, "test-only-authorization", send);
  if (sends) throw new Error("Revoked recipient received a dispatch");
});
Deno.test("invalid FIDs are removed instead of retried indefinitely", async () => {
  const store = new Store();
  const send: typeof fetch = () =>
    Promise.resolve(
      Response.json({ error: { details: [{ errorCode: "UNREGISTERED" }] } }, {
        status: 404,
      }),
    );
  await dispatchEvent(store, event, "test-only-authorization", send);
  if (store.current.length || store.completed !== 1) {
    throw new Error("Invalid registration was not cleaned up");
  }
});
