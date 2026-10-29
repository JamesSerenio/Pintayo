import { fcmEndpoint, pushMessage } from "./fcm_client.ts";

export interface PushEvent {
  id: string;
  kind: string;
  recipient: string;
}
export interface PushDevice {
  installation: string;
  token: string;
  generation: string;
}
// Deliberately no message-update API: push failure cannot undo a saved message
// or claim delivered/seen. Those receipts belong exclusively to recipient apps.
export interface PushDispatchStore {
  payload(event: string): Promise<{ conversation_id?: string } | null>;
  devices(event: string): Promise<PushDevice[]>;
  accepted(event: string, installation: string): Promise<boolean>;
  accept(event: string, installation: string): Promise<void>;
  invalidate(recipient: string, device: PushDevice): Promise<void>;
  complete(event: string): Promise<void>;
}
export async function dispatchEvent(
  store: PushDispatchStore,
  event: PushEvent,
  authorization: string,
  send: typeof fetch = fetch,
): Promise<boolean> {
  const payload = await store.payload(event.id);
  if (!payload) {
    await store.complete(event.id);
    return true;
  }
  let complete = true;
  for (const device of await store.devices(event.id)) {
    if (await store.accepted(event.id, device.installation)) continue;
    const current = await store.devices(event.id);
    if (
      !current.some((d) =>
        d.installation === device.installation &&
        d.generation === device.generation
      )
    ) continue;
    const response = await send(fcmEndpoint, {
      method: "POST",
      signal: AbortSignal.timeout(15000),
      headers: {
        Authorization: `Bearer ${authorization}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        message: pushMessage(event, device.token, payload.conversation_id),
      }),
    });
    if (response.ok) await store.accept(event.id, device.installation);
    else {
      const failure = await response.json().catch(() => ({}));
      if (
        failure.error?.details?.some((detail: { errorCode?: string }) =>
          detail.errorCode === "UNREGISTERED"
        )
      ) {
        await store.invalidate(event.recipient, device);
      } else complete = false;
    }
  }
  if (complete) await store.complete(event.id);
  return complete;
}
