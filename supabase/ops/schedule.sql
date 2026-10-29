-- Run after deployment as the project administrator, once. Requires pg_cron,
-- pg_net and Vault. Secrets must be created in Vault first (see setup docs).
create extension if not exists pg_cron;
create extension if not exists pg_net with schema extensions;
select cron.schedule('pintayo-expire-sharing','* * * * *', $$select public.expire_sharing();$$);
select cron.schedule('pintayo-push-dispatch','* * * * *', $$
 select net.http_post(
  url:=(select decrypted_secret from vault.decrypted_secrets where name='pintayo_project_url')||'/functions/v1/send-push',
  headers:=jsonb_build_object('Content-Type','application/json','x-worker-secret',
   (select decrypted_secret from vault.decrypted_secrets where name='pintayo_push_worker_secret')),
  body:='{}'::jsonb
 );
$$);
