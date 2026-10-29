create table public.push_deliveries(
 event_id uuid references public.notifications on delete cascade,
 installation uuid not null, accepted_at timestamptz not null default now(),
 primary key(event_id,installation)
);
alter table public.push_deliveries enable row level security;
revoke all on public.push_deliveries from anon,authenticated;
grant all on public.push_deliveries to service_role;

create function public.push_payload(event_id uuid) returns jsonb language plpgsql stable security definer set search_path='' as $$
 declare n public.notifications; m public.messages; c public.conversations; f public.friendships; begin
 select * into n from public.notifications where id=event_id;
 if n.kind='message' then
 select * into m from public.messages where id=n.entity_id;
 select * into c from public.conversations where id=m.conversation_id;
 if n.recipient not in(c.a,c.b) or n.recipient=m.sender or not private.friends(c.a,c.b) then return null; end if;
 return jsonb_build_object('conversation_id',c.id);
 elsif n.kind='friend_request' then
 select * into f from public.friendships where id=n.entity_id;
 if f.id is null or f.recipient<>n.recipient or f.status<>'pending' or private.blocked(f.requester,f.recipient) then return null; end if;
 return '{}'::jsonb;
 end if;
 return null; end $$;
revoke execute on function public.push_payload(uuid) from public,anon,authenticated;
grant execute on function public.push_payload(uuid) to service_role;

-- Users register their own device through RLS. Event dispatch never advances
-- delivered_at or seen_at; only ack_messages() from the recipient app does.
