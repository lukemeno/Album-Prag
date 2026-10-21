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
            or (not p_deleted
              and not exists(select 1 from public.places where trip_id = p_trip_id and id = body ->> 'placeID' and not deleted)
              and not exists(select 1 from public.trip_feature_entries prior
                where prior.trip_id = p_trip_id and prior.id = p_id
                  and prior.payload -> 'placeID' = body -> 'placeID')))) then
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
