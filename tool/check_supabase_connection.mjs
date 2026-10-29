// Read-only, unauthenticated probes. Never prints keys, JWTs or returned rows.
import { readFile, mkdir, writeFile } from 'node:fs/promises';
const path = process.argv[2] ?? 'config/app_config.json';
const config = JSON.parse(await readFile(path, 'utf8'));
const base = config.SUPABASE_URL;
const key = config.SUPABASE_PUBLISHABLE_KEY ?? config.SUPABASE_ANON_KEY;
if (!base || !key || key.startsWith('sb_secret_')) throw new Error('Public client configuration is required');
const probes = [
  ['auth_settings', '/auth/v1/settings'],
  ['profiles_anonymous', '/rest/v1/profiles?select=id&limit=0'],
  ['devices_anonymous', '/rest/v1/devices?select=installation&limit=0'],
  ['search_anonymous', '/rest/v1/rpc/search_people', { query: 'connection_check' }],
];
const results = [];
for (const [name, route, body] of probes) {
  try {
    const response = await fetch(new URL(route, base), {
      method: body ? 'POST' : 'GET',
      headers: { apikey: key, ...(body ? { 'Content-Type': 'application/json' } : {}) },
      ...(body ? { body: JSON.stringify(body) } : {}), signal: AbortSignal.timeout(15000),
    });
    const data = await response.json().catch(() => ({}));
    results.push({ probe: name, status: response.status, ...(data.code ? { code: data.code } : {}),
      ...(name === 'auth_settings' && response.ok ? { emailEnabled: data.external?.email === true, signupDisabled: data.disable_signup === true } : {}) });
  } catch (error) { results.push({ probe: name, networkError: error.cause?.code ?? error.name }); }
}
const report = { checkedAt: new Date().toISOString(), project: new URL(base).hostname, authenticatedUser: false, results };
await mkdir('docs/verification', { recursive: true });
await writeFile('docs/verification/supabase-public-probes.json', JSON.stringify(report, null, 2) + '\n');
console.log(JSON.stringify(report, null, 2));
