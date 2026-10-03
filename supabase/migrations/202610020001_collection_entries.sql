create table public.collection_entries (
  trip_id uuid not null references public.trips(id) on delete cascade,
  id text not null,
  payload jsonb not null,
  version bigint not null default 1,
  deleted boolean not null default false,
  updated_at timestamptz not null default now(),
  primary key (trip_id, id)
);

create index collection_entries_trip_updated_idx on public.collection_entries (trip_id, updated_at desc);

create or replace function public.set_collection_entry_updated_at()
returns trigger language plpgsql set search_path = public as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger collection_entries_updated_at
before insert or update on public.collection_entries
for each row execute function public.set_collection_entry_updated_at();

alter table public.collection_entries enable row level security;
create policy "members read collection entries" on public.collection_entries
  for select to authenticated using (public.is_trip_member(trip_id));
create policy "members insert collection entries" on public.collection_entries
  for insert to authenticated with check (public.is_trip_member(trip_id));
create policy "members update collection entries" on public.collection_entries
  for update to authenticated using (public.is_trip_member(trip_id)) with check (public.is_trip_member(trip_id));

revoke all on public.collection_entries from public, anon;
grant select, insert, update on public.collection_entries to authenticated;
alter publication supabase_realtime add table public.collection_entries;
