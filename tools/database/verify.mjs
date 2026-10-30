// Executes actual migrations and PostgreSQL/RLS assertions without credentials.
// PGlite does NOT emulate Supabase Realtime, Storage HTTP, Auth, or FCM.
import { PGlite } from '@electric-sql/pglite';
import { readFile, readdir } from 'node:fs/promises';
const db = new PGlite();
try {
await db.exec(`
  create role anon; create role authenticated; create role service_role bypassrls;
  create schema auth; create schema storage; create schema realtime;
  create table auth.users(id uuid primary key,email text);
  create table auth.sessions(id uuid primary key,user_id uuid references auth.users,not_after timestamptz);
  create function auth.uid() returns uuid language sql stable as $$ select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
  create function auth.jwt() returns jsonb language sql stable as $$ select coalesce(nullif(current_setting('request.jwt.claims',true),''),'{}')::jsonb $$;
  create table storage.buckets(id text primary key,name text,public boolean,file_size_limit bigint,allowed_mime_types text[]);
  create table storage.objects(id uuid default gen_random_uuid(),bucket_id text,name text);
  alter table storage.objects enable row level security;
  create function storage.foldername(name text) returns text[] language sql immutable as $$ select string_to_array(name,'/') $$;
  create table realtime.messages(id bigint,topic text);
  alter table realtime.messages enable row level security;
  create function realtime.topic() returns text language sql stable as $$ select current_setting('realtime.topic',true) $$;
  create publication supabase_realtime;
  grant usage on schema public,auth,storage,realtime to authenticated;
  grant select,insert,delete on storage.objects to authenticated;
  grant select,insert on realtime.messages to authenticated;
`);
const directory = new URL('../../supabase/migrations/', import.meta.url);
for (const name of (await readdir(directory)).filter((f) => f.endsWith('.sql')).sort()) {
  // gen_random_uuid() is built into PostgreSQL. pgcrypto's other features are
  // unused; only its extension install is omitted in the embedded test engine.
  const sql = (await readFile(new URL(name, directory), 'utf8')).replace('create extension if not exists pgcrypto;', '');
  await db.exec(sql);
  console.log(`Applied ${name}`);
}
await db.exec(await readFile(new URL('assertions.sql', import.meta.url), 'utf8'));
await db.exec(await readFile(new URL('activity_assertions.sql', import.meta.url), 'utf8'));
await db.exec(await readFile(new URL('storage_assertions.sql', import.meta.url), 'utf8'));
await db.exec(await readFile(new URL('push_assertions.sql', import.meta.url), 'utf8'));
await db.exec(await readFile(new URL('reaction_assertions.sql', import.meta.url), 'utf8'));
console.log('PostgreSQL migration, authorization, and behavior assertions passed.');
} catch (error) {
  console.error(`Database verification failed: ${error.message}`);
  if (error.where) console.error(error.where);
  process.exitCode = 1;
} finally { await db.close(); }
