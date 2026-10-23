create schema if not exists discovery_private;
revoke all on schema discovery_private from public, anon, authenticated;
grant usage on schema discovery_private to service_role;

create table discovery_private.catalog_cache (
  cache_key text primary key,
  catalog_version integer not null check (catalog_version > 0),
  city_qid text not null check (city_qid ~ '^Q[1-9][0-9]*$'),
  language_code text not null check (language_code ~ '^[a-z]{2,3}$'),
  payload jsonb,
  fetched_at timestamptz,
  expires_at timestamptz,
  stale_until timestamptz,
  next_refresh_at timestamptz,
  lease_token uuid,
  lease_until timestamptz,
  updated_at timestamptz not null default now(),
  check ((payload is null) = (fetched_at is null)),
  check (expires_at is null or fetched_at is not null),
  check (stale_until is null or expires_at is not null)
);

create table discovery_private.rate_limits (
  user_id uuid not null references auth.users(id) on delete cascade,
  action text not null check (action in ('search_cities', 'catalog')),
  window_start timestamptz not null,
  request_count integer not null default 0 check (request_count >= 0),
  primary key (user_id, action, window_start)
);
create index discovery_rate_limits_window_idx on discovery_private.rate_limits (window_start);

alter table discovery_private.catalog_cache enable row level security;
alter table discovery_private.catalog_cache force row level security;
alter table discovery_private.rate_limits enable row level security;
alter table discovery_private.rate_limits force row level security;
revoke all on discovery_private.catalog_cache, discovery_private.rate_limits from public, anon, authenticated;
grant select, insert, update, delete on discovery_private.catalog_cache, discovery_private.rate_limits to service_role;

create or replace function public.discovery_cache_claim(
  p_cache_key text, p_catalog_version integer, p_city_qid text, p_language_code text, p_lease_token uuid, p_now timestamptz
) returns jsonb
language plpgsql security definer
set search_path = discovery_private, pg_temp
as $$
declare cache_row discovery_private.catalog_cache%rowtype;
begin
  if auth.role() is distinct from 'service_role' then raise exception using errcode='42501', message='service role required'; end if;
  if p_cache_key is null or length(p_cache_key) > 180 or p_catalog_version <= 0 or p_city_qid !~ '^Q[1-9][0-9]*$' or p_language_code !~ '^[a-z]{2,3}$' or p_lease_token is null or p_now is null then
    raise exception using errcode='22023', message='invalid discovery cache claim';
  end if;
  insert into discovery_private.catalog_cache(cache_key,catalog_version,city_qid,language_code)
  values (p_cache_key,p_catalog_version,p_city_qid,p_language_code)
  on conflict (cache_key) do nothing;
  select * into cache_row from discovery_private.catalog_cache where cache_key=p_cache_key for update;
  if cache_row.catalog_version <> p_catalog_version or cache_row.city_qid <> p_city_qid or cache_row.language_code <> p_language_code then
    update discovery_private.catalog_cache set catalog_version=p_catalog_version,city_qid=p_city_qid,language_code=p_language_code,payload=null,fetched_at=null,expires_at=null,stale_until=null,next_refresh_at=null,lease_token=null,lease_until=null,updated_at=p_now where cache_key=p_cache_key;
    cache_row.payload := null; cache_row.expires_at := null; cache_row.stale_until := null; cache_row.lease_until := null;
  end if;
  if cache_row.payload is not null and cache_row.expires_at > p_now then return jsonb_build_object('state','fresh','payload',cache_row.payload); end if;
  if cache_row.lease_until > p_now then
    if cache_row.payload is not null and cache_row.stale_until > p_now then return jsonb_build_object('state','busy','payload',cache_row.payload); end if;
    return jsonb_build_object('state','busy','retry_after_seconds',greatest(1,ceil(extract(epoch from cache_row.lease_until-p_now))::integer));
  end if;
  if cache_row.next_refresh_at > p_now then
    if cache_row.payload is not null and cache_row.stale_until > p_now then return jsonb_build_object('state','stale','payload',cache_row.payload); end if;
    return jsonb_build_object('state','busy','retry_after_seconds',greatest(1,ceil(extract(epoch from cache_row.next_refresh_at-p_now))::integer));
  end if;
  update discovery_private.catalog_cache set lease_token=p_lease_token,lease_until=p_now+interval '25 seconds',updated_at=p_now where cache_key=p_cache_key;
  if cache_row.payload is not null and cache_row.stale_until > p_now then return jsonb_build_object('state','claimed','payload',cache_row.payload); end if;
  return jsonb_build_object('state','claimed');
end;
$$;

create or replace function public.discovery_cache_complete(
  p_cache_key text, p_lease_token uuid, p_payload jsonb, p_fetched_at timestamptz, p_expires_at timestamptz, p_stale_until timestamptz
) returns boolean
language plpgsql security definer
set search_path = discovery_private, pg_temp
as $$
begin
  if auth.role() is distinct from 'service_role' then raise exception using errcode='42501', message='service role required'; end if;
  if p_payload is null or p_fetched_at is null or p_expires_at is null or p_stale_until is null or p_expires_at <> p_fetched_at+interval '168 hours' or p_stale_until <> p_fetched_at+interval '720 hours' then
    raise exception using errcode='22023', message='invalid discovery cache payload';
  end if;
  update discovery_private.catalog_cache set payload=p_payload,fetched_at=p_fetched_at,expires_at=p_expires_at,stale_until=p_stale_until,next_refresh_at=p_fetched_at+interval '1 hour',lease_token=null,lease_until=null,updated_at=p_fetched_at
  where cache_key=p_cache_key and lease_token=p_lease_token and lease_until > p_fetched_at;
  return found;
end;
$$;

create or replace function public.discovery_cache_release(p_cache_key text, p_lease_token uuid, p_next_refresh_at timestamptz) returns boolean
language plpgsql security definer
set search_path = discovery_private, pg_temp
as $$
begin
  if auth.role() is distinct from 'service_role' then raise exception using errcode='42501', message='service role required'; end if;
  if p_next_refresh_at is null then raise exception using errcode='22023', message='invalid retry time'; end if;
  update discovery_private.catalog_cache set lease_token=null,lease_until=null,next_refresh_at=p_next_refresh_at,updated_at=now()
  where cache_key=p_cache_key and lease_token=p_lease_token;
  return found;
end;
$$;

create or replace function public.discovery_rate_reserve(p_user_id uuid, p_action text, p_limit integer, p_now timestamptz) returns jsonb
language plpgsql security definer
set search_path = discovery_private, pg_temp
as $$
declare bucket timestamptz; total integer;
begin
  if auth.role() is distinct from 'service_role' then raise exception using errcode='42501', message='service role required'; end if;
  if p_user_id is null or p_action not in ('search_cities','catalog') or p_limit not in (3,10) or p_now is null then raise exception using errcode='22023', message='invalid discovery rate reservation'; end if;
  bucket := date_trunc('minute',p_now);
  insert into discovery_private.rate_limits(user_id,action,window_start,request_count) values(p_user_id,p_action,bucket,1)
  on conflict(user_id,action,window_start) do update set request_count=discovery_private.rate_limits.request_count+1
  returning request_count into total;
  delete from discovery_private.rate_limits where window_start < p_now-interval '2 days';
  if total > p_limit then return jsonb_build_object('ok',false,'retry_after_seconds',greatest(1,60-extract(second from p_now)::integer)); end if;
  return jsonb_build_object('ok',true);
end;
$$;

revoke all on function public.discovery_cache_claim(text,integer,text,text,uuid,timestamptz) from public, anon, authenticated;
revoke all on function public.discovery_cache_complete(text,uuid,jsonb,timestamptz,timestamptz,timestamptz) from public, anon, authenticated;
revoke all on function public.discovery_cache_release(text,uuid,timestamptz) from public, anon, authenticated;
revoke all on function public.discovery_rate_reserve(uuid,text,integer,timestamptz) from public, anon, authenticated;
grant execute on function public.discovery_cache_claim(text,integer,text,text,uuid,timestamptz) to service_role;
grant execute on function public.discovery_cache_complete(text,uuid,jsonb,timestamptz,timestamptz,timestamptz) to service_role;
grant execute on function public.discovery_cache_release(text,uuid,timestamptz) to service_role;
grant execute on function public.discovery_rate_reserve(uuid,text,integer,timestamptz) to service_role;
