-- Stable per-trip roster and caller-owned individual place decisions.
alter table public.trip_members
  add column if not exists display_name text not null default '';

create table if not exists public.place_member_votes (
  trip_id uuid not null references public.trips(id) on delete cascade,
  place_id text not null,
  user_id uuid not null references auth.users(id) on delete cascade,
  decision boolean,
  mutation_id uuid not null,
  updated_at timestamptz not null default now(),
  primary key (trip_id, place_id, user_id)
);

alter table public.place_member_votes enable row level security;
drop policy if exists "members read place votes" on public.place_member_votes;
create policy "members read place votes" on public.place_member_votes
  for select to authenticated using (public.is_trip_member(trip_id));
revoke insert, update, delete on public.place_member_votes from anon, authenticated;

-- Old and new clients may write full Place payloads. Never accept their vote cache as authority.
create or replace function public.strip_place_member_votes()
returns trigger language plpgsql set search_path = public as $$
begin
  new.payload := new.payload - 'memberVotes';
  return new;
end;
$$;
drop trigger if exists places_strip_member_votes on public.places;
create trigger places_strip_member_votes before insert or update on public.places
  for each row execute function public.strip_place_member_votes();

create or replace function public.set_my_trip_display_name(p_trip_id uuid, p_display_name text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null or not public.is_trip_member(p_trip_id) then
    raise exception using errcode = '42501', message = 'trip membership required';
  end if;
  update public.trip_members
    set display_name = left(trim(coalesce(p_display_name, '')), 80)
    where trip_id = p_trip_id and user_id = auth.uid()
      and display_name is distinct from left(trim(coalesce(p_display_name, '')), 80);
end;
$$;
revoke all on function public.set_my_trip_display_name(uuid, text) from public, anon;
grant execute on function public.set_my_trip_display_name(uuid, text) to authenticated;
grant select on public.place_member_votes to authenticated;

create or replace function public.set_my_trip_place_vote(
  p_trip_id uuid, p_place_id text, p_decision boolean, p_mutation_id uuid
) returns void language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null or not public.is_trip_member(p_trip_id) then
    raise exception using errcode = '42501', message = 'trip membership required';
  end if;
  if p_place_id is null or length(p_place_id) > 200 or p_mutation_id is null
     or not exists (select 1 from public.places where trip_id = p_trip_id and id = p_place_id) then
    raise exception using errcode = '22023', message = 'invalid vote';
  end if;
  insert into public.place_member_votes(trip_id, place_id, user_id, decision, mutation_id, updated_at)
  values (p_trip_id, p_place_id, auth.uid(), p_decision, p_mutation_id, now())
  on conflict (trip_id, place_id, user_id) do update
    set decision = excluded.decision, mutation_id = excluded.mutation_id, updated_at = excluded.updated_at
    where public.place_member_votes.mutation_id <> excluded.mutation_id;
end;
$$;
revoke all on function public.set_my_trip_place_vote(uuid, text, boolean, uuid) from public, anon;
grant execute on function public.set_my_trip_place_vote(uuid, text, boolean, uuid) to authenticated;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'trip_members') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.trip_members;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'place_member_votes') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.place_member_votes;
  END IF;
END $$;
