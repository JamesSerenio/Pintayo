create function public.chat_activity(chat uuid) returns jsonb language sql stable security definer set search_path='' as $$
 select jsonb_build_object('hidden',p.hide_activity,'last_active',case when not p.hide_activity then p.last_active end)
 from public.conversations c join public.profiles p on p.id=case when c.a=auth.uid() then c.b else c.a end
 where c.id=chat and auth.uid() in(c.a,c.b) and private.friends(c.a,c.b); $$;
revoke execute on function public.chat_activity(uuid) from public,anon;
grant execute on function public.chat_activity(uuid) to authenticated;

-- Circle recipients may see the minimal identity of the location owner without
-- gaining access to private profile fields or activity information.
create or replace function public.person(person_id uuid) returns jsonb language sql stable security definer set search_path='' as $$
 select jsonb_build_object('id',id,'username',username,'display_name',display_name,'avatar_path',avatar_path,
 'last_active',case when not hide_activity and private.friends(id,auth.uid()) then last_active end,
 'hide_activity',hide_activity or not private.friends(id,auth.uid()))
 from public.profiles where auth.uid() is not null and(id=auth.uid() or private.friends(id,auth.uid())
 or private.can_locate(id,auth.uid()) or exists(select 1 from public.friendships where auth.uid() in(requester,recipient) and id in(requester,recipient))
 or exists(select 1 from public.conversations where auth.uid() in(a,b) and id in(a,b))); $$;
