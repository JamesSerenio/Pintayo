-- Preserve message identity/history while adding account-local hiding and tombstones.
alter table public.messages add column reply_to uuid references public.messages(id),
 add column forwarded boolean not null default false,
 add column deleted_at timestamptz,
 add column revision integer not null default 0;
alter table public.messages drop constraint messages_check;
alter table public.messages add constraint messages_content check (
 (deleted_at is not null and body is null and attachment is null)
 or (deleted_at is null and (coalesce(length(trim(body)),0)>0 or attachment is not null)));
create index message_attachment_path on public.messages(attachment) where attachment is not null;
create index message_replies on public.messages(reply_to) where reply_to is not null;
create table public.hidden_messages(
 message_id uuid references public.messages on delete cascade,
 owner uuid references public.profiles on delete cascade,
 conversation_id uuid not null references public.conversations,
 hidden_at timestamptz not null default now(), primary key(message_id,owner));
create index hidden_chat on public.hidden_messages(owner,conversation_id);
alter table public.hidden_messages enable row level security;
revoke all on public.hidden_messages from public,anon,authenticated;
grant select on public.hidden_messages to authenticated;
create policy hidden_own on public.hidden_messages for select to authenticated using(owner=auth.uid());
alter publication supabase_realtime add table public.hidden_messages;

create function private.message_visible(message uuid,viewer uuid) returns boolean
 language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.messages m where m.id=message
 and private.in_chat(m.conversation_id,viewer)
 and not exists(select 1 from public.hidden_messages h where h.message_id=m.id and h.owner=viewer)); $$;
revoke all on function private.message_visible(uuid,uuid) from public,anon;
grant execute on function private.message_visible(uuid,uuid) to authenticated;
drop policy message_read on public.messages;
create policy message_read on public.messages for select to authenticated using(private.message_visible(id,auth.uid()));
drop policy reaction_read on public.message_reactions;
create policy reaction_read on public.message_reactions for select to authenticated using(
 private.message_visible(message_id,auth.uid()) and exists(select 1 from public.messages m where m.id=message_id and m.deleted_at is null));

create table public.attachment_cleanup(
 path text primary key, message_id uuid references public.messages,
 requested_at timestamptz not null default now());
create table public.message_forward_jobs(
 id uuid primary key, owner uuid not null references public.profiles,
 source_id uuid not null references public.messages,
 destination uuid not null references public.conversations,
 attachment text, created_at timestamptz not null default now());
create index forward_jobs_created on public.message_forward_jobs(created_at) where attachment is not null;
alter table public.attachment_cleanup enable row level security;
alter table public.message_forward_jobs enable row level security;
revoke all on public.attachment_cleanup,public.message_forward_jobs from public,anon,authenticated;
grant select,delete on public.attachment_cleanup to service_role;

create function public.hide_message(message_id uuid) returns void language plpgsql security definer set search_path='' as $$
 declare c uuid; begin
 select m.conversation_id into c from public.messages m where m.id=message_id and private.in_chat(m.conversation_id,auth.uid());
 if c is null then raise exception 'Message unavailable'; end if;
 insert into public.hidden_messages values(message_id,auth.uid(),c,now()) on conflict do nothing;
 end $$;
create function public.delete_message_everyone(message_id uuid) returns void language plpgsql security definer set search_path='' as $$
 declare m public.messages; begin
 select * into m from public.messages x where x.id=message_id for update;
 if m.id is null or m.sender<>auth.uid() or auth.uid() is null then raise exception 'Only the sender can delete this message'; end if;
 if m.deleted_at is not null then return; end if;
 update public.messages set body=null,attachment=null,deleted_at=now(),revision=revision+1 where id=m.id;
 delete from public.message_reactions r where r.message_id=m.id;
 if m.attachment is not null and not exists(select 1 from public.messages x where x.attachment=m.attachment and x.deleted_at is null) then
 insert into public.attachment_cleanup(path,message_id) values(m.attachment,m.id) on conflict do nothing; end if;
 end $$;

create function public.send_chat_message(message_id uuid,chat uuid,body_text text default null,photo text default null,reply_to uuid default null)
 returns public.messages language plpgsql security definer set search_path='' as $$
 declare u uuid:=auth.uid(); c public.conversations; m public.messages; target public.messages; r uuid;
 begin
 perform pg_advisory_xact_lock(hashtextextended(message_id::text,0));
 select * into c from public.conversations x where x.id=chat and u in(x.a,x.b);
 if c.id is null or not private.friends(c.a,c.b) then raise exception 'Conversation unavailable'; end if;
 select * into m from public.messages x where x.id=message_id;
 if m.id is not null then
 if m.sender<>u or m.conversation_id<>chat then raise exception 'Identifier conflict'; end if; return m; end if;
 if reply_to is not null then
 select * into target from public.messages x where x.id=send_chat_message.reply_to for share;
 if target.id is null or target.conversation_id<>chat or target.deleted_at is not null or not private.message_visible(target.id,u) then raise exception 'Reply target unavailable'; end if;
 end if;
 if photo is not null then
 perform pg_advisory_xact_lock(hashtextextended(photo,0));
 if split_part(photo,'/',1)<>chat::text or split_part(photo,'/',2)<>u::text
 or not exists(select 1 from storage.objects o where o.bucket_id='attachments' and o.name=photo)
 or exists(select 1 from public.attachment_cleanup q where q.path=photo)
 or exists(select 1 from public.message_forward_jobs j where j.attachment=photo)
 or exists(select 1 from public.messages x where x.attachment=photo)
 then raise exception 'Invalid attachment'; end if;
 end if;
 insert into public.messages(id,conversation_id,sender,body,attachment,reply_to)
 values(message_id,chat,u,body_text,photo,reply_to) returning * into m;
 r:=case when c.a=u then c.b else c.a end;
 insert into public.notifications(recipient,kind,entity_id) values(r,'message',m.id) on conflict do nothing;
 return m;
 end $$;
-- Retain older clients without a permissive bypass around new validations.
create or replace function public.send_message(message_id uuid,chat uuid,body_text text default null,photo text default null)
 returns public.messages language sql security definer set search_path='' as $$
 select public.send_chat_message(message_id,chat,body_text,photo,null); $$;

create function public.prepare_message_forward(request_id uuid,source_message uuid,destination_chat uuid) returns jsonb
 language plpgsql security definer set search_path='' as $$
 declare m public.messages; c public.conversations; j public.message_forward_jobs; p text; existing public.messages;
 begin
 -- Serialize retries of the same operation before storage copying begins.
 perform pg_advisory_xact_lock(hashtextextended(request_id::text,0));
 select * into j from public.message_forward_jobs where id=request_id for update;
 if j.id is not null and (j.owner<>auth.uid() or j.source_id<>source_message or j.destination<>destination_chat) then raise exception 'Identifier conflict'; end if;
 select * into existing from public.messages where id=request_id;
 if existing.id is not null then
 if j.id is null or existing.sender<>auth.uid() then raise exception 'Identifier conflict'; end if;
 return jsonb_build_object('complete',true); end if;
 if j.id is not null and j.created_at<now()-interval '1 hour' then raise exception 'Forward request expired; reopen the picker to retry'; end if;
 select * into m from public.messages where id=source_message for share;
 if m.id is null or m.deleted_at is not null or not private.message_visible(m.id,auth.uid()) then raise exception 'Source message unavailable'; end if;
 if not exists(select 1 from public.conversations x where x.id=m.conversation_id and private.friends(x.a,x.b)) then raise exception 'Source conversation unavailable'; end if;
 select * into c from public.conversations x where x.id=destination_chat and auth.uid() in(x.a,x.b);
 if c.id is null or not private.friends(c.a,c.b) then raise exception 'Destination unavailable'; end if;
 p:=case when m.attachment is not null then destination_chat::text||'/'||auth.uid()::text||'/'||request_id::text||'.jpg' end;
 insert into public.message_forward_jobs(id,owner,source_id,destination,attachment)
 values(request_id,auth.uid(),source_message,destination_chat,p) on conflict do nothing;
 return jsonb_build_object('complete',false,'source_path',m.attachment,'destination_path',p,
 'copied',false);
 end $$;

-- Only the trusted worker may finalize a forward, after copying through Storage.
create function public.finish_message_forward(request_id uuid,acting_user uuid) returns void
 language plpgsql security definer set search_path='' as $$
 declare j public.message_forward_jobs; m public.messages; c public.conversations; existing public.messages; r uuid;
 begin
 perform pg_advisory_xact_lock(hashtextextended(request_id::text,0));
 select * into j from public.message_forward_jobs where id=request_id for update;
 if j.id is null or j.owner<>acting_user then raise exception 'Forward unavailable'; end if;
 select * into existing from public.messages where id=request_id;
 if existing.id is not null then return; end if;
 if j.created_at<now()-interval '1 hour' then raise exception 'Forward request expired'; end if;
 select * into m from public.messages where id=j.source_id for share;
 if m.deleted_at is not null or not private.message_visible(m.id,acting_user)
 or not exists(select 1 from public.conversations x where x.id=m.conversation_id and private.friends(x.a,x.b)) then raise exception 'Source message unavailable'; end if;
 select * into c from public.conversations x where x.id=j.destination and acting_user in(x.a,x.b);
 if c.id is null or not private.friends(c.a,c.b) then raise exception 'Destination unavailable'; end if;
 if j.attachment is not null and not exists(select 1 from storage.objects o where o.bucket_id='attachments' and o.name=j.attachment) then raise exception 'Attachment copy unavailable'; end if;
 insert into public.messages(id,conversation_id,sender,body,attachment,forwarded)
 values(j.id,j.destination,acting_user,m.body,j.attachment,true);
 r:=case when c.a=acting_user then c.b else c.a end;
 insert into public.notifications(recipient,kind,entity_id) values(r,'message',j.id) on conflict do nothing;
 end $$;
revoke all on function public.finish_message_forward(uuid,uuid) from public,anon,authenticated;
grant execute on function public.finish_message_forward(uuid,uuid) to service_role;

create or replace function public.message_page(chat uuid,before_time timestamptz default null,before_id uuid default null)
 returns setof public.messages language sql stable security definer set search_path='' as $$
 select m.* from public.messages m where m.conversation_id=chat and private.message_visible(m.id,auth.uid())
 and(before_time is null or(m.created_at,m.id)<(before_time,before_id)) order by m.created_at desc,m.id desc limit 40; $$;
create or replace function public.messages_since(chat uuid,since_time timestamptz,since_id uuid)
 returns setof public.messages language sql stable security definer set search_path='' as $$
 select m.* from public.messages m where m.conversation_id=chat and private.message_visible(m.id,auth.uid())
 and(m.created_at,m.id)>(since_time,since_id) order by m.created_at,m.id limit 200; $$;
create or replace function public.message_receipts(chat uuid,message_ids uuid[]) returns setof public.messages
 language sql stable security definer set search_path='' as $$
 select m.* from public.messages m where m.conversation_id=chat and m.id=any(message_ids) and private.message_visible(m.id,auth.uid()) limit 500; $$;
create or replace function public.chat_summaries() returns table(id uuid,friend_id uuid,preview text,last_message_at timestamptz,unread bigint)
 language sql stable security definer set search_path='' as $$
 select c.id,case when c.a=auth.uid() then c.b else c.a end,
 coalesce(case when m.deleted_at is not null then case when m.sender=auth.uid() then 'You deleted a message' else 'This message was deleted' end
 else coalesce(m.body,case when m.attachment is not null then 'Photo' end) end,'Say hello'),m.created_at,
 (select count(*) from public.messages x where x.conversation_id=c.id and x.sender<>auth.uid() and x.seen_at is null and x.deleted_at is null and private.message_visible(x.id,auth.uid()))
 from public.conversations c left join lateral(select x.* from public.messages x where x.conversation_id=c.id
 and private.message_visible(x.id,auth.uid()) order by x.created_at desc,x.id desc limit 1)m on true
 where auth.uid() in(c.a,c.b) order by m.created_at desc nulls last limit 100; $$;
create function public.search_chat_messages(chat uuid,query text) returns setof public.messages
 language sql stable security definer set search_path='' as $$
 select m.* from public.messages m where m.conversation_id=chat and private.message_visible(m.id,auth.uid())
 and m.deleted_at is null and length(trim(query))>=2 and m.body ilike '%'||query||'%'
 order by m.created_at desc,m.id desc limit 100; $$;

-- Existing historical reactions migrate to the exact six-value palette.
alter table public.message_reactions drop constraint message_reactions_emoji_check;
update public.message_reactions set emoji='😆' where emoji='😂';
update public.message_reactions set emoji='😠' where emoji='😡';
alter table public.message_reactions add constraint message_reactions_emoji_check check(emoji in('❤️','😆','😮','😢','😠','👍'));

create or replace function public.react_to_message(message_id uuid,reaction text default null)
 returns void language plpgsql security definer set search_path='' as $$
 declare m public.messages; c public.conversations; begin
 select * into m from public.messages x where x.id=message_id for share;
 select * into c from public.conversations where id=m.conversation_id;
 if m.id is null or m.deleted_at is not null or not private.message_visible(m.id,auth.uid()) or not private.friends(c.a,c.b) then raise exception 'Not allowed'; end if;
 if reaction is null then delete from public.message_reactions r where r.message_id=m.id and r.owner=auth.uid();
 else insert into public.message_reactions values(m.id,auth.uid(),m.conversation_id,reaction)
 on conflict on constraint message_reactions_pkey do update set emoji=excluded.emoji; end if;
 end $$;

create function private.can_read_attachment(object_name text) returns boolean
 language sql stable security definer set search_path='' as $$
 select auth.uid() is not null and (
 exists(select 1 from public.messages m where m.attachment=object_name and m.deleted_at is null and private.message_visible(m.id,auth.uid()))
 or (split_part(object_name,'/',2)=auth.uid()::text
 and exists(select 1 from public.conversations c where c.id::text=split_part(object_name,'/',1) and auth.uid() in(c.a,c.b) and private.friends(c.a,c.b))
 and not exists(select 1 from public.messages m where m.attachment=object_name)
 and not exists(select 1 from public.attachment_cleanup q where q.path=object_name)
 and not exists(select 1 from public.message_forward_jobs j where j.attachment=object_name))); $$;
revoke all on function private.can_read_attachment(text) from public,anon;
grant execute on function private.can_read_attachment(text) to authenticated;
drop policy attachment_read on storage.objects;
create policy attachment_read on storage.objects for select to authenticated using(bucket_id='attachments' and private.can_read_attachment(name));
drop policy attachment_insert on storage.objects;
create function private.can_upload_attachment(object_name text) returns boolean language sql stable security definer set search_path='' as $$
 select auth.uid() is not null and split_part(object_name,'/',2)=auth.uid()::text
 and exists(select 1 from public.conversations c where c.id::text=split_part(object_name,'/',1) and auth.uid() in(c.a,c.b) and private.friends(c.a,c.b))
 and not exists(select 1 from public.attachment_cleanup q where q.path=object_name)
 and not exists(select 1 from public.message_forward_jobs j where j.attachment=object_name); $$;
revoke all on function private.can_upload_attachment(text) from public,anon;
grant execute on function private.can_upload_attachment(text) to authenticated;
create policy attachment_insert on storage.objects for insert to authenticated with check(bucket_id='attachments' and private.can_upload_attachment(name));

create function public.attachment_cleanup_batch() returns setof public.attachment_cleanup
 language plpgsql security definer set search_path='' as $$ declare job public.message_forward_jobs; begin
 for job in select j.* from public.message_forward_jobs j where j.attachment is not null and j.created_at<now()-interval '1 hour'
 and not exists(select 1 from public.messages m where m.id=j.id) for update skip locked loop
   if not exists(select 1 from public.messages m where m.id=job.id) then
     insert into public.attachment_cleanup(path) values(job.attachment) on conflict do nothing;
   end if;
 end loop;
 return query select q.* from public.attachment_cleanup q where not exists(select 1 from public.messages m where m.attachment=q.path and m.deleted_at is null) order by q.requested_at limit 50;
 end $$;
revoke all on function public.attachment_cleanup_batch() from public,anon,authenticated;
grant execute on function public.attachment_cleanup_batch() to service_role;
revoke all on function public.hide_message(uuid),public.delete_message_everyone(uuid),public.send_chat_message(uuid,uuid,text,text,uuid),public.prepare_message_forward(uuid,uuid,uuid),public.search_chat_messages(uuid,text) from public,anon;
grant execute on function public.hide_message(uuid),public.delete_message_everyone(uuid),public.send_chat_message(uuid,uuid,text,text,uuid),public.prepare_message_forward(uuid,uuid,uuid),public.search_chat_messages(uuid,text) to authenticated;
