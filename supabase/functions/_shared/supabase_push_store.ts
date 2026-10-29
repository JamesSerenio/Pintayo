import type { SupabaseClient } from "@supabase/supabase-js";
import type { PushDevice, PushDispatchStore } from "./push_dispatcher.ts";

export class SupabasePushStore implements PushDispatchStore {
  constructor(private db: SupabaseClient) {}
  async payload(event: string) {
    const { data, error } = await this.db.rpc("push_payload", {
      event_id: event,
    });
    if (error) throw error;
    return data;
  }
  async devices(event: string): Promise<PushDevice[]> {
    const { data, error } = await this.db.rpc("push_devices", {
      event_id: event,
    });
    if (error) throw error;
    return data ?? [];
  }
  async accepted(event: string, installation: string) {
    const { data, error } = await this.db.from("push_deliveries").select(
      "event_id",
    )
      .eq("event_id", event).eq("installation", installation).maybeSingle();
    if (error) throw error;
    return data != null;
  }
  async accept(event: string, installation: string) {
    const { error } = await this.db.from("push_deliveries").upsert({
      event_id: event,
      installation,
    });
    if (error) throw error;
  }
  async invalidate(recipient: string, device: PushDevice) {
    const { error } = await this.db.from("devices").delete().eq(
      "owner",
      recipient,
    )
      .eq("installation", device.installation).eq(
        "generation",
        device.generation,
      );
    if (error) throw error;
  }
  async complete(event: string) {
    const { error } = await this.db.from("notifications").update({
      dispatched_at: new Date().toISOString(),
    }).eq("id", event);
    if (error) throw error;
  }
}
