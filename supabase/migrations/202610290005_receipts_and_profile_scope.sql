create or replace function public.person(person_id uuid) returns jsonb language sql stable security definer set search_path='' as $$
 select jsonb_build_object('id',p.id,'username',p.username,'display_name',p.display_name,'avatar_path',p.avatar_path,
 'last_active',case when not p.hide_activity and private.friends(p.id,auth.uid()) then p.last_active end,
 'hide_activity',p.hide_activity or not private.friends(p.id,auth.uid()))
 from public.profiles p where p.id=person_id and auth.uid() is not null and not private.blocked(p.id,auth.uid()) and
 (p.id=auth.uid() or private.friends(p.id,auth.uid()) or private.can_locate(p.id,auth.uid())
 or exists(select 1 from public.friendships f where auth.uid() in(f.requester,f.recipient) and p.id in(f.requester,f.recipient))
 or exists(select 1 from public.conversations c where auth.uid() in(c.a,c.b) and p.id in(c.a,c.b))); $$;

create function public.ack_received(chat uuid,message_ids uuid[],seen boolean default false) returns void language plpgsql security definer set search_path='' as $$ begin
 if not private.in_chat(chat,auth.uid()) or cardinality(message_ids)>500 then raise exception 'Not allowed'; end if;
 update public.messages set delivered_at=coalesce(delivered_at,now()),
 seen_at=case when seen then coalesce(seen_at,now()) else seen_at end
 where conversation_id=chat and id=any(message_ids) and sender<>auth.uid()
 and(delivered_at is null or(seen and seen_at is null)); end $$;
revoke execute on function public.ack_messages(uuid,boolean) from authenticated;
revoke execute on function public.ack_received(uuid,uuid[],boolean) from public,anon;
grant execute on function public.ack_received(uuid,uuid[],boolean) to authenticated;

-- Scoped receipt refresh for messages already loaded before disconnection.
create function public.message_receipts(chat uuid,message_ids uuid[]) returns setof public.messages language sql stable security definer set search_path='' as $$
 select * from public.messages where conversation_id=chat and id=any(message_ids) and private.in_chat(chat,auth.uid()) limit 500; $$;
revoke execute on function public.message_receipts(uuid,uuid[]) from public,anon;
grant execute on function public.message_receipts(uuid,uuid[]) to authenticated;
