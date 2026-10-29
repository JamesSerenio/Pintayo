-- Referenced avatars are minimal public identity for authenticated, unblocked
-- users. A definer helper avoids accidentally applying profile self-RLS inside
-- the Storage object policy and hiding every friend's photo.
create function private.can_read_avatar(object_name text) returns boolean language sql stable security definer set search_path='' as $$
 select auth.uid() is not null and(split_part(object_name,'/',1)=auth.uid()::text
 or exists(select 1 from public.profiles p where p.avatar_path=object_name and not private.blocked(p.id,auth.uid()))); $$;
revoke execute on function private.can_read_avatar(text) from public,anon;
grant execute on function private.can_read_avatar(text) to authenticated;
drop policy avatar_read on storage.objects;
create policy avatar_read on storage.objects for select to authenticated using(bucket_id='avatars' and private.can_read_avatar(name));

-- Make worker permissions explicit rather than depending on a project's default
-- privileges for newly created public-schema objects.
grant select,delete on public.devices to service_role;
grant select,update on public.notifications to service_role;
grant select,insert on public.push_deliveries to service_role;
