import type { SupabaseClient } from "@supabase/supabase-js";

export async function copyForwardedAttachment(
  admin: SupabaseClient,
  sourcePath: string,
  destinationPath: string,
): Promise<void> {
  const storage = admin.storage.from("attachments");
  const copied = await storage.copy(sourcePath, destinationPath);
  if (!copied.error) return;
  // A retry can encounter a previously copied object. Never accept a different
  // pre-existing upload simply because it occupies the reserved destination.
  const [source, target] = await Promise.all([
    storage.download(sourcePath),
    storage.download(destinationPath),
  ]);
  if (source.error || target.error) throw new Error("Copy verification failed");
  const [a, b] = await Promise.all([
    source.data.arrayBuffer(),
    target.data.arrayBuffer(),
  ]);
  const [ah, bh] = await Promise.all([
    crypto.subtle.digest("SHA-256", a),
    crypto.subtle.digest("SHA-256", b),
  ]);
  const targetHash = new Uint8Array(bh);
  if (new Uint8Array(ah).some((value, i) => value !== targetHash[i])) {
    throw new Error("Copy conflict");
  }
}
