-- A person may keep one reaction per message. Only chat participants can read
-- reactions, and only accepted, unblocked friends can create/change them.
create table public.message_reactions (
 message_id uuid not null references public.messages(id) on delete cascade,
 owner uuid not null references public.profiles(id) on delete cascade,
 conversation_id uuid not null references public.conversations(id) on delete cascade,
 emoji text not null check (emoji in ('❤️','👍','😂','😮','😢','😡')),
 primary key(message_id,owner)
);
create index message_reactions_chat on public.message_reactions(conversation_id);
alter table public.message_reactions enable row level security;
revoke all on public.message_reactions from public,anon,authenticated;
grant select on public.message_reactions to authenticated;
create policy reaction_read on public.message_reactions for select to authenticated
 using(private.in_chat(conversation_id,auth.uid()));

create function public.react_to_message(message_id uuid,reaction text default null)
 returns void language plpgsql security definer set search_path='' as $$
declare chat uuid; first_user uuid; second_user uuid;
begin
 select c.id,c.a,c.b into chat,first_user,second_user
 from public.messages m join public.conversations c on c.id=m.conversation_id
 where m.id=message_id and auth.uid() in(c.a,c.b);
 if chat is null or not private.friends(first_user,second_user) then
   raise exception 'Not allowed';
 end if;
 if reaction is null then
   delete from public.message_reactions r where r.message_id=react_to_message.message_id and r.owner=auth.uid();
 else
   insert into public.message_reactions values(message_id,auth.uid(),chat,reaction)
   on conflict on constraint message_reactions_pkey do update set emoji=excluded.emoji;
 end if;
end $$;
revoke execute on function public.react_to_message(uuid,text) from public,anon;
grant execute on function public.react_to_message(uuid,text) to authenticated;
alter table public.message_reactions replica identity full;
alter publication supabase_realtime add table public.message_reactions;
