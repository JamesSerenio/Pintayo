begin;
insert into auth.users values
 ('00000000-0000-4000-8000-000000000021','action-a@test.invalid'),
 ('00000000-0000-4000-8000-000000000022','action-b@test.invalid'),
 ('00000000-0000-4000-8000-000000000023','action-c@test.invalid'),
 ('00000000-0000-4000-8000-000000000024','action-d@test.invalid');
insert into public.profiles(id,username,display_name) select id,'action_'||right(id::text,2),email from auth.users where email like 'action-%';
insert into public.friendships(requester,recipient,status) values
 ('00000000-0000-4000-8000-000000000021','00000000-0000-4000-8000-000000000022','accepted'),
 ('00000000-0000-4000-8000-000000000022','00000000-0000-4000-8000-000000000023','accepted');
insert into public.conversations values
 ('00000000-0000-4000-8000-000000000121','00000000-0000-4000-8000-000000000021','00000000-0000-4000-8000-000000000022'),
 ('00000000-0000-4000-8000-000000000122','00000000-0000-4000-8000-000000000022','00000000-0000-4000-8000-000000000023');
insert into storage.objects(bucket_id,name) values('attachments','00000000-0000-4000-8000-000000000121/00000000-0000-4000-8000-000000000021/source.jpg');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000021',true);
set local role authenticated;
select public.send_chat_message('00000000-0000-4000-8000-000000000221','00000000-0000-4000-8000-000000000121','secret original',null,null);
select public.send_chat_message('00000000-0000-4000-8000-000000000222','00000000-0000-4000-8000-000000000121',null,'00000000-0000-4000-8000-000000000121/00000000-0000-4000-8000-000000000021/source.jpg',null);
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000022',true);
select public.send_chat_message('00000000-0000-4000-8000-000000000223','00000000-0000-4000-8000-000000000121','reply',null,'00000000-0000-4000-8000-000000000221');
do $$ begin
 begin perform public.send_chat_message('00000000-0000-4000-8000-000000000224','00000000-0000-4000-8000-000000000122','bad reply',null,'00000000-0000-4000-8000-000000000221'); raise exception 'Cross-chat reply allowed';
 exception when raise_exception then if sqlerrm<>'Reply target unavailable' then raise; end if; end;
 begin perform public.delete_message_everyone('00000000-0000-4000-8000-000000000221'); raise exception 'Recipient global deletion allowed';
 exception when raise_exception then if sqlerrm<>'Only the sender can delete this message' then raise; end if; end;
end $$;
select public.prepare_message_forward('00000000-0000-4000-8000-000000000321','00000000-0000-4000-8000-000000000221','00000000-0000-4000-8000-000000000122');
select public.prepare_message_forward('00000000-0000-4000-8000-000000000322','00000000-0000-4000-8000-000000000222','00000000-0000-4000-8000-000000000122');
do $$ begin
 begin perform public.finish_message_forward('00000000-0000-4000-8000-000000000321',auth.uid()); raise exception 'Untrusted finalize allowed'; exception when insufficient_privilege then null; end;
 begin insert into storage.objects(bucket_id,name) values('attachments','00000000-0000-4000-8000-000000000122/00000000-0000-4000-8000-000000000022/00000000-0000-4000-8000-000000000322.jpg'); raise exception 'Reserved forward upload allowed'; exception when insufficient_privilege then null; end;
end $$;
reset role;
-- The embedded engine has no Storage HTTP server; simulate only a successful
-- trusted Storage.copy result. Real object copying is performed by the Edge Function.
insert into storage.objects(bucket_id,name) values('attachments','00000000-0000-4000-8000-000000000122/00000000-0000-4000-8000-000000000022/00000000-0000-4000-8000-000000000322.jpg');
set local role service_role;
select public.finish_message_forward('00000000-0000-4000-8000-000000000321','00000000-0000-4000-8000-000000000022');
select public.finish_message_forward('00000000-0000-4000-8000-000000000322','00000000-0000-4000-8000-000000000022');
select public.finish_message_forward('00000000-0000-4000-8000-000000000322','00000000-0000-4000-8000-000000000022');
reset role;
set local role authenticated;
select public.hide_message('00000000-0000-4000-8000-000000000221');
select public.hide_message('00000000-0000-4000-8000-000000000221');
do $$ begin
 if exists(select 1 from public.message_page('00000000-0000-4000-8000-000000000121') where id='00000000-0000-4000-8000-000000000221') then raise exception 'Hidden message returned by page'; end if;
 if exists(select 1 from public.search_chat_messages('00000000-0000-4000-8000-000000000121','secret')) then raise exception 'Hidden content returned by search'; end if;
 if (select count(*) from public.hidden_messages)<>1 then raise exception 'Duplicate hide'; end if;
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000021',true);
do $$ begin
 if not exists(select 1 from public.message_page('00000000-0000-4000-8000-000000000121') where body='secret original') then raise exception 'Hide removed partner history'; end if;
 if exists(select 1 from public.hidden_messages) then raise exception 'Other account hide records exposed'; end if;
end $$;
select public.delete_message_everyone('00000000-0000-4000-8000-000000000221');
select public.delete_message_everyone('00000000-0000-4000-8000-000000000222');
select public.delete_message_everyone('00000000-0000-4000-8000-000000000222');
do $$ begin
 if exists(select 1 from public.message_receipts('00000000-0000-4000-8000-000000000121',array['00000000-0000-4000-8000-000000000221'::uuid,'00000000-0000-4000-8000-000000000222'::uuid]) where body is not null or attachment is not null or deleted_at is null) then raise exception 'Deleted content in context response'; end if;
 if private.can_read_attachment('00000000-0000-4000-8000-000000000121/00000000-0000-4000-8000-000000000021/source.jpg') then raise exception 'Deleted original attachment still signable'; end if;
 begin perform public.react_to_message('00000000-0000-4000-8000-000000000221','❤️'); raise exception 'Deleted reaction allowed'; exception when raise_exception then if sqlerrm<>'Not allowed' then raise; end if; end;
 begin perform public.send_chat_message('00000000-0000-4000-8000-000000000225','00000000-0000-4000-8000-000000000121','late reply',null,'00000000-0000-4000-8000-000000000221'); raise exception 'Deleted reply allowed'; exception when raise_exception then if sqlerrm<>'Reply target unavailable' then raise; end if; end;
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000022',true);
do $$ begin
 if exists(select 1 from public.message_page('00000000-0000-4000-8000-000000000121') where id='00000000-0000-4000-8000-000000000221') then raise exception 'Global tombstone restored hidden message'; end if;
 if not exists(select 1 from public.messages where id='00000000-0000-4000-8000-000000000321' and body='secret original' and forwarded) then raise exception 'Independent text forward lost'; end if;
 if not private.can_read_attachment('00000000-0000-4000-8000-000000000122/00000000-0000-4000-8000-000000000022/00000000-0000-4000-8000-000000000322.jpg') then raise exception 'Independent photo forward lost'; end if;
 begin perform public.prepare_message_forward('00000000-0000-4000-8000-000000000323','00000000-0000-4000-8000-000000000222','00000000-0000-4000-8000-000000000122'); raise exception 'Deleted forward allowed'; exception when raise_exception then if sqlerrm<>'Source message unavailable' then raise; end if; end;
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000023',true);
do $$ begin
 if exists(select 1 from public.message_page('00000000-0000-4000-8000-000000000121')) then raise exception 'Forward exposed source chat'; end if;
 if (select count(*) from public.message_page('00000000-0000-4000-8000-000000000122') where forwarded)<>2 then raise exception 'Forward duplicates or missing copies'; end if;
end $$;
reset role;
set local role service_role;
do $$ begin
 if (select count(*) from public.attachment_cleanup_batch() where path like '%source.jpg')<>1 then raise exception 'Original cleanup not queued'; end if;
 if exists(select 1 from public.attachment_cleanup_batch() where path like '%000000000322.jpg') then raise exception 'Forward incorrectly queued for removal'; end if;
end $$;
reset role;
rollback;
