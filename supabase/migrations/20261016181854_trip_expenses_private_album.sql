create table public.trip_feature_entries (
  trip_id uuid not null references public.trips(id) on delete cascade,
  id uuid not null,
  kind text not null check (kind in ('expense', 'settlement', 'photo')),
  payload jsonb not null check (jsonb_typeof(payload) = 'object'),
  owner_id uuid not null references auth.users(id),
  version bigint not null default 1 check (version > 0),
  mutation_token uuid not null,
  deleted boolean not null default false,
  storage_path text,
  updated_at timestamptz not null default now(),
  primary key (trip_id, id)
);

create index trip_feature_entries_trip_updated_idx on public.trip_feature_entries (trip_id, updated_at desc);
alter table public.trip_feature_entries enable row level security;
create policy "members read trip features" on public.trip_feature_entries
  for select to authenticated using (public.is_trip_member(trip_id));
revoke all on public.trip_feature_entries from public, anon, authenticated;
grant select on public.trip_feature_entries to authenticated;

create or replace function public.trip_feature_integer(p_object jsonb, p_key text)
returns numeric language plpgsql immutable set search_path = public as $$
declare value_text text;
begin
  if jsonb_typeof(p_object -> p_key) <> 'number' then return null; end if;
  value_text := p_object ->> p_key;
  if value_text !~ '^-?[0-9]+$' then return null; end if;
  return value_text::numeric;
exception when numeric_value_out_of_range then return null;
end;
$$;
revoke all on function public.trip_feature_integer(jsonb, text) from public, anon, authenticated;

create or replace function public.trip_feature_currency_scale(p_currency text)
returns integer language sql immutable set search_path = public as $$
  select case
    when p_currency in ('BIF','CLP','DJF','GNF','ISK','JPY','KMF','KRW','PYG','RWF','UGX','UYI','VND','VUV','XAF','XOF','XPF') then 0
    when p_currency in ('BHD','IQD','JOD','KWD','LYD','OMR','TND') then 3
    when p_currency in ('AED','AFN','ALL','AMD','ANG','AOA','ARS','AUD','AWG','AZN','BAM','BBD','BDT','BGN','BMD','BND','BOB','BOV','BRL','BSD','BTN','BWP','BYN','BZD','CAD','CDF','CHE','CHF','CHW','CNY','COP','COU','CRC','CUC','CUP','CVE','CZK','DKK','DOP','DZD','EGP','ERN','ETB','EUR','FJD','FKP','GBP','GEL','GHS','GIP','GMD','GTQ','GYD','HKD','HNL','HTG','HUF','IDR','ILS','INR','IRR','JMD','KES','KGS','KHR','KPW','KYD','KZT','LAK','LBP','LKR','LRD','LSL','MAD','MDL','MGA','MKD','MMK','MNT','MOP','MRU','MUR','MVR','MWK','MXN','MXV','MYR','MZN','NAD','NGN','NIO','NOK','NPR','NZD','PAB','PEN','PGK','PHP','PKR','PLN','QAR','RON','RSD','RUB','SAR','SBD','SCR','SDG','SEK','SGD','SHP','SLE','SOS','SRD','SSP','STN','SVC','SYP','SZL','THB','TJS','TMT','TOP','TRY','TTD','TWD','TZS','UAH','USD','USN','UYU','UZS','VES','WST','YER','ZAR','ZMW','XCD') then 2
    else null
  end;
$$;
revoke all on function public.trip_feature_currency_scale(text) from public, anon, authenticated;

create or replace function public.commit_trip_feature(
  p_trip_id uuid,
  p_id uuid,
  p_kind text,
  p_payload text,
  p_owner_id uuid,
  p_deleted boolean,
  p_mutation_token uuid,
  p_expected_version bigint default null,
  p_storage_path text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, storage
as $$
declare
  actor uuid := auth.uid();
  body jsonb;
  current_row public.trip_feature_entries%rowtype;
  amount numeric;
  total numeric;
  currency text;
  entry jsonb;
  participant uuid;
  seen uuid[] := '{}';
  expected_path text;
  file_count integer;
begin
  if p_trip_id is null or p_id is null or p_kind is null or p_owner_id is null
     or p_deleted is null or p_mutation_token is null or p_payload is null then
    raise exception 'required feature fields are missing' using errcode = '22023';
  end if;
  if actor is null or actor <> p_owner_id or not public.is_trip_member(p_trip_id) then
    raise exception 'membership or owner mismatch' using errcode = '42501';
  end if;
  if p_kind not in ('expense','settlement','photo') or p_payload is null or octet_length(p_payload) > 1000000 then
    raise exception 'invalid feature envelope' using errcode = '22023';
  end if;
  begin body := p_payload::jsonb; exception when others then raise exception 'invalid JSON payload' using errcode = '22023'; end;
  if jsonb_typeof(body) <> 'object' or body ->> 'id' is distinct from p_id::text then
    raise exception 'payload ID mismatch' using errcode = '22023';
  end if;

  if p_kind in ('expense','settlement') then
    currency := body ->> 'currency';
    if public.trip_feature_currency_scale(currency) is null then raise exception 'unsupported currency' using errcode = '22023'; end if;
    if jsonb_typeof(body -> 'currency') is distinct from 'string' then raise exception 'currency must be text' using errcode = '22023'; end if;
    amount := public.trip_feature_integer(body, 'amountMinor');
    if amount is null or amount <= 0 or amount > 1000000000000 then raise exception 'invalid amount' using errcode = '22023'; end if;
    if p_kind = 'expense' then
      if jsonb_typeof(body -> 'title') is distinct from 'string'
        or jsonb_typeof(body -> 'payerName') is distinct from 'string'
        or btrim(coalesce(body ->> 'title','')) = '' or length(body ->> 'title') > 200
        or btrim(coalesce(body ->> 'payerName','')) = '' or length(body ->> 'payerName') > 200
        or length(coalesce(body ->> 'note','')) > 2000
        or (body ? 'note' and jsonb_typeof(body -> 'note') is distinct from 'string')
        or jsonb_typeof(body -> 'splitMode') is distinct from 'string' or body ->> 'splitMode' not in ('equal','custom')
        or jsonb_typeof(body -> 'day') is distinct from 'string' or body ->> 'day' !~ '^([0-9]{4})-([0-9]{2})-([0-9]{2})$'
        or jsonb_typeof(body -> 'shares') is distinct from 'array' then
        raise exception 'invalid expense fields' using errcode = '22023';
      end if;
      if jsonb_array_length(body -> 'shares') not between 1 and 200 then raise exception 'invalid expense shares' using errcode = '22023'; end if;
      begin
        if (body ->> 'day')::date::text <> body ->> 'day' then raise exception 'invalid day'; end if;
      exception when others then raise exception 'invalid expense day' using errcode = '22023'; end;
      begin participant := (body ->> 'payerID')::uuid; exception when others then raise exception 'invalid payer' using errcode = '22023'; end;
      if not exists (select 1 from public.trip_members where trip_id = p_trip_id and user_id = participant) then raise exception 'payer is not a trip member' using errcode = '22023'; end if;
      total := 0;
      for entry in select value from jsonb_array_elements(body -> 'shares') loop
        if jsonb_typeof(entry) is distinct from 'object' or jsonb_typeof(entry -> 'participantID') is distinct from 'string'
          or jsonb_typeof(entry -> 'name') is distinct from 'string'
          or btrim(coalesce(entry ->> 'name','')) = '' or length(entry ->> 'name') > 200 then
          raise exception 'invalid share' using errcode = '22023';
        end if;
        begin participant := (entry ->> 'participantID')::uuid; exception when others then raise exception 'invalid share member' using errcode = '22023'; end;
        if participant = any(seen) then raise exception 'duplicate share member' using errcode = '22023'; end if;
        seen := array_append(seen, participant);
        if not exists (select 1 from public.trip_members where trip_id = p_trip_id and user_id = participant) then raise exception 'share participant is not a trip member' using errcode = '22023'; end if;
        amount := public.trip_feature_integer(entry, 'amountMinor');
        if amount is null or amount <= 0 or amount > 1000000000000 then raise exception 'invalid share amount' using errcode = '22023'; end if;
        total := total + amount;
      end loop;
      if total <> public.trip_feature_integer(body, 'amountMinor') then raise exception 'share sum mismatch' using errcode = '22023'; end if;
      if body ->> 'splitMode' = 'equal' then
        if exists (
          select 1 from (
            select participant_id, public.trip_feature_integer(share, 'amountMinor') as share_amount,
                   row_number() over (order by participant_id) - 1 as share_index,
                   count(*) over () as share_count
            from jsonb_array_elements(body -> 'shares') as s(share)
            cross join lateral (select (share ->> 'participantID')::uuid as participant_id) p
          ) ordered
          where share_amount <> trunc(public.trip_feature_integer(body, 'amountMinor') / share_count)
            + case when share_index < (public.trip_feature_integer(body, 'amountMinor') % share_count) then 1 else 0 end
        ) then raise exception 'equal shares are not canonical' using errcode = '22023'; end if;
      end if;
    else
      begin
        if jsonb_typeof(body -> 'day') is distinct from 'string' or body ->> 'day' !~ '^([0-9]{4})-([0-9]{2})-([0-9]{2})$' then raise exception 'invalid day'; end if;
        if (body ->> 'day')::date::text <> body ->> 'day' then raise exception 'invalid day'; end if;
        if body ->> 'fromID' is null or body ->> 'toID' is null then raise exception 'missing settlement participant'; end if;
        if jsonb_typeof(body -> 'fromID') is distinct from 'string' or jsonb_typeof(body -> 'toID') is distinct from 'string'
          or jsonb_typeof(body -> 'fromName') is distinct from 'string' or jsonb_typeof(body -> 'toName') is distinct from 'string'
          or btrim(coalesce(body ->> 'fromName','')) = '' or length(body ->> 'fromName') > 200
          or btrim(coalesce(body ->> 'toName','')) = '' or length(body ->> 'toName') > 200
          or length(coalesce(body ->> 'note','')) > 2000
          or (body ? 'note' and jsonb_typeof(body -> 'note') is distinct from 'string') then
          raise exception 'invalid settlement names';
        end if;
        participant := (body ->> 'fromID')::uuid;
        if participant not in (select user_id from public.trip_members where trip_id = p_trip_id) then raise exception 'sender is not a trip member'; end if;
        if (body ->> 'toID')::uuid not in (select user_id from public.trip_members where trip_id = p_trip_id) then raise exception 'recipient is not a trip member'; end if;
        if (body ->> 'fromID')::uuid = (body ->> 'toID')::uuid then raise exception 'settlement parties must differ'; end if;
      exception when others then raise exception 'invalid settlement participants' using errcode = '22023'; end;
    end if;
    if p_storage_path is not null then raise exception 'financial row cannot have file path' using errcode = '22023'; end if;
  else
    expected_path := p_trip_id::text || '/' || actor::text || '/' || p_id::text || '.jpg';
    if (p_storage_path is not null and p_storage_path is distinct from expected_path)
      or (not p_deleted and p_storage_path is distinct from expected_path)
      or body ->> 'authorID' is distinct from actor::text
      or body ->> 'filename' is distinct from p_id::text || '.jpg' or body ->> 'thumbnailFilename' is distinct from p_id::text || '-thumb.jpg'
      or jsonb_typeof(body -> 'authorName') is distinct from 'string'
      or btrim(coalesce(body ->> 'authorName','')) = '' or length(body ->> 'authorName') > 200
      or jsonb_typeof(body -> 'caption') is distinct from 'string' or length(body ->> 'caption') > 500
      or jsonb_typeof(body -> 'sha256') is distinct from 'string' or coalesce(body ->> 'sha256','') !~ '^[0-9a-fA-F]{64}$'
      or jsonb_typeof(body -> 'thumbnailSHA256') is distinct from 'string' or coalesce(body ->> 'thumbnailSHA256','') !~ '^[0-9a-fA-F]{64}$'
      or public.trip_feature_integer(body, 'width') is null or public.trip_feature_integer(body, 'width') not between 1 and 4096
      or public.trip_feature_integer(body, 'height') is null or public.trip_feature_integer(body, 'height') not between 1 and 4096
      or jsonb_typeof(body -> 'createdAt') is distinct from 'number'
      or (body ->> 'createdAt')::numeric not between -62135769600 and 100000000000
      or (body -> 'placeID' is not null and body -> 'placeID' <> 'null'::jsonb
          and (jsonb_typeof(body -> 'placeID') is distinct from 'string'
            or not exists(select 1 from public.places where trip_id = p_trip_id and id = body ->> 'placeID' and not deleted))) then
      raise exception 'invalid photo metadata or path' using errcode = '22023';
    end if;
    if not p_deleted then
      select count(*) into file_count from storage.objects
        where bucket_id = 'trip-album' and name in (expected_path, p_trip_id::text || '/' || actor::text || '/' || p_id::text || '-thumb.jpg');
      if file_count <> 2 then raise exception 'photo objects must upload before metadata' using errcode = '22023'; end if;
      if not exists (select 1 from storage.objects where bucket_id = 'trip-album' and name = expected_path
          and metadata ->> 'mimetype' = 'image/jpeg' and coalesce((metadata ->> 'size')::bigint, 0) between 1 and 5000000)
        or not exists (select 1 from storage.objects where bucket_id = 'trip-album'
          and name = p_trip_id::text || '/' || actor::text || '/' || p_id::text || '-thumb.jpg'
          and metadata ->> 'mimetype' = 'image/jpeg' and coalesce((metadata ->> 'size')::bigint, 0) between 1 and 300000) then
        raise exception 'photo object size or content type is invalid' using errcode = '22023';
      end if;
    end if;
  end if;

  select * into current_row from public.trip_feature_entries where trip_id = p_trip_id and id = p_id for update;
  if found then
    if current_row.mutation_token = p_mutation_token then
      if current_row.owner_id <> p_owner_id or current_row.kind <> p_kind or current_row.payload <> body
        or current_row.deleted <> p_deleted or current_row.storage_path is distinct from p_storage_path then
        raise exception 'mutation token reused with different values' using errcode = '22023';
      end if;
      return to_jsonb(current_row);
    end if;
    if current_row.owner_id <> actor then raise exception 'foreign owner' using errcode = '42501'; end if;
    if current_row.kind <> p_kind then raise exception 'feature kind is immutable' using errcode = '22023'; end if;
    if p_kind = 'photo' and (
      current_row.payload ->> 'filename' is distinct from body ->> 'filename'
      or current_row.payload ->> 'thumbnailFilename' is distinct from body ->> 'thumbnailFilename'
      or current_row.payload ->> 'sha256' is distinct from body ->> 'sha256'
      or current_row.payload ->> 'thumbnailSHA256' is distinct from body ->> 'thumbnailSHA256'
      or current_row.payload ->> 'authorID' is distinct from body ->> 'authorID'
      or current_row.payload ->> 'authorName' is distinct from body ->> 'authorName'
      or current_row.payload ->> 'createdAt' is distinct from body ->> 'createdAt'
      or current_row.payload ->> 'width' is distinct from body ->> 'width'
      or current_row.payload ->> 'height' is distinct from body ->> 'height'
    ) then raise exception 'photo identity and file metadata are immutable' using errcode = '22023'; end if;
    if p_expected_version is null or p_expected_version <> current_row.version then raise exception 'feature version conflict' using errcode = '40001'; end if;
    update public.trip_feature_entries set payload = body, deleted = p_deleted,
      mutation_token = p_mutation_token, version = current_row.version + 1,
      storage_path = p_storage_path, updated_at = now()
      where trip_id = p_trip_id and id = p_id
      returning * into current_row;
  else
    if p_expected_version is not null then raise exception 'feature row missing' using errcode = '40001'; end if;
    insert into public.trip_feature_entries(trip_id,id,kind,payload,owner_id,version,mutation_token,deleted,storage_path)
      values (p_trip_id,p_id,p_kind,body,p_owner_id,1,p_mutation_token,p_deleted,p_storage_path)
      returning * into current_row;
  end if;
  return to_jsonb(current_row);
end;
$$;
revoke all on function public.commit_trip_feature(uuid, uuid, text, text, uuid, boolean, uuid, bigint, text) from public, anon;
grant execute on function public.commit_trip_feature(uuid, uuid, text, text, uuid, boolean, uuid, bigint, text) to authenticated;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('trip-album', 'trip-album', false, 5000000, array['image/jpeg'])
on conflict (id) do update set public = false, file_size_limit = 5000000, allowed_mime_types = array['image/jpeg'];

create policy "members read private trip album" on storage.objects for select to authenticated
using (bucket_id = 'trip-album' and public.is_trip_member(((storage.foldername(name))[1])::uuid));
create policy "members upload own private trip album" on storage.objects for insert to authenticated
with check (
  bucket_id = 'trip-album'
  and array_length(storage.foldername(name), 1) = 2
  and public.is_trip_member(((storage.foldername(name))[1])::uuid)
  and ((storage.foldername(name))[1])::uuid::text = (storage.foldername(name))[1]
  and (storage.foldername(name))[2] = auth.uid()::text
  and storage.filename(name) ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}(-thumb)?\.jpg$'
);

create policy "owners delete only unpublished trip album objects" on storage.objects for delete to authenticated
using (
  bucket_id = 'trip-album'
  and array_length(storage.foldername(name), 1) = 2
  and public.is_trip_member(((storage.foldername(name))[1])::uuid)
  and ((storage.foldername(name))[1])::uuid::text = (storage.foldername(name))[1]
  and (storage.foldername(name))[2] = auth.uid()::text
  and storage.filename(name) ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}(-thumb)?\.jpg$'
  and not exists (
    select 1 from public.trip_feature_entries feature
    where feature.trip_id = ((storage.foldername(name))[1])::uuid
      and feature.id = regexp_replace(storage.filename(name), '-thumb\.jpg$|\.jpg$', '', 'i')::uuid
      and feature.kind = 'photo' and feature.deleted = false
  )
);

alter publication supabase_realtime add table public.trip_feature_entries;
