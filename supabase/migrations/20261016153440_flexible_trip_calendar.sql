-- FT-05: shared trip/calendar v2 writes are upgraded as one transaction.
-- Unknown JSON keys and table columns survive the merge; stable row IDs remain keys.

create or replace function public.is_iso_calendar_date(value text)
returns boolean
language plpgsql
immutable
strict
set search_path = public
as $$
declare parsed date;
begin
  if value !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' then return false; end if;
  parsed := value::date;
  return to_char(parsed, 'YYYY-MM-DD') = value;
exception when others then
  return false;
end;
$$;

create or replace function public.reject_unversioned_trip_v2_write()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if old.payload ->> 'planningSchemaVersion' = '2'
     and new.payload ->> 'planningSchemaVersion' is distinct from '2' then
    raise exception using errcode = 'P0001', message = 'ALBUM_PROTOCOL_UPGRADE_REQUIRED';
  end if;
  return new;
end;
$$;

create or replace function public.reject_unversioned_place_v2_write()
returns trigger
language plpgsql
set search_path = public
as $$
declare trip_version text;
begin
  select payload ->> 'planningSchemaVersion' into trip_version
  from public.trips where id = new.trip_id;
  if trip_version = '2' and new.payload ->> 'planningSchemaVersion' is distinct from '2' then
    raise exception using errcode = 'P0001', message = 'ALBUM_PROTOCOL_UPGRADE_REQUIRED';
  end if;
  return new;
end;
$$;

drop trigger if exists trips_require_v2_protocol on public.trips;
create trigger trips_require_v2_protocol
before update on public.trips
for each row execute function public.reject_unversioned_trip_v2_write();

drop trigger if exists places_require_v2_protocol on public.places;
create trigger places_require_v2_protocol
before insert or update on public.places
for each row execute function public.reject_unversioned_place_v2_write();

create or replace function public.sync_trip_v2(
  p_trip_id uuid,
  p_trip_payload jsonb,
  p_expected_trip_updated_at timestamptz,
  p_places jsonb default '[]'::jsonb
)
returns jsonb
language plpgsql
security invoker
set search_path = public
as $$
declare
  current_trip jsonb;
  current_trip_updated_at timestamptz;
  result_trip_updated_at timestamptz;
  result_place_updated_at jsonb := '{}'::jsonb;
  merged_trip jsonb;
  trip_version text;
  row_value jsonb;
  row_id text;
  place_payload jsonb;
  server_revision timestamptz;
  deleted_value boolean;
  expected_place_updated_at timestamptz;
  current_place_updated_at timestamptz;
  supplied_place_count integer;
  distinct_place_count integer;
begin
  if auth.uid() is null or not public.is_trip_member(p_trip_id) then
    raise exception using errcode = '42501', message = 'Not a trip member';
  end if;
  if p_places is null or jsonb_typeof(p_places) <> 'array' then
    raise exception using errcode = '22023', message = 'p_places must be an array';
  end if;
  select count(*)::integer, count(distinct value ->> 'id')::integer
  into supplied_place_count, distinct_place_count
  from jsonb_array_elements(p_places);
  if supplied_place_count <> distinct_place_count then
    raise exception using errcode = '22023', message = 'Duplicate place IDs in v2 batch';
  end if;

  select payload, updated_at into current_trip, current_trip_updated_at
  from public.trips where id = p_trip_id for update;
  if current_trip is null then
    raise exception using errcode = 'P0002', message = 'Trip not found';
  end if;
  trip_version := current_trip ->> 'planningSchemaVersion';

  if p_trip_payload is not null then
    if p_expected_trip_updated_at is null or p_expected_trip_updated_at <> current_trip_updated_at then
      raise exception using errcode = 'P0001', message = 'ALBUM_SYNC_CONFLICT';
    end if;
    if jsonb_typeof(p_trip_payload) <> 'object'
       or p_trip_payload ->> 'planningSchemaVersion' is distinct from '2' then
      raise exception using errcode = '22023', message = 'ALBUM_PROTOCOL_UPGRADE_REQUIRED';
    end if;
    if p_trip_payload ? 'startDate' and p_trip_payload -> 'startDate' <> 'null'::jsonb
       and not public.is_iso_calendar_date(p_trip_payload ->> 'startDate') then
      raise exception using errcode = '22023', message = 'Invalid trip start date';
    end if;
    if p_trip_payload ? 'endDate' and p_trip_payload -> 'endDate' <> 'null'::jsonb
       and not public.is_iso_calendar_date(p_trip_payload ->> 'endDate') then
      raise exception using errcode = '22023', message = 'Invalid trip end date';
    end if;
    if (p_trip_payload ->> 'startDate' is null) <> (p_trip_payload ->> 'endDate' is null) then
      raise exception using errcode = '22023', message = 'Trip dates must both be present or absent';
    end if;
    if p_trip_payload ->> 'startDate' is not null and p_trip_payload ->> 'endDate' is not null
       and p_trip_payload ->> 'startDate' > p_trip_payload ->> 'endDate' then
      raise exception using errcode = '22023', message = 'Trip end date precedes start date';
    end if;
    if trip_version is distinct from '2' and exists (
      select 1 from public.places existing
      where existing.trip_id = p_trip_id
        and not exists (
          select 1 from jsonb_array_elements(p_places) supplied(value)
          where supplied.value ->> 'id' = existing.id
        )
    ) then
      raise exception using errcode = '22023', message = 'ALBUM_V2_TRANSITION_REQUIRES_ALL_PLACES';
    end if;

    merged_trip := (current_trip - array[
      'title', 'destination', 'startDate', 'endDate', 'timeZoneIdentifier',
      'planningSchemaVersion', 'hotel', 'outbound', 'arrival', 'route',
      'flightNumber', 'notes', 'updatedAt', 'flights', 'hotelDetails',
      'bookingNumber', 'travelers'
    ]) || p_trip_payload;
    update public.trips
      set payload = merged_trip,
          updated_at = greatest(clock_timestamp(), current_trip_updated_at + interval '1 microsecond')
      where id = p_trip_id
      returning updated_at into result_trip_updated_at;
  elsif trip_version is distinct from '2' then
    raise exception using errcode = 'P0001', message = 'ALBUM_PROTOCOL_UPGRADE_REQUIRED';
  else
    result_trip_updated_at := current_trip_updated_at;
  end if;

  for row_value in select value from jsonb_array_elements(p_places)
  loop
    if jsonb_typeof(row_value) <> 'object' then
      raise exception using errcode = '22023', message = 'Invalid place sync row';
    end if;
    row_id := row_value ->> 'id';
    place_payload := row_value -> 'payload';
    if row_id is null or length(row_id) = 0 or jsonb_typeof(place_payload) <> 'object'
       or place_payload ->> 'id' is distinct from row_id
       or place_payload ->> 'planningSchemaVersion' is distinct from '2' then
      raise exception using errcode = 'P0001', message = 'ALBUM_PROTOCOL_UPGRADE_REQUIRED';
    end if;
    if place_payload ? 'plannedDate' and place_payload -> 'plannedDate' <> 'null'::jsonb
       and not public.is_iso_calendar_date(place_payload ->> 'plannedDate') then
      raise exception using errcode = '22023', message = 'Invalid planned date';
    end if;
    deleted_value := coalesce((row_value ->> 'deleted')::boolean, false);
    expected_place_updated_at := null;
    if row_value ->> 'expected_updated_at' is not null then
      expected_place_updated_at := (row_value ->> 'expected_updated_at')::timestamptz;
    end if;
    select updated_at into current_place_updated_at
    from public.places where trip_id = p_trip_id and id = row_id for update;
    if found then
      if expected_place_updated_at is null or expected_place_updated_at <> current_place_updated_at then
        raise exception using errcode = 'P0001', message = 'ALBUM_SYNC_CONFLICT';
      end if;
      server_revision := greatest(clock_timestamp(), current_place_updated_at + interval '1 microsecond');
    else
      if expected_place_updated_at is not null then
        raise exception using errcode = 'P0001', message = 'ALBUM_SYNC_CONFLICT';
      end if;
      server_revision := clock_timestamp();
    end if;

    insert into public.places (trip_id, id, payload, updated_at, deleted)
    values (p_trip_id, row_id, place_payload, server_revision, deleted_value)
    on conflict (trip_id, id) do update set
      payload = (public.places.payload - array[
        'id', 'title', 'note', 'sourceURL', 'category', 'author', 'image',
        'address', 'lat', 'lng', 'selectedGooglePlace', 'franked', 'deferred',
        'deleted', 'visited', 'plannedDate', 'planningSchemaVersion', 'day',
        'dayOrder', 'approvals', 'passedBy', 'openingHours', 'gallery',
        'updatedAt', 'imageName', 'remoteImage', 'imageSourceURL', 'imageCredit'
      ]) || excluded.payload,
      updated_at = excluded.updated_at,
      deleted = excluded.deleted;
    result_place_updated_at := result_place_updated_at || jsonb_build_object(row_id, server_revision);
  end loop;
  return jsonb_build_object('trip_updated_at', result_trip_updated_at, 'place_updated_at', result_place_updated_at);
end;
$$;

revoke all on function public.sync_trip_v2(uuid, jsonb, timestamptz, jsonb) from public, anon;
grant execute on function public.sync_trip_v2(uuid, jsonb, timestamptz, jsonb) to authenticated;
