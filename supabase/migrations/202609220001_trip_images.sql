insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('trip-images', 'trip-images', false, 5000000, array['image/jpeg'])
on conflict (id) do update
set public = false, file_size_limit = 5000000, allowed_mime_types = array['image/jpeg'];

create policy "members read trip images" on storage.objects for select to authenticated
using (bucket_id = 'trip-images' and public.is_trip_member(((storage.foldername(name))[1])::uuid));

create policy "members upload trip images" on storage.objects for insert to authenticated
with check (bucket_id = 'trip-images' and public.is_trip_member(((storage.foldername(name))[1])::uuid));

create policy "members update trip images" on storage.objects for update to authenticated
using (bucket_id = 'trip-images' and public.is_trip_member(((storage.foldername(name))[1])::uuid))
with check (bucket_id = 'trip-images' and public.is_trip_member(((storage.foldername(name))[1])::uuid));

create policy "members delete trip images" on storage.objects for delete to authenticated
using (bucket_id = 'trip-images' and public.is_trip_member(((storage.foldername(name))[1])::uuid));
