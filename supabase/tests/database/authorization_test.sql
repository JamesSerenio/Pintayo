begin;
create extension if not exists pgtap with schema extensions;
select plan(20);
insert into auth.users(id,email) values
 ('00000000-0000-4000-8000-000000000001','test-a@pintayo.invalid'),
 ('00000000-0000-4000-8000-000000000002','test-b@pintayo.invalid'),
 ('00000000-0000-4000-8000-000000000003','test-c@pintayo.invalid');
insert into public.profiles(id,username,display_name) values
 ('00000000-0000-4000-8000-000000000001','test_a','A'),
 ('00000000-0000-4000-8000-000000000002','test_b','B'),
 ('00000000-0000-4000-8000-000000000003','test_c','C');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000001',true);
select throws_ok($$select public.friend_action('00000000-0000-4000-8000-000000000001','request')$$,'P0001','Invalid friend','self requests denied');
select public.friend_action('00000000-0000-4000-8000-000000000002','request');
select public.friend_action('00000000-0000-4000-8000-000000000002','request');
select is((select count(*) from public.friendships),1::bigint,'pending pair deduplicated');
select ok(not private.can_locate('00000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000002'),'request never shares');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000002',true);
select public.friend_action('00000000-0000-4000-8000-000000000001','accept');
select ok(private.friends('00000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000002'),'accepted friendship');
select ok(not private.can_locate('00000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000002'),'accepting never shares');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000001',true);
select public.share_start(array['00000000-0000-4000-8000-000000000002'::uuid],array[]::uuid[],15);
select ok(private.can_locate('00000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000002'),'selected friend authorized');
select ok(not private.can_locate('00000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000003'),'unselected user denied');
select public.publish_location(14.5,121,20,now());
select is((select count(*) from public.location_inbox),1::bigint,'server fanout only selected recipient');
select public.publish_location(15,122,20,now()-interval '1 second');
select is((select latitude from public.latest_locations),14.5::double precision,'delayed fix ignored');
select public.share_state('paused');
select ok(not private.can_locate('00000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000002'),'pause revokes');
select public.share_state('active');
update public.sharing_sessions set expires_at=now()-interval '1 second';
select ok(not private.can_locate('00000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000002'),'server-time expiration enforced');
select public.open_chat('00000000-0000-4000-8000-000000000002');
select public.send_message('10000000-0000-4000-8000-000000000001',(select id from public.conversations),'Hello');
select public.send_message('10000000-0000-4000-8000-000000000001',(select id from public.conversations),'Hello');
select is((select count(*) from public.messages),1::bigint,'idempotent send');
select ok((select delivered_at is null and seen_at is null from public.messages),'saving and notification enqueue never acknowledge receipt');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000003',true);
select throws_ok($$select public.send_message('10000000-0000-4000-8000-000000000002',(select id from public.conversations),'Intrusion')$$,'P0001','Conversation unavailable','nonparticipant send denied');
select is((select count(*) from public.message_page((select id from public.conversations))),0::bigint,'nonparticipant catch-up denied');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000002',true);
select public.ack_received((select id from public.conversations),array['10000000-0000-4000-8000-000000000001'::uuid],false);
select ok((select delivered_at is not null and seen_at is null from public.messages),'app acknowledgement delivers without reading');
select public.ack_received((select id from public.conversations),array['10000000-0000-4000-8000-000000000001'::uuid],true);
select ok((select seen_at is not null from public.messages),'active conversation marks seen');
select public.friend_action('00000000-0000-4000-8000-000000000001','block');
select ok(not private.friends('00000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000002'),'block revokes friendship');
select throws_ok($$select public.send_message('10000000-0000-4000-8000-000000000003',(select id from public.conversations),'Blocked')$$,'P0001','Conversation unavailable','blocked send denied');
set local role authenticated;
select is((select count(*) from public.devices),0::bigint,'device registrations private');
reset role;
select * from finish();
rollback;
