-- AF-2 automatic place-photo cache and distributed upstream budgets.
-- This migration is independent of discovery/catalog migrations.
create schema if not exists place_photo_private;
revoke all on schema place_photo_private from public, anon, authenticated;

create table if not exists place_photo_private.public_cache (
  cache_key text primary key check (cache_key ~ '^[0-9a-f]{64}$'),
  identity_protocol text not null check (identity_protocol ~ '^[a-z0-9_-]{1,32}$'),
  pipeline_version integer not null default 1 check (pipeline_version > 0),
  payload jsonb not null default '[]'::jsonb check (jsonb_typeof(payload) = 'array'),
  fetched_at timestamptz,
  expires_at timestamptz,
  stale_until timestamptz,
  lease_token uuid,
  lease_until timestamptz,
  updated_at timestamptz not null default now()
);
create index if not exists place_photo_cache_expiry_idx on place_photo_private.public_cache (stale_until);

create table if not exists place_photo_private.private_cache (
  scope_key text not null check (length(scope_key) between 6 and 200),
  user_id uuid,
  trip_id uuid,
  place_id text not null check (length(place_id) between 1 and 128),
  revision text not null default '1' check (length(revision) between 1 and 64),
  payload jsonb not null default '[]'::jsonb check (jsonb_typeof(payload) = 'array'),
  expires_at timestamptz,
  lease_token uuid,
  lease_until timestamptz,
  updated_at timestamptz not null default now(),
  primary key (scope_key, place_id, revision)
);
create index if not exists place_photo_private_cache_expiry_idx on place_photo_private.private_cache (expires_at);

create table if not exists place_photo_private.resolution_runs (
  resolution_id uuid primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  trip_id uuid,
  cache_key text check (cache_key is null or cache_key ~ '^[0-9a-f]{64}$'),
  manual boolean not null default false,
  created_at timestamptz not null default now()
);
create index if not exists place_photo_runs_user_idx on place_photo_private.resolution_runs (user_id, created_at desc);
create index if not exists place_photo_runs_trip_idx on place_photo_private.resolution_runs (trip_id, created_at desc);

create table if not exists place_photo_private.upstream_calls (
  resolution_id uuid not null references place_photo_private.resolution_runs(resolution_id) on delete cascade,
  sequence integer not null check (sequence between 1 and 12),
  provider text not null check (provider in ('wikimedia','google')),
  created_at timestamptz not null default now(),
  primary key (resolution_id, sequence)
);
create index if not exists place_photo_calls_created_idx on place_photo_private.upstream_calls (created_at desc);
create table if not exists place_photo_private.upstream_lease (
  singleton boolean primary key default true check (singleton),
  resolution_id uuid,
  sequence integer,
  lease_until timestamptz
);

alter table place_photo_private.public_cache enable row level security;
alter table place_photo_private.private_cache enable row level security;
alter table place_photo_private.resolution_runs enable row level security;
alter table place_photo_private.upstream_calls enable row level security;
revoke all on all tables in schema place_photo_private from public, anon, authenticated;
grant usage on schema place_photo_private to service_role;
grant select, insert, update, delete on all tables in schema place_photo_private to service_role;


create or replace function public.place_photo_private_cache_claim(p_user_id uuid,p_trip_id uuid,p_place_id text,p_revision text,p_lease_token uuid,p_now timestamptz default now())
returns jsonb language plpgsql security definer set search_path=public,place_photo_private,pg_temp as $$
declare row place_photo_private.private_cache%rowtype;
        scope text := case when p_trip_id is null then 'user:'||p_user_id::text else 'trip:'||p_trip_id::text end;
begin
  if auth.role() is distinct from 'service_role' or p_user_id is null or p_place_id is null or length(p_place_id) not between 1 and 128 or p_lease_token is null then raise exception using errcode='22023',message='invalid private cache claim'; end if;
  if p_trip_id is not null and not exists(select 1 from public.trip_members where trip_id=p_trip_id and user_id=p_user_id) then return jsonb_build_object('state','forbidden','payload','[]'::jsonb); end if;
  insert into place_photo_private.private_cache(scope_key,user_id,trip_id,place_id,revision) values(scope,p_user_id,p_trip_id,p_place_id,coalesce(nullif(p_revision,''),'1')) on conflict do nothing;
  select * into row from place_photo_private.private_cache where scope_key=scope and place_id=p_place_id and revision=coalesce(nullif(p_revision,''),'1') for update;
  if row.expires_at is not null and row.expires_at > p_now then return jsonb_build_object('state','fresh','payload',row.payload); end if;
  if row.lease_until is not null and row.lease_until > p_now and row.lease_token is distinct from p_lease_token then return jsonb_build_object('state','busy','payload','[]'::jsonb,'retry_after_seconds',greatest(1,ceil(extract(epoch from row.lease_until-p_now))::integer)); end if;
  update place_photo_private.private_cache set lease_token=p_lease_token,lease_until=p_now+interval '2 minutes',updated_at=p_now where scope_key=scope and place_id=p_place_id and revision=coalesce(nullif(p_revision,''),'1');
  return jsonb_build_object('state','claimed','payload',row.payload);
end $$;
create or replace function public.place_photo_private_cache_complete(p_user_id uuid,p_trip_id uuid,p_place_id text,p_revision text,p_lease_token uuid,p_payload jsonb,p_expires_at timestamptz)
returns boolean language plpgsql security definer set search_path=public,place_photo_private,pg_temp as $$
declare scope text := case when p_trip_id is null then 'user:'||p_user_id::text else 'trip:'||p_trip_id::text end;
begin
  if auth.role() is distinct from 'service_role' or jsonb_typeof(p_payload) <> 'array' or p_expires_at <= now() then raise exception using errcode='22023',message='invalid private cache payload'; end if;
  update place_photo_private.private_cache set payload=p_payload,expires_at=p_expires_at,lease_token=null,lease_until=null,updated_at=now() where scope_key=scope and place_id=p_place_id and revision=coalesce(nullif(p_revision,''),'1') and lease_token=p_lease_token;
  return found;
end $$;
create or replace function public.place_photo_private_cache_release(p_user_id uuid,p_trip_id uuid,p_place_id text,p_revision text,p_lease_token uuid)
returns boolean language plpgsql security definer set search_path=public,place_photo_private,pg_temp as $$
declare scope text := case when p_trip_id is null then 'user:'||p_user_id::text else 'trip:'||p_trip_id::text end;
begin
  if auth.role() is distinct from 'service_role' then raise exception using errcode='42501',message='service role required'; end if;
  update place_photo_private.private_cache set lease_token=null,lease_until=null,updated_at=now() where scope_key=scope and place_id=p_place_id and revision=coalesce(nullif(p_revision,''),'1') and lease_token=p_lease_token;
  return found;
end $$;

create or replace function public.place_photo_cache_claim(p_cache_key text, p_identity_protocol text, p_pipeline_version integer, p_lease_token uuid, p_now timestamptz default now())
returns jsonb language plpgsql security definer set search_path=public,place_photo_private,pg_temp as $$
declare row place_photo_private.public_cache%rowtype;
begin
  if auth.role() is distinct from 'service_role' or p_cache_key is null or p_cache_key !~ '^[0-9a-f]{64}$' or p_lease_token is null then raise exception using errcode='22023', message='invalid cache claim'; end if;
  insert into place_photo_private.public_cache(cache_key,identity_protocol,pipeline_version) values(p_cache_key,lower(p_identity_protocol),p_pipeline_version) on conflict do nothing;
  select * into row from place_photo_private.public_cache where cache_key=p_cache_key for update;
  if row.pipeline_version <> p_pipeline_version or row.identity_protocol <> lower(p_identity_protocol) then
    update place_photo_private.public_cache set identity_protocol=lower(p_identity_protocol),pipeline_version=p_pipeline_version,payload='[]',fetched_at=null,expires_at=null,stale_until=null,lease_token=null,lease_until=null,updated_at=p_now where cache_key=p_cache_key returning * into row;
  end if;
  if row.expires_at is not null and row.expires_at > p_now then return jsonb_build_object('state','fresh','payload',row.payload); end if;
  if row.lease_until is not null and row.lease_until > p_now and row.lease_token is distinct from p_lease_token then return jsonb_build_object('state','busy','payload',row.payload); end if;
  update place_photo_private.public_cache set lease_token=p_lease_token,lease_until=p_now+interval '2 minutes',updated_at=p_now where cache_key=p_cache_key returning * into row;
  return jsonb_build_object('state','claimed','payload',row.payload);
end $$;

create or replace function public.place_photo_cache_complete(p_cache_key text,p_lease_token uuid,p_payload jsonb,p_fetched_at timestamptz,p_expires_at timestamptz,p_stale_until timestamptz)
returns boolean language plpgsql security definer set search_path=public,place_photo_private,pg_temp as $$
begin
  if auth.role() is distinct from 'service_role' or jsonb_typeof(p_payload) <> 'array' or p_expires_at <= p_fetched_at or p_stale_until < p_expires_at then raise exception using errcode='22023',message='invalid cache payload'; end if;
  update place_photo_private.public_cache set payload=p_payload,fetched_at=p_fetched_at,expires_at=p_expires_at,stale_until=p_stale_until,lease_token=null,lease_until=null,updated_at=p_fetched_at where cache_key=p_cache_key and lease_token=p_lease_token;
  return found;
end $$;
create or replace function public.place_photo_cache_release(p_cache_key text,p_lease_token uuid)
returns boolean language plpgsql security definer set search_path=public,place_photo_private,pg_temp as $$
begin
  if auth.role() is distinct from 'service_role' then raise exception using errcode='42501',message='service role required'; end if;
  update place_photo_private.public_cache set lease_token=null,lease_until=null,updated_at=now() where cache_key=p_cache_key and lease_token=p_lease_token;
  return found;
end $$;

create or replace function public.place_photo_reserve_run(p_resolution_id uuid,p_user_id uuid,p_trip_id uuid,p_cache_key text,p_manual boolean default false,p_now timestamptz default now())
returns jsonb language plpgsql security definer set search_path=public,place_photo_private,pg_temp as $$
declare oldest timestamptz; count_hour integer; count_day integer; count_trip integer; count_manual integer;
begin
  if auth.role() is distinct from 'service_role' or p_resolution_id is null or p_user_id is null then raise exception using errcode='42501',message='service role required'; end if;
  perform pg_advisory_xact_lock(hashtextextended('place-photo-run-user:'||p_user_id::text,0));
  if p_trip_id is not null then perform pg_advisory_xact_lock(hashtextextended('place-photo-run-trip:'||p_trip_id::text,0)); end if;
  if exists(select 1 from place_photo_private.resolution_runs where resolution_id=p_resolution_id) then return jsonb_build_object('ok',true,'reused',true); end if;
  if p_trip_id is not null and not exists(select 1 from public.trip_members where trip_id=p_trip_id and user_id=p_user_id) then return jsonb_build_object('ok',false,'code','forbidden_trip'); end if;
  select count(*)::integer,min(created_at) into count_hour,oldest from place_photo_private.resolution_runs where user_id=p_user_id and created_at >= p_now-interval '1 hour';
  if count_hour >= 30 then return jsonb_build_object('ok',false,'code','user_hour_limit','retry_after_seconds',greatest(1,ceil(extract(epoch from oldest+interval '1 hour'-p_now))::integer)); end if;
  select count(*)::integer,min(created_at) into count_day,oldest from place_photo_private.resolution_runs where user_id=p_user_id and created_at >= p_now-interval '1 day';
  if count_day >= 100 then return jsonb_build_object('ok',false,'code','user_day_limit','retry_after_seconds',greatest(1,ceil(extract(epoch from oldest+interval '1 day'-p_now))::integer)); end if;
  if p_trip_id is not null then
    select count(*)::integer into count_trip from place_photo_private.resolution_runs where trip_id=p_trip_id and created_at >= p_now-interval '1 day';
    if count_trip >= 150 then return jsonb_build_object('ok',false,'code','trip_day_limit','retry_after_seconds',3600); end if;
  end if;
  if p_manual and p_cache_key is not null then
    select count(*)::integer into count_manual from place_photo_private.resolution_runs where user_id=p_user_id and cache_key=p_cache_key and manual and created_at >= p_now-interval '1 day';
    if count_manual >= 3 then return jsonb_build_object('ok',false,'code','manual_day_limit','retry_after_seconds',3600); end if;
  end if;
  insert into place_photo_private.resolution_runs(resolution_id,user_id,trip_id,cache_key,manual,created_at) values(p_resolution_id,p_user_id,p_trip_id,p_cache_key,p_manual,p_now);
  return jsonb_build_object('ok',true,'reused',false);
end $$;

create or replace function public.place_photo_reserve_upstream(p_resolution_id uuid,p_provider text,p_now timestamptz default now())
returns jsonb language plpgsql security definer set search_path=public,place_photo_private,pg_temp as $$
declare seq integer; oldest timestamptz; total_min integer; total_day integer;
begin
  if auth.role() is distinct from 'service_role' or p_provider not in ('wikimedia','google') then raise exception using errcode='22023',message='invalid upstream'; end if;
  if not exists(select 1 from place_photo_private.resolution_runs where resolution_id=p_resolution_id) then return jsonb_build_object('ok',false,'code','run_missing'); end if;
  perform pg_advisory_xact_lock(hashtextextended('place-photo-upstream-global',0));
  if exists(select 1 from place_photo_private.upstream_lease where singleton and lease_until > p_now) then
    return jsonb_build_object('ok',false,'code','active_request','retry_after_seconds',greatest(1,ceil(extract(epoch from (select lease_until from place_photo_private.upstream_lease where singleton)-p_now))::integer));
  end if;
  select count(*)::integer,min(created_at) into total_min,oldest from place_photo_private.upstream_calls where created_at >= p_now-interval '1 minute';
  if total_min >= 10 then return jsonb_build_object('ok',false,'code','global_rate_limit','retry_after_seconds',greatest(1,ceil(extract(epoch from oldest+interval '1 minute'-p_now))::integer)); end if;
  select count(*)::integer into total_day from place_photo_private.upstream_calls where created_at >= p_now-interval '1 day';
  if total_day >= 1000 then return jsonb_build_object('ok',false,'code','global_day_limit','retry_after_seconds',3600); end if;
  select coalesce(max(sequence),0)+1 into seq from place_photo_private.upstream_calls where resolution_id=p_resolution_id;
  if seq > 12 then return jsonb_build_object('ok',false,'code','resolution_limit','retry_after_seconds',3600); end if;
  insert into place_photo_private.upstream_calls(resolution_id,sequence,provider,created_at) values(p_resolution_id,seq,p_provider,p_now);
  insert into place_photo_private.upstream_lease(singleton,resolution_id,sequence,lease_until) values(true,p_resolution_id,seq,p_now+interval '30 seconds') on conflict(singleton) do update set resolution_id=excluded.resolution_id,sequence=excluded.sequence,lease_until=excluded.lease_until;
  return jsonb_build_object('ok',true,'sequence',seq);
end $$;

create or replace function public.place_photo_release_upstream(p_resolution_id uuid,p_sequence integer)
returns boolean language plpgsql security definer set search_path=public,place_photo_private,pg_temp as $$
begin
  if auth.role() is distinct from 'service_role' then raise exception using errcode='42501',message='service role required'; end if;
  update place_photo_private.upstream_lease set resolution_id=null,sequence=null,lease_until=null where singleton and resolution_id=p_resolution_id and sequence=p_sequence;
  return found;
end $$;

create or replace function public.place_photo_prune()
returns void language plpgsql security definer set search_path=public,place_photo_private,place_enrichment_private,pg_temp as $$
begin
  if auth.role() is distinct from 'service_role' then raise exception using errcode='42501',message='service role required'; end if;
  delete from place_photo_private.upstream_calls where created_at < now()-interval '8 days';
  delete from place_photo_private.resolution_runs where created_at < now()-interval '8 days';
  delete from place_photo_private.public_cache where stale_until < now();
  delete from place_photo_private.private_cache where expires_at < now()-interval '30 days';
  update place_photo_private.public_cache set lease_token=null,lease_until=null where lease_until < now();
  update place_photo_private.private_cache set lease_token=null,lease_until=null where lease_until < now();
  update place_photo_private.upstream_lease set resolution_id=null,sequence=null,lease_until=null where singleton and lease_until < now();
  update place_enrichment_private.jobs set snapshot='{}'::jsonb where status in ('ready','needs_review','not_found','failed') and updated_at < now()-interval '7 days';
  delete from place_enrichment_private.jobs where status in ('ready','needs_review','not_found','failed') and updated_at < now()-interval '30 days';
  delete from place_photo_private.public_cache where cache_key in (select cache_key from place_photo_private.public_cache order by updated_at asc offset 100000);
end $$;

revoke all on function public.place_photo_cache_claim(text,text,integer,uuid,timestamptz) from public,anon,authenticated;
revoke all on function public.place_photo_cache_complete(text,uuid,jsonb,timestamptz,timestamptz,timestamptz) from public,anon,authenticated;
revoke all on function public.place_photo_cache_release(text,uuid) from public,anon,authenticated;
revoke all on function public.place_photo_reserve_run(uuid,uuid,uuid,text,boolean,timestamptz) from public,anon,authenticated;
revoke all on function public.place_photo_reserve_upstream(uuid,text,timestamptz) from public,anon,authenticated;
revoke all on function public.place_photo_prune() from public,anon,authenticated;
revoke all on function public.place_photo_release_upstream(uuid,integer) from public,anon,authenticated;
revoke all on function public.place_photo_private_cache_claim(uuid,uuid,text,text,uuid,timestamptz) from public,anon,authenticated;
revoke all on function public.place_photo_private_cache_complete(uuid,uuid,text,text,uuid,jsonb,timestamptz) from public,anon,authenticated;
revoke all on function public.place_photo_private_cache_release(uuid,uuid,text,text,uuid) from public,anon,authenticated;
grant execute on function public.place_photo_cache_claim(text,text,integer,uuid,timestamptz) to service_role;
grant execute on function public.place_photo_cache_complete(text,uuid,jsonb,timestamptz,timestamptz,timestamptz) to service_role;
grant execute on function public.place_photo_cache_release(text,uuid) to service_role;
grant execute on function public.place_photo_reserve_run(uuid,uuid,uuid,text,boolean,timestamptz) to service_role;
grant execute on function public.place_photo_reserve_upstream(uuid,text,timestamptz) to service_role;
grant execute on function public.place_photo_prune() to service_role;
grant execute on function public.place_photo_release_upstream(uuid,integer) to service_role;
grant execute on function public.place_photo_private_cache_claim(uuid,uuid,text,text,uuid,timestamptz) to service_role;
grant execute on function public.place_photo_private_cache_complete(uuid,uuid,text,text,uuid,jsonb,timestamptz) to service_role;
grant execute on function public.place_photo_private_cache_release(uuid,uuid,text,text,uuid) to service_role;

do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.schedule('place-photo-prune', '17 3 * * *', 'select public.place_photo_prune()');
  end if;
exception when unique_violation then null;
end $$;

-- Google enrichment uses the same run and HTTP budgets. Existing monthly Google
-- accounting remains intact for compatibility and billing visibility.
create or replace function public.place_enrichment_reserve_google(p_job_id uuid,p_lease_token uuid)
returns jsonb language plpgsql security definer set search_path=public,place_enrichment_private,place_photo_private,pg_temp as $$
declare job place_enrichment_private.jobs%rowtype; month date := date_trunc('month',now() at time zone 'UTC')::date; usage_row place_enrichment_private.google_usage_monthly%rowtype; hour_count integer; common jsonb;
begin
  if auth.role() is distinct from 'service_role' then raise exception using errcode='42501', message='service role required'; end if;
  select * into job from place_enrichment_private.jobs where job_id=p_job_id and status='processing' and lease_token=p_lease_token for update;
  if not found then return jsonb_build_object('ok',false,'code','lease_expired'); end if;
  if exists(select 1 from place_enrichment_private.google_usage_calls where job_id=p_job_id and lease_token=p_lease_token) then return jsonb_build_object('ok',false,'code','duplicate_reservation'); end if;
  common := public.place_photo_reserve_run(job.job_id,job.user_id,job.trip_id,null,false,now());
  if not coalesce((common->>'ok')::boolean,false) then return common; end if;
  common := public.place_photo_reserve_upstream(job.job_id,'google',now());
  if not coalesce((common->>'ok')::boolean,false) then return common; end if;
  insert into place_enrichment_private.google_usage_monthly(month_start) values(month) on conflict do nothing;
  select * into usage_row from place_enrichment_private.google_usage_monthly where month_start=month for update;
  select count(*)::integer into hour_count from place_enrichment_private.google_usage_calls where user_id=job.user_id and created_at >= now()-interval '1 hour';
  if usage_row.call_count >= 1000 then return jsonb_build_object('ok',false,'code','monthly_limit'); end if;
  if hour_count >= 100 then return jsonb_build_object('ok',false,'code','rate_limit'); end if;
  insert into place_enrichment_private.google_usage_calls(job_id,lease_token,user_id) values(p_job_id,p_lease_token,job.user_id);
  update place_enrichment_private.google_usage_monthly set call_count=call_count+1 where month_start=month;
  return jsonb_build_object('ok',true,'call_count',usage_row.call_count+1);
end $$;
revoke all on function public.place_enrichment_reserve_google(uuid,uuid) from public,anon,authenticated;
grant execute on function public.place_enrichment_reserve_google(uuid,uuid) to service_role;
