create schema if not exists place_enrichment_private;
revoke all on schema place_enrichment_private from public, anon, authenticated;

create table place_enrichment_private.jobs (
  job_id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  trip_id uuid,
  request_key text not null check (request_key ~ '^[0-9a-f]{64}$'),
  snapshot jsonb not null,
  status text not null default 'queued' check (status in ('queued','processing','ready','needs_review','not_found','retry_wait','failed')),
  result jsonb,
  attempts integer not null default 0 check (attempts between 0 and 3),
  ready_at timestamptz not null default now(),
  lease_until timestamptz,
  lease_token uuid,
  error_code text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, request_key)
);
create index place_enrichment_jobs_due_idx on place_enrichment_private.jobs (ready_at, created_at)
  where status in ('queued','retry_wait','processing');
create index place_enrichment_jobs_user_created_idx on place_enrichment_private.jobs (user_id, created_at desc);

create table place_enrichment_private.google_usage_monthly (
  month_start date primary key,
  call_count integer not null default 0 check (call_count between 0 and 1000)
);
create table place_enrichment_private.google_usage_calls (
  job_id uuid not null references place_enrichment_private.jobs(job_id) on delete cascade,
  lease_token uuid not null,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (job_id, lease_token)
);
create index place_enrichment_google_user_hour_idx on place_enrichment_private.google_usage_calls (user_id, created_at desc);
create table place_enrichment_private.worker_config (
  singleton boolean primary key default true check (singleton),
  function_url text,
  enabled boolean not null default false
);
insert into place_enrichment_private.worker_config(singleton) values(true) on conflict do nothing;
revoke all on place_enrichment_private.worker_config from public, anon, authenticated, service_role;
alter table place_enrichment_private.jobs enable row level security;
alter table place_enrichment_private.google_usage_monthly enable row level security;
alter table place_enrichment_private.google_usage_calls enable row level security;
revoke all on all tables in schema place_enrichment_private from public, anon, authenticated;
grant usage on schema place_enrichment_private to service_role;
grant select, insert, update, delete on all tables in schema place_enrichment_private to service_role;

create table if not exists place_enrichment_private.worker_secret_ref (
  singleton boolean primary key default true check (singleton),
  secret_id uuid not null,
  token_hash text not null
);
revoke all on place_enrichment_private.worker_secret_ref from public, anon, authenticated, service_role;
do $$
declare secret_value text := encode(extensions.gen_random_bytes(32), 'hex');
        secret_id uuid;
begin
  if not exists (select 1 from place_enrichment_private.worker_secret_ref where singleton) then
    select vault.create_secret(secret_value, 'place-enrichment-worker-token') into secret_id;
    insert into place_enrichment_private.worker_secret_ref(singleton, secret_id, token_hash)
      values (true, secret_id, encode(extensions.digest(secret_value, 'sha256'), 'hex'));
  end if;
end $$;

create or replace function public.place_enrichment_job_json(job place_enrichment_private.jobs)
returns jsonb language sql stable set search_path = public, place_enrichment_private, pg_temp as $$
  select jsonb_build_object('job_id', job.job_id, 'request_key', job.request_key, 'status', job.status,
    'result', job.result, 'retry_after_seconds', case when job.status in ('retry_wait','processing') then greatest(0,ceil(extract(epoch from coalesce(job.lease_until,job.ready_at)-now()))::integer) else null end,
    'error_code', job.error_code)
$$;

create or replace function public.place_enrichment_enqueue(p_user_id uuid, p_trip_id uuid, p_request_key text, p_snapshot jsonb)
returns jsonb language plpgsql security definer set search_path = public, place_enrichment_private, pg_temp as $$
declare job place_enrichment_private.jobs%rowtype;
begin
  if auth.role() is distinct from 'service_role' then raise exception using errcode='42501', message='service role required'; end if;
  if p_user_id is null or p_request_key is null or p_request_key !~ '^[0-9a-f]{64}$' or jsonb_typeof(p_snapshot) <> 'object' then raise exception using errcode='22023', message='invalid job'; end if;
  perform pg_advisory_xact_lock(hashtextextended(p_user_id::text, 0));
  select * into job from place_enrichment_private.jobs where user_id=p_user_id and request_key=p_request_key;
  if found then return public.place_enrichment_job_json(job); end if;
  if (select count(*) from place_enrichment_private.jobs where user_id=p_user_id and status in ('queued','processing','retry_wait')) >= 100 then
    raise exception using errcode='54000', message='pending job limit reached';
  end if;
  insert into place_enrichment_private.jobs(user_id,trip_id,request_key,snapshot)
    values(p_user_id,p_trip_id,p_request_key,p_snapshot) on conflict(user_id,request_key) do nothing;
  select * into job from place_enrichment_private.jobs where user_id=p_user_id and request_key=p_request_key;
  return public.place_enrichment_job_json(job);
end $$;

create or replace function public.place_enrichment_status(p_user_id uuid, p_job_id uuid)
returns jsonb language plpgsql security definer set search_path = public, place_enrichment_private, pg_temp as $$
declare job place_enrichment_private.jobs%rowtype;
begin
  if auth.role() is distinct from 'service_role' then raise exception using errcode='42501', message='service role required'; end if;
  select * into job from place_enrichment_private.jobs where job_id=p_job_id and user_id=p_user_id;
  if not found then return null; end if;
  return public.place_enrichment_job_json(job);
end $$;

create or replace function public.place_enrichment_retry(p_user_id uuid, p_job_id uuid)
returns jsonb language plpgsql security definer set search_path = public, place_enrichment_private, pg_temp as $$
declare job place_enrichment_private.jobs%rowtype;
begin
  if auth.role() is distinct from 'service_role' then raise exception using errcode='42501', message='service role required'; end if;
  select * into job from place_enrichment_private.jobs where job_id=p_job_id and user_id=p_user_id for update;
  if not found then return null; end if;
  if job.status in ('failed','not_found') then
    update place_enrichment_private.jobs set status='queued', attempts=0, ready_at=now(), lease_until=null, lease_token=null, error_code=null, result=null, updated_at=now()
      where job_id=p_job_id returning * into job;
  elsif job.status in ('ready','needs_review') then
    return jsonb_build_object('job_id',job.job_id,'request_key',job.request_key,'status',job.status,'result',job.result,'retry_after_seconds',null,'error_code','not_retryable');
  end if;
  return public.place_enrichment_job_json(job);
end $$;

create or replace function public.place_enrichment_claim(p_limit integer default 5)
returns setof jsonb language plpgsql security definer set search_path = public, place_enrichment_private, pg_temp as $$
declare active_leases integer;
begin
  if auth.role() is distinct from 'service_role' then raise exception using errcode='42501', message='service role required'; end if;
  perform pg_advisory_xact_lock(hashtext('place_enrichment_worker_claim'));
  update place_enrichment_private.jobs set status='failed', lease_until=null, lease_token=null, error_code='attempts_exhausted', updated_at=now()
    where status='processing' and lease_until < now() and attempts >= 3;
  select count(*)::integer into active_leases from place_enrichment_private.jobs where status='processing' and lease_until>now();
  if active_leases >= 2 then return; end if;
  return query with picked as (
    select j.job_id from place_enrichment_private.jobs j
    where j.attempts < 3 and ((j.status in ('queued','retry_wait') and j.ready_at <= now()) or (j.status='processing' and j.lease_until < now()))
    order by j.ready_at, j.created_at for update skip locked limit least(greatest(p_limit,1),2-active_leases)
  ), updated as (
    update place_enrichment_private.jobs j set status='processing', attempts=j.attempts+1,
      lease_until=now()+interval '3 minutes', lease_token=gen_random_uuid(), error_code=null, updated_at=now()
    from picked where j.job_id=picked.job_id returning j.*
  ) select jsonb_build_object('job_id',u.job_id,'user_id',u.user_id,'snapshot',u.snapshot,'attempts',u.attempts,'lease_token',u.lease_token) from updated u;
end $$;

create or replace function public.place_enrichment_reserve_google(p_job_id uuid, p_lease_token uuid)
returns jsonb language plpgsql security definer set search_path = public, place_enrichment_private, pg_temp as $$
declare job place_enrichment_private.jobs%rowtype; month date := date_trunc('month',now() at time zone 'UTC')::date; usage_row place_enrichment_private.google_usage_monthly%rowtype; hour_count integer;
begin
  if auth.role() is distinct from 'service_role' then raise exception using errcode='42501', message='service role required'; end if;
  select * into job from place_enrichment_private.jobs where job_id=p_job_id and status='processing' and lease_token=p_lease_token for update;
  if not found then return jsonb_build_object('ok',false,'code','lease_expired'); end if;
  if exists(select 1 from place_enrichment_private.google_usage_calls where job_id=p_job_id and lease_token=p_lease_token) then return jsonb_build_object('ok',false,'code','duplicate_reservation'); end if;
  insert into place_enrichment_private.google_usage_monthly(month_start) values(month) on conflict do nothing;
  select * into usage_row from place_enrichment_private.google_usage_monthly where month_start=month for update;
  select count(*)::integer into hour_count from place_enrichment_private.google_usage_calls where user_id=job.user_id and created_at >= now()-interval '1 hour';
  if usage_row.call_count >= 1000 then return jsonb_build_object('ok',false,'code','monthly_limit'); end if;
  if hour_count >= 100 then return jsonb_build_object('ok',false,'code','rate_limit'); end if;
  insert into place_enrichment_private.google_usage_calls(job_id,lease_token,user_id) values(p_job_id,p_lease_token,job.user_id);
  update place_enrichment_private.google_usage_monthly set call_count=call_count+1 where month_start=month;
  return jsonb_build_object('ok',true,'call_count',usage_row.call_count+1);
end $$;

create or replace function public.place_enrichment_complete(p_job_id uuid, p_lease_token uuid, p_result jsonb, p_status text default 'ready')
returns boolean language plpgsql security definer set search_path = public, place_enrichment_private, pg_temp as $$
begin
  if auth.role() is distinct from 'service_role' then raise exception using errcode='42501', message='service role required'; end if;
  if p_status not in ('ready','needs_review','not_found') or jsonb_typeof(p_result) <> 'object' then raise exception using errcode='22023', message='invalid result'; end if;
  update place_enrichment_private.jobs set status=p_status,result=p_result,lease_until=null,lease_token=null,error_code=null,updated_at=now()
    where job_id=p_job_id and status='processing' and lease_token=p_lease_token;
  return found;
end $$;

create or replace function public.place_enrichment_fail(p_job_id uuid,p_lease_token uuid,p_error_code text,p_retryable boolean)
returns boolean language plpgsql security definer set search_path = public, place_enrichment_private, pg_temp as $$
declare job place_enrichment_private.jobs%rowtype;
begin
  if auth.role() is distinct from 'service_role' then raise exception using errcode='42501', message='service role required'; end if;
  select * into job from place_enrichment_private.jobs where job_id=p_job_id and status='processing' and lease_token=p_lease_token for update;
  if not found then return false; end if;
  update place_enrichment_private.jobs set status=case when p_retryable and job.attempts < 3 then 'retry_wait' else 'failed' end,
    ready_at=now()+make_interval(secs => least(3600,60*power(2,job.attempts-1)::integer)), lease_until=null,lease_token=null,
    error_code=left(coalesce(p_error_code,'provider_unavailable'),80),updated_at=now() where job_id=p_job_id;
  return true;
end $$;

create or replace function public.place_enrichment_verify_worker_token(p_token text)
returns boolean language sql security definer set search_path = public, place_enrichment_private, pg_temp as $$
  select auth.role()='service_role' and p_token is not null and exists(
    select 1 from place_enrichment_private.worker_secret_ref where singleton and token_hash=encode(extensions.digest(p_token,'sha256'),'hex'))
$$;

create or replace function public.place_enrichment_cron_tick()
returns bigint language plpgsql security definer set search_path = public, place_enrichment_private, vault, pg_temp as $$
declare config place_enrichment_private.worker_config%rowtype; token text; request_id bigint;
begin
  select * into config from place_enrichment_private.worker_config where singleton;
  if not found or not config.enabled or config.function_url is null or config.function_url !~ '^https://[^/]+/functions/v1/place-enrichment-worker/?$' then return null; end if;
  if not exists(select 1 from place_enrichment_private.jobs where (status in ('queued','retry_wait') and ready_at<=now()) or (status='processing' and lease_until<now())) then return null; end if;
  select s.decrypted_secret into token from place_enrichment_private.worker_secret_ref r join vault.decrypted_secrets s on s.id=r.secret_id where r.singleton;
  if token is null then return null; end if;
  select net.http_post(url:=config.function_url,headers:=jsonb_build_object('Content-Type','application/json','X-Place-Enrichment-Worker',token),body:='{}'::jsonb,timeout_milliseconds:=10000) into request_id;
  return request_id;
end $$;

revoke all on function public.place_enrichment_job_json(place_enrichment_private.jobs) from public,anon,authenticated;
revoke all on function public.place_enrichment_enqueue(uuid,uuid,text,jsonb) from public,anon,authenticated;
revoke all on function public.place_enrichment_status(uuid,uuid) from public,anon,authenticated;
revoke all on function public.place_enrichment_retry(uuid,uuid) from public,anon,authenticated;
revoke all on function public.place_enrichment_claim(integer) from public,anon,authenticated;
revoke all on function public.place_enrichment_reserve_google(uuid,uuid) from public,anon,authenticated;
revoke all on function public.place_enrichment_complete(uuid,uuid,jsonb,text) from public,anon,authenticated;
revoke all on function public.place_enrichment_fail(uuid,uuid,text,boolean) from public,anon,authenticated;
revoke all on function public.place_enrichment_verify_worker_token(text) from public,anon,authenticated;
revoke all on function public.place_enrichment_cron_tick() from public,anon,authenticated;
grant execute on function public.place_enrichment_enqueue(uuid,uuid,text,jsonb) to service_role;
grant execute on function public.place_enrichment_status(uuid,uuid) to service_role;
grant execute on function public.place_enrichment_retry(uuid,uuid) to service_role;
grant execute on function public.place_enrichment_claim(integer) to service_role;
grant execute on function public.place_enrichment_reserve_google(uuid,uuid) to service_role;
grant execute on function public.place_enrichment_complete(uuid,uuid,jsonb,text) to service_role;
grant execute on function public.place_enrichment_fail(uuid,uuid,text,boolean) to service_role;
grant execute on function public.place_enrichment_verify_worker_token(text) to service_role;
revoke all on function public.place_enrichment_cron_tick() from service_role;

do $$
begin
  if exists(select 1 from pg_available_extensions where name='pg_cron') then execute 'create extension if not exists pg_cron'; end if;
  if exists(select 1 from pg_available_extensions where name='pg_net') then execute 'create extension if not exists pg_net'; end if;
  if to_regclass('cron.job') is not null then
    execute 'select cron.unschedule(jobid) from cron.job where jobname = ''place-enrichment-worker''';
    execute 'select cron.schedule(''place-enrichment-worker'',''* * * * *'',''select public.place_enrichment_cron_tick()'')';
  end if;
end $$;

