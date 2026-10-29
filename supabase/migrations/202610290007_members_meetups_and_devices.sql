create function public.circle_people(circle uuid) returns table(user_id uuid,display_name text,accepted boolean) language sql stable security definer set search_path='' as $$
 select m.user_id,p.display_name,m.accepted from public.circle_members m join public.profiles p on p.id=m.user_id
 where m.circle_id=circle and private.member(circle,auth.uid()) and not private.blocked(p.id,auth.uid()) order by p.display_name limit 100; $$;
create function public.meetup_people(meetup uuid) returns table(user_id uuid,display_name text,status text) language sql stable security definer set search_path='' as $$
 select g.user_id,p.display_name,g.status from public.meetup_guests g join public.profiles p on p.id=g.user_id join public.meetups m on m.id=g.meetup_id
 where m.id=meetup and not private.blocked(m.owner,auth.uid()) and not private.blocked(p.id,auth.uid())
 and(m.owner=auth.uid() or exists(select 1 from public.meetup_guests me where me.meetup_id=m.id and me.user_id=auth.uid()))
 order by p.display_name limit 100; $$;
create or replace function public.meetup_status(meetup uuid,new_status text) returns void language plpgsql security definer set search_path='' as $$ begin
 if new_status not in('Papunta na','Nandito na') or not exists(select 1 from public.meetups m where m.id=meetup and m.expires_at>now()
 and not private.blocked(m.owner,auth.uid()) and(m.owner=auth.uid() or exists(select 1 from public.meetup_guests g where g.meetup_id=m.id and g.user_id=auth.uid()))) then raise exception 'Meet-up unavailable'; end if;
 insert into public.meetup_guests(meetup_id,user_id,status) values(meetup,auth.uid(),new_status)
 on conflict(meetup_id,user_id) do update set status=excluded.status; end $$;

-- Possession of an unguessable FCM registration identifies the installation;
-- switching accounts transfers that registration instead of notifying both.
create function public.register_device(installation_id uuid,registration text,device_platform text) returns void language plpgsql security definer set search_path='' as $$ begin
 if auth.uid() is null or installation_id is null or length(registration) not between 10 and 4096 or device_platform not in('android','iOS','macOS','windows','linux','fuchsia') then raise exception 'Invalid registration'; end if;
 delete from public.devices where installation=installation_id or token=registration;
 insert into public.devices(owner,installation,token,platform) values(auth.uid(),installation_id,registration,device_platform);
 end $$;
revoke execute on function public.circle_people(uuid),public.meetup_people(uuid),public.register_device(uuid,text,text) from public,anon;
grant execute on function public.circle_people(uuid),public.meetup_people(uuid),public.register_device(uuid,text,text) to authenticated;
revoke insert,update on public.devices from authenticated;

create function private.profile_activity_guard() returns trigger language plpgsql set search_path='' as $$ begin
 if current_user='authenticated' then
 if tg_op='INSERT' then new.last_active:=null; else new.last_active:=old.last_active; end if;
 end if; return new; end $$;
create trigger guard_profile_activity before insert or update on public.profiles for each row execute function private.profile_activity_guard();
