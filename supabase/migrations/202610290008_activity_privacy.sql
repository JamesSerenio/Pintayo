-- Presence channels are private to the user's own devices. Cross-user activity
-- and typing use per-event RLS, so another device's stale preference cannot leak
-- new activity after the server visibility preference changes.
create table public.activity_sessions(
 owner uuid not null references public.profiles, connection uuid not null,
 expires_at timestamptz not null, typing_chat uuid references public.conversations,
 typing_until timestamptz, primary key(owner,connection)
);
alter table public.activity_sessions enable row level security;
revoke all on public.activity_sessions from anon,authenticated;
grant select on public.activity_sessions to authenticated;
create policy activity_read on public.activity_sessions for select to authenticated using(
 owner=auth.uid() or(private.friends(owner,auth.uid()) and exists(select 1 from public.profiles p where p.id=owner and not p.hide_activity)));
-- Avoid profile self-RLS inside activity policy with a restricted definer helper.
create function private.activity_visible(person uuid) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.profiles where id=person and not hide_activity); $$;
revoke execute on function private.activity_visible(uuid) from public,anon;
grant execute on function private.activity_visible(uuid) to authenticated;
drop policy activity_read on public.activity_sessions;
create policy activity_read on public.activity_sessions for select to authenticated using(
 owner=auth.uid() or(private.friends(owner,auth.uid()) and private.activity_visible(owner)));

create function public.activity_tick(connection_id uuid,foreground boolean,chat uuid default null,is_typing boolean default false) returns void language plpgsql security definer set search_path='' as $$ begin
 if auth.uid() is null or connection_id is null then raise exception 'Sign in required'; end if;
 if not foreground then
 delete from public.activity_sessions where owner=auth.uid() and connection=connection_id;
 update public.profiles set last_active=now() where id=auth.uid(); return; end if;
 if chat is not null and not exists(select 1 from public.conversations where id=chat and auth.uid() in(a,b) and private.friends(a,b)) then raise exception 'Conversation unavailable'; end if;
 insert into public.activity_sessions values(auth.uid(),connection_id,now()+interval '75 seconds',
 case when is_typing and private.activity_visible(auth.uid()) then chat end,
 case when is_typing and private.activity_visible(auth.uid()) then now()+interval '5 seconds' end)
 on conflict(owner,connection) do update set expires_at=excluded.expires_at,typing_chat=excluded.typing_chat,typing_until=excluded.typing_until;
 update public.profiles set last_active=now() where id=auth.uid();
 delete from public.activity_sessions where expires_at<now()-interval '5 minutes';
 end $$;
create or replace function public.chat_activity(chat uuid) returns jsonb language sql stable security definer set search_path='' as $$
 select jsonb_build_object('hidden',p.hide_activity,'last_active',case when not p.hide_activity then p.last_active end,
 'active',not p.hide_activity and exists(select 1 from public.activity_sessions s where s.owner=p.id and s.expires_at>now()),
 'typing',not p.hide_activity and exists(select 1 from public.activity_sessions s where s.owner=p.id and s.expires_at>now() and s.typing_chat=c.id and s.typing_until>now()))
 from public.conversations c join public.profiles p on p.id=case when c.a=auth.uid() then c.b else c.a end
 where c.id=chat and auth.uid() in(c.a,c.b) and private.friends(c.a,c.b); $$;
revoke execute on function public.activity_tick(uuid,boolean,uuid,boolean) from public,anon;
grant execute on function public.activity_tick(uuid,boolean,uuid,boolean) to authenticated;
create policy self_presence_read on realtime.messages for select to authenticated using(realtime.topic()='presence:'||auth.uid()::text);
create policy self_presence_write on realtime.messages for insert to authenticated with check(realtime.topic()='presence:'||auth.uid()::text);
alter publication supabase_realtime add table public.activity_sessions;
