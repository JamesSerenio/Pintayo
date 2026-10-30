import type { SupabaseClient } from "@supabase/supabase-js";

// Durable queue; supported Storage API removes bytes and metadata together.
export async function cleanupAttachments(
  admin: SupabaseClient,
): Promise<number> {
  const { data, error } = await admin.rpc("attachment_cleanup_batch");
  if (error) throw error;
  let removed = 0;
  for (const item of data ?? []) {
    const result = await admin.storage.from("attachments").remove([item.path]);
    if (result.error) continue;
    const ack = await admin.from("attachment_cleanup").delete().eq(
      "path",
      item.path,
    );
    if (!ack.error) removed++;
  }
  return removed;
}
