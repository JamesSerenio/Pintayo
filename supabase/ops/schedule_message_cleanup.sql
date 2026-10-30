-- Optional scheduled retry for queued attachment removals. Apply once after
-- deploying message-actions. Reuses the dedicated worker secret kept in Vault.
-- No client key or private service-account value belongs in this SQL file.
select cron.schedule('pintayo-message-attachment-cleanup','*/5 * * * *', $$
 select net.http_post(
  url:=(select decrypted_secret from vault.decrypted_secrets where name='pintayo_project_url')||'/functions/v1/message-actions',
  headers:=jsonb_build_object('Content-Type','application/json','x-worker-secret',
   (select decrypted_secret from vault.decrypted_secrets where name='pintayo_push_worker_secret')),
  body:='{}'::jsonb
 );
$$);
