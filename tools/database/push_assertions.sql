-- Restore the development friendship removed by the preceding block test.
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000002',false);
select public.friend_action('00000000-0000-4000-8000-000000000001','unblock');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000001',false);
select public.friend_action('00000000-0000-4000-8000-000000000002','request');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000002',false);
select public.friend_action('00000000-0000-4000-8000-000000000001','accept');
insert into auth.sessions(id,user_id) values
 ('40000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000001'),
 ('40000000-0000-4000-8000-000000000002','00000000-0000-4000-8000-000000000002');
select set_config('request.jwt.claims','{"session_id":"40000000-0000-4000-8000-000000000001"}',false);
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000001',false);
do $$ begin
 begin perform public.register_push_device('00000000-0000-4000-8000-000000000002','50000000-0000-4000-8000-000000000001','test-only-switching-fid','android');
 raise exception 'Registered against another account'; exception when raise_exception then if sqlerrm<>'Account changed. Try again.' then raise; end if; end;
end $$;
select public.register_push_device('00000000-0000-4000-8000-000000000001','50000000-0000-4000-8000-000000000001','test-only-switching-fid','android');
select public.register_push_device('00000000-0000-4000-8000-000000000001','50000000-0000-4000-8000-000000000002','test-only-second-device-fid','iOS');
do $$ begin if(select count(*) from public.devices where owner=auth.uid())<>2 then raise exception 'Multiple devices not preserved'; end if; end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000002',false);
select set_config('request.jwt.claims','{"session_id":"40000000-0000-4000-8000-000000000002"}',false);
select public.register_push_device('00000000-0000-4000-8000-000000000002','50000000-0000-4000-8000-000000000001','test-only-switching-fid','android');
do $$ begin
 if(select count(*) from public.devices where owner='00000000-0000-4000-8000-000000000001' and installation='50000000-0000-4000-8000-000000000001')<>0 then raise exception 'Old account retained switched device'; end if;
 if(select count(*) from public.push_devices((select id from public.notifications where kind='message' limit 1)))<>1 then raise exception 'Expected active recipient registration'; end if;
end $$;
set role authenticated;
do $$ begin if(select count(*) from public.devices where owner<>'00000000-0000-4000-8000-000000000002')<>0 then raise exception 'Private device data leaked'; end if; end $$;
reset role;
delete from auth.sessions where id='40000000-0000-4000-8000-000000000002';
do $$ begin
 if(select count(*) from public.push_devices((select id from public.notifications where kind='message' limit 1)))<>0 then raise exception 'Signed-out session still targeted'; end if;
 begin perform public.register_push_device('00000000-0000-4000-8000-000000000002','50000000-0000-4000-8000-000000000001','test-only-switching-fid','android');
 raise exception 'Revoked session registered again'; exception when raise_exception then if sqlerrm<>'Sign in again to enable notifications.' then raise; end if; end;
end $$;
select set_config('test.message_count',(select count(*)::text from public.messages),false);
select public.claim_push();
-- A simulated dispatch failure leaves its event undispatched and its message durable.
update public.notifications set lease_until=now()-interval '1 second' where kind='message';
do $$ begin if(select count(*) from public.messages)<>current_setting('test.message_count')::bigint then raise exception 'Push failure lost messages'; end if; end $$;
