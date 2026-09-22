create extension if not exists pgcrypto;

create table public.trips (
  id uuid primary key default gen_random_uuid(),
  payload jsonb not null default '{}',
  updated_at timestamptz not null default now(),
  invite_token_hash text not null unique,
  invite_expires_at timestamptz not null default (now() + interval '30 days')
);

create table public.trip_members (
  trip_id uuid not null references public.trips(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null check (role in ('owner', 'member')),
  created_at timestamptz not null default now(),
  primary key (trip_id, user_id)
);

create table public.places (
  trip_id uuid not null references public.trips(id) on delete cascade,
  id text not null,
  payload jsonb not null,
  updated_at timestamptz not null,
  deleted boolean not null default false,
  primary key (trip_id, id)
);

create table public.documents (
  trip_id uuid not null references public.trips(id) on delete cascade,
  id text not null,
  name text not null,
  filename text not null,
  extracted_text text not null default '',
  storage_path text not null,
  updated_at timestamptz not null,
  primary key (trip_id, id)
);

create or replace function public.is_trip_member(target_trip_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.trip_members
    where trip_id = target_trip_id and user_id = auth.uid()
  );
$$;

create or replace function public.create_trip_for_user(target_user_id uuid, token_hash text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare new_trip_id uuid;
begin
  insert into public.trips (payload, invite_token_hash)
  values ('{"hotel":"Hotel Urban Crème","outbound":"","arrival":"","route":"","flightNumber":"","notes":"","updatedAt":-62135769600}'::jsonb, token_hash)
  returning id into new_trip_id;
  insert into public.trip_members (trip_id, user_id, role) values (new_trip_id, target_user_id, 'owner');
  return new_trip_id;
end;
$$;

create or replace function public.join_trip_for_user(target_user_id uuid, token_hash text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare found_trip_id uuid;
begin
  select id into found_trip_id from public.trips
  where invite_token_hash = token_hash and invite_expires_at > now();
  if found_trip_id is null then return null; end if;
  insert into public.trip_members (trip_id, user_id, role)
  values (found_trip_id, target_user_id, 'member')
  on conflict (trip_id, user_id) do nothing;
  return found_trip_id;
end;
$$;

revoke all on function public.create_trip_for_user(uuid, text) from public, anon, authenticated;
revoke all on function public.join_trip_for_user(uuid, text) from public, anon, authenticated;
grant execute on function public.create_trip_for_user(uuid, text) to service_role;
grant execute on function public.join_trip_for_user(uuid, text) to service_role;

alter table public.trips enable row level security;
alter table public.trip_members enable row level security;
alter table public.places enable row level security;
alter table public.documents enable row level security;

create policy "members read trips" on public.trips for select to authenticated using (public.is_trip_member(id));
create policy "members update trips" on public.trips for update to authenticated using (public.is_trip_member(id)) with check (public.is_trip_member(id));
create policy "members read memberships" on public.trip_members for select to authenticated using (public.is_trip_member(trip_id));
create policy "members read places" on public.places for select to authenticated using (public.is_trip_member(trip_id));
create policy "members insert places" on public.places for insert to authenticated with check (public.is_trip_member(trip_id));
create policy "members update places" on public.places for update to authenticated using (public.is_trip_member(trip_id)) with check (public.is_trip_member(trip_id));
create policy "members read documents" on public.documents for select to authenticated using (public.is_trip_member(trip_id));
create policy "members insert documents" on public.documents for insert to authenticated with check (public.is_trip_member(trip_id));
create policy "members update documents" on public.documents for update to authenticated using (public.is_trip_member(trip_id)) with check (public.is_trip_member(trip_id));

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('trip-files', 'trip-files', false, 25000000, array['application/pdf'])
on conflict (id) do update set public = false, file_size_limit = 25000000, allowed_mime_types = array['application/pdf'];

create policy "members read trip files" on storage.objects for select to authenticated
using (bucket_id = 'trip-files' and public.is_trip_member(((storage.foldername(name))[1])::uuid));
create policy "members upload trip files" on storage.objects for insert to authenticated
with check (bucket_id = 'trip-files' and public.is_trip_member(((storage.foldername(name))[1])::uuid));
create policy "members update trip files" on storage.objects for update to authenticated
using (bucket_id = 'trip-files' and public.is_trip_member(((storage.foldername(name))[1])::uuid))
with check (bucket_id = 'trip-files' and public.is_trip_member(((storage.foldername(name))[1])::uuid));

alter publication supabase_realtime add table public.trips, public.places, public.documents;
