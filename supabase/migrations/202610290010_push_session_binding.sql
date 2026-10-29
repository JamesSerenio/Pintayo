-- Tie a registration to a real, active Auth session, not merely a still-valid
-- JWT. A removed/revoked session can no longer receive future push dispatches.
alter table public.devices add column session_id uuid references auth.sessions(id) on delete cascade;
alter table public.devices add column generation uuid not null default gen_random_uuid();
create index devices_session on public.devices(session_id);

create function public.register_push_device(expected_user uuid,installation_id uuid,registration text,device_platform text)
returns void language plpgsql security definer set search_path='' as $$
 declare u uuid:=auth.uid(); sid uuid:=nullif(auth.jwt()->>'session_id','')::uuid; begin
 if u is null or expected_user is distinct from u then raise exception 'Account changed. Try again.'; end if;
 if sid is null or not exists(select 1 from auth.sessions s where s.id=sid and s.user_id=u and(s.not_after is null or s.not_after>now())) then raise exception 'Sign in again to enable notifications.'; end if;
 perform public.register_device(installation_id,registration,device_platform);
 update public.devices set session_id=sid,generation=gen_random_uuid() where owner=u and installation=installation_id;
 end $$;
revoke execute on function public.register_push_device(uuid,uuid,text,text) from public,anon;
grant execute on function public.register_push_device(uuid,uuid,text,text) to authenticated;

create function public.push_devices(event_id uuid) returns table(installation uuid,token text,generation uuid)
language sql stable security definer set search_path='' as $$
 select d.installation,d.token,d.generation from public.notifications n join public.devices d on d.owner=n.recipient
 join auth.sessions s on s.id=d.session_id and s.user_id=d.owner
 where n.id=event_id and(s.not_after is null or s.not_after>now()) and public.push_payload(n.id) is not null limit 20; $$;
revoke execute on function public.push_devices(uuid) from public,anon,authenticated;
grant execute on function public.push_devices(uuid) to service_role;

-- Existing, unbound registrations are excluded until the application registers
-- again. Existing messages are untouched if notification delivery fails.
