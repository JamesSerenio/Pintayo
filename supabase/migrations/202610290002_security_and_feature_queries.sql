-- Preserve core migration history; tighten default Supabase table privileges.
revoke all on all tables in schema public from anon,authenticated;
grant select on all tables in schema public to authenticated;
grant insert,update on public.profiles to authenticated;
grant insert,update,delete on public.devices to authenticated;
revoke all on all functions in schema private from public,anon;
grant execute on all functions in schema private to authenticated;

alter table public.profiles add constraint avatar_owned check(avatar_path is null or split_part(avatar_path,'/',1)=id::text);
create policy avatar_delete on storage.objects for delete to authenticated using(bucket_id='avatars' and(storage.foldername(name))[1]=auth.uid()::text);
drop policy avatar_read on storage.objects;
create policy avatar_read on storage.objects for select to authenticated using(bucket_id='avatars' and (
 (storage.foldername(name))[1]=auth.uid()::text or exists(select 1 from public.profiles p where p.avatar_path=name and not private.blocked(p.id,auth.uid()))));

create function public.my_circles() returns table(id uuid,name text,owner uuid,accepted boolean) language sql stable security definer set search_path='' as $$
 select c.id,c.name,c.owner,m.accepted from public.circles c join public.circle_members m on m.circle_id=c.id where m.user_id=auth.uid() order by c.name limit 100; $$;

create function public.chat_summaries() returns table(id uuid,friend_id uuid,preview text,last_message_at timestamptz,unread bigint) language sql stable security definer set search_path='' as $$
 select c.id,case when c.a=auth.uid() then c.b else c.a end,
 coalesce(m.body,case when m.attachment is not null then 'Photo' else 'Say hello' end),m.created_at,
 (select count(*) from public.messages u where u.conversation_id=c.id and u.sender<>auth.uid() and u.seen_at is null)
 from public.conversations c left join lateral(select body,attachment,created_at from public.messages where conversation_id=c.id order by created_at desc,id desc limit 1)m on true
 where auth.uid() in(c.a,c.b) order by m.created_at desc nulls last limit 100; $$;

-- UUID cursor resolves equal-timestamp page boundaries without dropping messages.
create function public.message_page(chat uuid,before_time timestamptz default null,before_id uuid default null) returns setof public.messages language sql stable security definer set search_path='' as $$
 select * from public.messages where conversation_id=chat and private.in_chat(chat,auth.uid())
 and(before_time is null or(created_at,id)<(before_time,before_id)) order by created_at desc,id desc limit 40; $$;
create function public.messages_since(chat uuid,since_time timestamptz,since_id uuid) returns setof public.messages language sql stable security definer set search_path='' as $$
 select * from public.messages where conversation_id=chat and private.in_chat(chat,auth.uid())
 and(created_at,id)>(since_time,since_id) order by created_at,id limit 200; $$;

-- Location expiration and cached-fix cleanup run server-side. Read RLS denies an
-- expired fix immediately even before this maintenance task runs.
create function public.expire_sharing() returns void language plpgsql security definer set search_path='' as $$ begin
 update public.sharing_sessions set state='stopped' where state<>'stopped' and expires_at<=now();
 delete from public.location_inbox where not private.can_locate(owner,recipient);
 delete from public.latest_locations l where not exists(select 1 from public.sharing_sessions s where s.owner=l.owner and s.state='active' and(s.expires_at is null or s.expires_at>now()));
 end $$;
revoke execute on function public.expire_sharing() from public,anon,authenticated;
grant execute on function public.expire_sharing() to service_role;

-- Dispatch workers claim one durable event at a time. Lease protects concurrent
-- invocations; a retry uses the same event ID for device-side deduplication.
create function public.claim_push() returns setof public.notifications language sql security definer set search_path='' as $$
 update public.notifications set lease_until=now()+interval '2 minutes',attempts=attempts+1
 where id in(select id from public.notifications where dispatched_at is null and(lease_until is null or lease_until<now()) and attempts<8 order by created_at for update skip locked limit 20) returning *; $$;
revoke execute on function public.claim_push() from public,anon,authenticated;
grant execute on function public.claim_push() to service_role;

revoke execute on function public.my_circles(),public.chat_summaries(),public.message_page(uuid,timestamptz,uuid),public.messages_since(uuid,timestamptz,uuid) from public,anon;
grant execute on function public.my_circles(),public.chat_summaries(),public.message_page(uuid,timestamptz,uuid),public.messages_since(uuid,timestamptz,uuid) to authenticated;

-- Safety: profile writes cannot counterfeit last active. activity() is the only
-- authenticated path that advances it, always using database time.
revoke update on public.profiles from authenticated;
grant update(username,first_name,last_name,display_name,avatar_path,hide_activity,onboarded) on public.profiles to authenticated;
create index inbox_owner on public.location_inbox(owner);
create index membership_user on public.circle_members(user_id);
create index notification_queue on public.notifications(created_at) where dispatched_at is null;
