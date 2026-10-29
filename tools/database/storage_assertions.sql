select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000001',false);
select set_config('test.chat',(select id::text from public.conversations),false);
set role authenticated;
insert into storage.objects(bucket_id,name) values('avatars','00000000-0000-4000-8000-000000000001/test.jpg');
update public.profiles set avatar_path='00000000-0000-4000-8000-000000000001/test.jpg' where id=auth.uid();
insert into storage.objects(bucket_id,name) values('attachments',current_setting('test.chat')||'/00000000-0000-4000-8000-000000000001/test.jpg');
reset role;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000002',false);
set role authenticated;
do $$ begin
 if(select count(*) from storage.objects where bucket_id='avatars')<>1 then raise exception 'Friend avatar unexpectedly hidden by profile RLS'; end if;
 if(select count(*) from storage.objects where bucket_id='attachments')<>1 then raise exception 'Participant attachment access denied'; end if;
end $$;
reset role;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000003',false);
set role authenticated;
do $$ begin
 if(select count(*) from storage.objects where bucket_id='attachments')<>0 then raise exception 'Nonparticipant attachment exposed'; end if;
 begin insert into storage.objects(bucket_id,name) values('attachments',current_setting('test.chat')||'/00000000-0000-4000-8000-000000000003/forbidden.jpg');
 raise exception 'Nonparticipant upload permitted'; exception when insufficient_privilege then null; end;
end $$;
reset role;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000002',false);
select public.friend_action('00000000-0000-4000-8000-000000000001','block');
set role authenticated;
do $$ begin if(select count(*) from storage.objects where bucket_id='avatars')<>0 then raise exception 'Blocked profile photo visible'; end if; end $$;
reset role;
