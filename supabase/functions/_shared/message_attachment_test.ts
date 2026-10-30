import type { SupabaseClient } from "@supabase/supabase-js";
import { copyForwardedAttachment } from "./message_attachment_copy.ts";
import { cleanupAttachments } from "./attachment_cleanup.ts";

Deno.test("forward retries accept identical independent objects and reject conflicting uploads", async () => {
  let conflict = false;
  const client = {
    storage: {
      from: () => ({
        copy: () => Promise.resolve({ error: { statusCode: "409" } }),
        download: (path: string) =>
          Promise.resolve({
            error: null,
            data: new Blob([
              path === "source" || !conflict
                ? "original bytes"
                : "different bytes",
            ]),
          }),
      }),
    },
  } as unknown as SupabaseClient;
  await copyForwardedAttachment(client, "source", "independent-copy");
  conflict = true;
  let rejected = false;
  try {
    await copyForwardedAttachment(client, "source", "independent-copy");
  } catch (_) {
    rejected = true;
  }
  if (!rejected) throw new Error("Conflicting upload accepted");
});

Deno.test("failed Storage removals remain queued and successful retries acknowledge only the queue", async () => {
  let failing = true;
  let acknowledged = false;
  const client = {
    rpc: () => Promise.resolve({ data: [{ path: "original" }], error: null }),
    storage: {
      from: (bucket: string) => {
        if (bucket !== "attachments") throw new Error("Wrong bucket");
        return {
          remove: (paths: string[]) => {
            if (paths.join() !== "original") throw new Error("Wrong object");
            return Promise.resolve({
              error: failing ? new Error("Unavailable") : null,
            });
          },
        };
      },
    },
    from: (table: string) => {
      if (table !== "attachment_cleanup") {
        throw new Error("SQL must not delete Storage metadata");
      }
      return {
        delete: () => ({
          eq: () => {
            acknowledged = true;
            return Promise.resolve({ error: null });
          },
        }),
      };
    },
  } as unknown as SupabaseClient;
  if (await cleanupAttachments(client) !== 0 || acknowledged) {
    throw new Error("Failed removal lost queue entry");
  }
  failing = false;
  if (await cleanupAttachments(client) !== 1 || !acknowledged) {
    throw new Error("Retry did not complete");
  }
});
