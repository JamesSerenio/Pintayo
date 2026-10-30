// No user session, keys, returned rows or private data are printed.
import { readFile } from 'node:fs/promises';
const config = JSON.parse(await readFile('config/app_config.json', 'utf8'));
for (const path of ['/functions/v1/message-actions', '/rest/v1/rpc/delete_message_everyone']) {
  const response = await fetch(config.SUPABASE_URL + path, {
    method: 'POST',
    headers: { apikey: config.SUPABASE_PUBLISHABLE_KEY, 'Content-Type': 'application/json' },
    body: JSON.stringify(path.includes('/rpc/') ? { message_id: '00000000-0000-4000-8000-000000000000' } : {}),
    signal: AbortSignal.timeout(15000),
  });
  const data = await response.json().catch(() => ({}));
  console.log(JSON.stringify({ endpoint: path, status: response.status, code: data.code ?? null }));
}
