begin;
insert into auth.users values
 ('00000000-0000-4000-8000-000000000011','react-a@test.invalid'),
 ('00000000-0000-4000-8000-000000000012','react-b@test.invalid'),
 ('00000000-0000-4000-8000-000000000013','react-c@test.invalid');
insert into public.profiles(id,username,display_name)
 select id,'react_'||right(id::text,2),email from auth.users where email like 'react-%';
insert into public.friendships(requester,recipient,status) values
 ('00000000-0000-4000-8000-000000000011','00000000-0000-4000-8000-000000000012','accepted');
insert into public.conversations(id,a,b) values
 ('00000000-0000-4000-8000-000000000101','00000000-0000-4000-8000-000000000011','00000000-0000-4000-8000-000000000012');
insert into public.messages(id,conversation_id,sender,body) values
 ('00000000-0000-4000-8000-000000000201','00000000-0000-4000-8000-000000000101','00000000-0000-4000-8000-000000000011','Reaction test');
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000012',true);
select public.react_to_message('00000000-0000-4000-8000-000000000201','❤️');
select public.react_to_message('00000000-0000-4000-8000-000000000201','👍');
do $$ begin
 if (select count(*) from public.message_reactions)<>1 or (select emoji from public.message_reactions)<>'👍' then raise exception 'Reaction replacement failed'; end if;
 begin
  perform public.react_to_message('00000000-0000-4000-8000-000000000201','invalid');
  raise exception 'Invalid emoji accepted';
 exception when check_violation then null; end;
 begin
  insert into public.message_reactions values('00000000-0000-4000-8000-000000000201','00000000-0000-4000-8000-000000000011','00000000-0000-4000-8000-000000000101','❤️');
  raise exception 'Direct impersonation accepted';
 exception when insufficient_privilege then null; end;
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000011',true);
select public.react_to_message('00000000-0000-4000-8000-000000000201','😆');
select public.react_to_message('00000000-0000-4000-8000-000000000201',null);
do $$ begin
 if (select count(*) from public.message_reactions)<>1 then raise exception 'Removal affected partner reaction'; end if;
 if exists(select 1 from public.messages where id='00000000-0000-4000-8000-000000000201' and (delivered_at is not null or seen_at is not null)) then raise exception 'Reaction changed message receipts'; end if;
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000013',true);
do $$ begin
 if exists(select 1 from public.message_reactions) then raise exception 'Outsider could read reactions'; end if;
 begin
  perform public.react_to_message('00000000-0000-4000-8000-000000000201','❤️');
  raise exception 'Outsider could react';
 exception when raise_exception then if sqlerrm<>'Not allowed' then raise; end if; end;
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000011',true);
select public.friend_action('00000000-0000-4000-8000-000000000012','block');
do $$ begin
 begin
  perform public.react_to_message('00000000-0000-4000-8000-000000000201','❤️');
  raise exception 'Blocked pair could react';
 exception when raise_exception then if sqlerrm<>'Not allowed' then raise; end if; end;
end $$;
reset role;
rollback;
