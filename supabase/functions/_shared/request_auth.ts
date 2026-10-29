// The scheduler uses a dedicated server secret, never a publishable key or a
// client-selected sender/recipient. Constant-time comparison avoids early exits.
export async function authorized(request: Request): Promise<boolean> {
  const expected = Deno.env.get("PUSH_WORKER_SECRET");
  const supplied = request.headers.get("x-worker-secret");
  if (!expected || !supplied) return false;
  const digest = async (value: string) =>
    new Uint8Array(
      await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value)),
    );
  const [a, b] = await Promise.all([digest(expected), digest(supplied)]);
  return a.reduce((difference, value, i) => difference | (value ^ b[i]), 0) ===
    0;
}
