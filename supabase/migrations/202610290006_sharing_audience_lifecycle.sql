-- Circle sharing snapshots accepted members at the explicit start action.
-- Joining/rejoining a circle or re-friending never silently restores a grant.
create table private.sharing_circle_audience(
 session_id uuid references public.sharing_sessions on delete cascade,
 circle_id uuid references public.circles on delete cascade,
 recipient uuid references public.profiles,primary key(session_id,circle_id,recipient)
);
create table private.sharing_exclusions(
 session_id uuid references public.sharing_sessions on delete cascade,
 recipient uuid references public.profiles,primary key(session_id,recipient)
);
revoke all on private.sharing_circle_audience,private.sharing_exclusions from public,anon,authenticated;
-- Fail closed for existing circle sessions: the owner must explicitly restart.
create or replace function private.can_locate(o uuid,r uuid) returns boolean language sql stable security definer set search_path='' as $$
 select o=r or(not private.blocked(o,r) and exists(
 select 1 from public.sharing_sessions s join public.sharing_recipients t on t.session_id=s.id
 where s.owner=o and s.state='active' and(s.expires_at is null or s.expires_at>now())
 and not exists(select 1 from private.sharing_exclusions e where e.session_id=s.id and e.recipient=r)
 and((t.friend_id=r and private.friends(o,r))or(t.circle_id is not null
 and private.member(t.circle_id,o) and private.member(t.circle_id,r)
 and exists(select 1 from private.sharing_circle_audience a where a.session_id=s.id and a.circle_id=t.circle_id and a.recipient=r))))); $$;

create or replace function public.share_start(friends uuid[],circles uuid[],minutes integer default 15) returns uuid language plpgsql security definer set search_path='' as $$
 declare u uuid:=auth.uid(); s uuid; f uuid; c uuid; begin
 if u is null or friends is null or circles is null or minutes is null or minutes not in(0,15,60)
 or cardinality(friends)+cardinality(circles) not between 1 and 100 then raise exception 'Choose an audience and duration'; end if;
 update public.sharing_sessions set state='stopped' where owner=u and state<>'stopped';
 delete from public.location_inbox where owner=u;
 insert into public.sharing_sessions(owner,state,expires_at) values(u,'active',case when minutes=0 then null else now()+make_interval(mins=>minutes) end) returning id into s;
 foreach f in array friends loop
 if not private.friends(u,f) then raise exception 'Accepted friends only'; end if;
 insert into public.sharing_recipients(session_id,friend_id) values(s,f); end loop;
 foreach c in array circles loop
 if not private.member(c,u) then raise exception 'Accepted circles only'; end if;
 insert into public.sharing_recipients(session_id,circle_id) values(s,c);
 insert into private.sharing_circle_audience select s,c,user_id from public.circle_members where circle_id=c and accepted and user_id<>u on conflict do nothing;
 end loop; return s; end $$;

create or replace function public.friend_action(target_id uuid,action text) returns void language plpgsql security definer set search_path='' as $$
 declare u uuid:=auth.uid(); begin
 if u is null or target_id is null or target_id=u then raise exception 'Invalid friend'; end if;
 if action='block' then insert into public.blocks values(u,target_id) on conflict do nothing;
 delete from public.friendships where least(requester,recipient)=least(u,target_id) and greatest(requester,recipient)=greatest(u,target_id);
 elsif action='unblock' then delete from public.blocks where owner=u and target=target_id;
 elsif action='request' then
 if private.blocked(u,target_id) then raise exception 'Unavailable'; end if;
 insert into public.friendships(requester,recipient) values(u,target_id) on conflict do nothing;
 insert into public.notifications(recipient,kind,entity_id) select target_id,'friend_request',id from public.friendships where requester=u and recipient=target_id and status='pending' on conflict do nothing;
 elsif action='accept' then update public.friendships set status='accepted' where requester=target_id and recipient=u and not private.blocked(u,target_id);
 elsif action in('remove','decline','cancel') then delete from public.friendships where
 (action='remove' and status='accepted' and u in(requester,recipient) and target_id in(requester,recipient))or
 (action='decline' and recipient=u and requester=target_id and status='pending')or
 (action='cancel' and requester=u and recipient=target_id and status='pending');
 else raise exception 'Unknown action'; end if;
 if action in('remove','block') then
 insert into private.sharing_exclusions select id,case when owner=u then target_id else u end from public.sharing_sessions where owner in(u,target_id) and state<>'stopped' on conflict do nothing;
 end if;
 delete from public.location_inbox where(owner=u or recipient=u) and not private.can_locate(owner,recipient);
 end $$;

create or replace function public.circle_action(action text,circle uuid default null,target uuid default null,title text default null) returns uuid language plpgsql security definer set search_path='' as $$
 declare u uuid:=auth.uid(); c uuid:=circle; leaving uuid; begin
 if u is null then raise exception 'Sign in required'; end if;
 if action='create' then insert into public.circles(owner,name) values(u,title) returning id into c; insert into public.circle_members values(c,u,true);
 elsif action='invite' then
 if not exists(select 1 from public.circles where id=c and owner=u) or not private.friends(u,target) then raise exception 'Not allowed'; end if;
 insert into public.circle_members values(c,target,false) on conflict do nothing;
 elsif action='accept' then update public.circle_members set accepted=true where circle_id=c and user_id=u;
 elsif action in('leave','remove_member') then
 leaving:=case when action='leave' then u else target end;
 if action='remove_member' and(not exists(select 1 from public.circles where id=c and owner=u) or target=u) then raise exception 'Owner permission required'; end if;
 delete from private.sharing_circle_audience a where a.circle_id=c and(a.recipient=leaving or exists(select 1 from public.sharing_sessions s where s.id=a.session_id and s.owner=leaving));
 if action='leave' and exists(select 1 from public.circles where id=c and owner=u) then delete from public.circles where id=c;
 else delete from public.circle_members where circle_id=c and user_id=leaving; end if;
 else raise exception 'Unknown action'; end if;
 delete from public.location_inbox where not private.can_locate(owner,recipient); return c; end $$;

-- Build candidate recipients from explicit grants instead of scanning profiles.
create or replace function public.publish_location(lat double precision,lng double precision,accuracy_m double precision,fix_time timestamptz) returns void language plpgsql security definer set search_path='' as $$
 declare u uuid:=auth.uid(); begin
 if u is null or not exists(select 1 from public.sharing_sessions where owner=u and state='active' and(expires_at is null or expires_at>now())) then raise exception 'Sharing is off'; end if;
 if fix_time>now()+interval '30 seconds' or fix_time<now()-interval '5 minutes' then raise exception 'Stale fix'; end if;
 insert into public.latest_locations values(u,lat,lng,accuracy_m,fix_time,now()) on conflict(owner) do update set latitude=excluded.latitude,longitude=excluded.longitude,accuracy=excluded.accuracy,fixed_at=excluded.fixed_at,received_at=now() where excluded.fixed_at>public.latest_locations.fixed_at;
 if not found then return; end if;
 delete from public.location_inbox where owner=u and not private.can_locate(u,recipient);
 insert into public.location_inbox
 select distinct candidate.recipient,u,lat,lng,accuracy_m,fix_time from (
 select t.friend_id recipient from public.sharing_recipients t join public.sharing_sessions s on s.id=t.session_id where s.owner=u and s.state='active' and t.friend_id is not null
 union select a.recipient from private.sharing_circle_audience a join public.sharing_sessions s on s.id=a.session_id where s.owner=u and s.state='active'
 )candidate where candidate.recipient<>u and private.can_locate(u,candidate.recipient)
 on conflict(recipient,owner) do update set latitude=excluded.latitude,longitude=excluded.longitude,accuracy=excluded.accuracy,fixed_at=excluded.fixed_at; end $$;
