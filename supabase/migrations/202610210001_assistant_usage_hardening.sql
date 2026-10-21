create table public.assistant_limits (
  id boolean primary key default true check (id),
  enabled boolean not null default true,
  global_limit_usd numeric(12, 6) not null default 9.00,
  user_monthly_requests integer not null default 100,
  solo_monthly_requests integer not null default 20,
  hourly_requests integer not null default 10,
  reservation_usd numeric(12, 6) not null default 0.05,
  stale_after interval not null default interval '10 minutes',
  updated_at timestamptz not null default now()
);

insert into public.assistant_limits (id) values (true) on conflict do nothing;

create table public.assistant_model_prices (
  model text primary key,
  input_usd_per_million numeric(12, 6) not null,
  output_usd_per_million numeric(12, 6) not null,
  web_search_usd numeric(12, 6) not null
);

insert into public.assistant_model_prices (model, input_usd_per_million, output_usd_per_million, web_search_usd)
values ('gpt-6-luna', 0.10, 0.50, 0.01)
on conflict do nothing;

alter table public.assistant_limits enable row level security;
alter table public.assistant_model_prices enable row level security;
revoke all on public.assistant_limits from public, anon, authenticated;
revoke all on public.assistant_model_prices from public, anon, authenticated;
grant select on public.assistant_limits to service_role;
grant select on public.assistant_model_prices to service_role;

alter table public.assistant_usage_requests
  add column if not exists has_trip boolean not null default true;

drop function if exists public.assistant_reserve_usage(uuid, uuid, numeric);

create or replace function public.assistant_reserve_usage(
  p_user_id uuid,
  p_request_id uuid,
  p_reservation_usd numeric default null,
  p_has_trip boolean default true
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  current_month date := date_trunc('month', now())::date;
  limits public.assistant_limits%rowtype;
  global_row public.assistant_usage_monthly%rowtype;
  user_row public.assistant_usage_user_monthly%rowtype;
  existing_request public.assistant_usage_requests%rowtype;
  stale_row public.assistant_usage_requests%rowtype;
  reserve_usd numeric;
  hour_count integer;
  solo_count integer := 0;
  remaining integer;
  solo_remaining integer;
begin
  if auth.role() <> 'service_role' then
    raise exception using errcode = '42501', message = 'service role required';
  end if;
  if p_user_id is null or p_request_id is null then
    raise exception using errcode = '22023', message = 'invalid usage reservation';
  end if;

  select * into limits from public.assistant_limits where id = true;
  if not found then
    raise exception using errcode = 'P0001', message = 'assistant limits not configured';
  end if;
  if not limits.enabled then
    return jsonb_build_object('ok', false, 'code', 'disabled');
  end if;

  reserve_usd := coalesce(p_reservation_usd, limits.reservation_usd);
  if reserve_usd is null or reserve_usd <= 0 or reserve_usd > 1.00 then
    raise exception using errcode = '22023', message = 'invalid usage reservation';
  end if;

  select * into existing_request
  from public.assistant_usage_requests
  where request_id = p_request_id
  for update;
  if found then
    return jsonb_build_object('ok', false, 'code', 'duplicate_request');
  end if;

  insert into public.assistant_usage_monthly (month_start)
  values (current_month)
  on conflict (month_start) do nothing;
  select * into global_row
  from public.assistant_usage_monthly
  where month_start = current_month
  for update;

  insert into public.assistant_usage_user_monthly (user_id, month_start)
  values (p_user_id, current_month)
  on conflict (user_id, month_start) do nothing;
  select * into user_row
  from public.assistant_usage_user_monthly
  where user_id = p_user_id and month_start = current_month
  for update;

  -- Release reservations of this user that were never reconciled, before any limit is checked.
  for stale_row in
    select * from public.assistant_usage_requests
    where user_id = p_user_id
      and status = 'reserved'
      and created_at < now() - limits.stale_after
    for update
  loop
    update public.assistant_usage_requests
    set status = 'failed', updated_at = now()
    where request_id = stale_row.request_id;
    update public.assistant_usage_monthly
    set committed_usd = greatest(committed_usd - stale_row.reserved_usd, 0), updated_at = now()
    where month_start = stale_row.month_start;
    update public.assistant_usage_user_monthly
    set committed_usd = greatest(committed_usd - stale_row.reserved_usd, 0),
        request_count = greatest(request_count - 1, 0),
        updated_at = now()
    where user_id = p_user_id and month_start = stale_row.month_start;
  end loop;

  select * into global_row
  from public.assistant_usage_monthly
  where month_start = current_month;
  select * into user_row
  from public.assistant_usage_user_monthly
  where user_id = p_user_id and month_start = current_month;

  select count(*)::integer into hour_count
  from public.assistant_usage_requests
  where user_id = p_user_id and created_at >= now() - interval '1 hour';

  if not p_has_trip then
    select count(*)::integer into solo_count
    from public.assistant_usage_requests
    where user_id = p_user_id
      and month_start = current_month
      and has_trip = false
      and status <> 'failed';
  end if;

  if global_row.committed_usd + reserve_usd > limits.global_limit_usd then
    return jsonb_build_object('ok', false, 'code', 'monthly_limit');
  end if;
  if user_row.request_count >= limits.user_monthly_requests then
    return jsonb_build_object('ok', false, 'code', 'user_monthly_limit');
  end if;
  if not p_has_trip and solo_count >= limits.solo_monthly_requests then
    return jsonb_build_object('ok', false, 'code', 'solo_monthly_limit');
  end if;
  if hour_count >= limits.hourly_requests then
    return jsonb_build_object('ok', false, 'code', 'rate_limit');
  end if;

  insert into public.assistant_usage_requests
    (request_id, user_id, month_start, reserved_usd, status, has_trip)
  values (p_request_id, p_user_id, current_month, reserve_usd, 'reserved', p_has_trip);
  update public.assistant_usage_monthly
  set committed_usd = committed_usd + reserve_usd, updated_at = now()
  where month_start = current_month;
  update public.assistant_usage_user_monthly
  set committed_usd = committed_usd + reserve_usd,
      request_count = request_count + 1,
      updated_at = now()
  where user_id = p_user_id and month_start = current_month;

  remaining := least(
    limits.user_monthly_requests - user_row.request_count - 1,
    limits.hourly_requests - hour_count - 1,
    floor((limits.global_limit_usd - global_row.committed_usd - reserve_usd) / reserve_usd)::integer
  );
  if not p_has_trip then
    solo_remaining := limits.solo_monthly_requests - solo_count - 1;
    remaining := least(remaining, solo_remaining);
  end if;

  return jsonb_build_object(
    'ok', true,
    'used_usd', round((global_row.committed_usd + reserve_usd)::numeric, 6),
    'limit_usd', limits.global_limit_usd,
    'remaining_requests', greatest(remaining, 0)
  );
end;
$$;

create or replace function public.assistant_reconcile_usage(
  p_request_id uuid,
  p_succeeded boolean,
  p_actual_usd numeric default null
)
returns boolean
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  usage_row public.assistant_usage_requests%rowtype;
  delta numeric;
begin
  if auth.role() <> 'service_role' then
    raise exception using errcode = '42501', message = 'service role required';
  end if;
  select * into usage_row from public.assistant_usage_requests where request_id = p_request_id for update;
  if not found or usage_row.status <> 'reserved' then return false; end if;
  if not p_succeeded or p_actual_usd is null or p_actual_usd < 0 or p_actual_usd > 100 then
    update public.assistant_usage_requests set status = 'failed', updated_at = now() where request_id = p_request_id;
    update public.assistant_usage_monthly
    set committed_usd = greatest(committed_usd - usage_row.reserved_usd, 0), updated_at = now()
    where month_start = usage_row.month_start;
    update public.assistant_usage_user_monthly
    set committed_usd = greatest(committed_usd - usage_row.reserved_usd, 0),
        request_count = greatest(request_count - 1, 0),
        updated_at = now()
    where user_id = usage_row.user_id and month_start = usage_row.month_start;
    return true;
  end if;
  delta := p_actual_usd - usage_row.reserved_usd;
  update public.assistant_usage_monthly
  set committed_usd = greatest(committed_usd + delta, 0), updated_at = now()
  where month_start = usage_row.month_start;
  update public.assistant_usage_user_monthly
  set committed_usd = greatest(committed_usd + delta, 0), updated_at = now()
  where user_id = usage_row.user_id and month_start = usage_row.month_start;
  update public.assistant_usage_requests
  set actual_usd = p_actual_usd, status = 'completed', updated_at = now()
  where request_id = p_request_id;
  return true;
end;
$$;

create or replace function public.assistant_usage_status(p_user_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  current_month date := date_trunc('month', now())::date;
  limits public.assistant_limits%rowtype;
  global_used numeric := 0;
  user_count integer := 0;
  hour_count integer := 0;
  remaining integer;
begin
  if auth.role() <> 'service_role' then
    raise exception using errcode = '42501', message = 'service role required';
  end if;
  select * into limits from public.assistant_limits where id = true;
  if not found then
    raise exception using errcode = 'P0001', message = 'assistant limits not configured';
  end if;
  select coalesce(committed_usd, 0) into global_used
  from public.assistant_usage_monthly where month_start = current_month;
  select coalesce(request_count, 0) into user_count
  from public.assistant_usage_user_monthly
  where user_id = p_user_id and month_start = current_month;
  select count(*)::integer into hour_count
  from public.assistant_usage_requests
  where user_id = p_user_id and created_at >= now() - interval '1 hour';
  remaining := least(
    limits.user_monthly_requests - user_count,
    limits.hourly_requests - hour_count,
    floor((limits.global_limit_usd - global_used) / nullif(limits.reservation_usd, 0))::integer
  );
  return jsonb_build_object(
    'used_usd', round(greatest(global_used, 0)::numeric, 6),
    'limit_usd', limits.global_limit_usd,
    'remaining_requests', greatest(remaining, 0)
  );
end;
$$;

revoke all on function public.assistant_reserve_usage(uuid, uuid, numeric, boolean) from public, anon, authenticated;
revoke all on function public.assistant_reconcile_usage(uuid, boolean, numeric) from public, anon, authenticated;
revoke all on function public.assistant_usage_status(uuid) from public, anon, authenticated;
grant execute on function public.assistant_reserve_usage(uuid, uuid, numeric, boolean) to service_role;
grant execute on function public.assistant_reconcile_usage(uuid, boolean, numeric) to service_role;
grant execute on function public.assistant_usage_status(uuid) to service_role;
