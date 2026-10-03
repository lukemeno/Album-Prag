create table public.assistant_usage_monthly (
  month_start date primary key,
  committed_usd numeric(12, 6) not null default 0 check (committed_usd >= 0),
  updated_at timestamptz not null default now()
);

create table public.assistant_usage_user_monthly (
  user_id uuid not null references auth.users(id) on delete cascade,
  month_start date not null,
  committed_usd numeric(12, 6) not null default 0 check (committed_usd >= 0),
  request_count integer not null default 0 check (request_count >= 0),
  updated_at timestamptz not null default now(),
  primary key (user_id, month_start)
);

create table public.assistant_usage_requests (
  request_id uuid primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  month_start date not null,
  reserved_usd numeric(12, 6) not null check (reserved_usd > 0),
  actual_usd numeric(12, 6),
  status text not null check (status in ('reserved', 'completed', 'failed')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index assistant_usage_requests_user_created_idx
  on public.assistant_usage_requests (user_id, created_at desc);

alter table public.assistant_usage_monthly enable row level security;
alter table public.assistant_usage_user_monthly enable row level security;
alter table public.assistant_usage_requests enable row level security;
revoke all on public.assistant_usage_monthly from public, anon, authenticated;
revoke all on public.assistant_usage_user_monthly from public, anon, authenticated;
revoke all on public.assistant_usage_requests from public, anon, authenticated;

create or replace function public.assistant_reserve_usage(
  p_user_id uuid,
  p_request_id uuid,
  p_reservation_usd numeric default 0.05
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  current_month date := date_trunc('month', now())::date;
  global_row public.assistant_usage_monthly%rowtype;
  user_row public.assistant_usage_user_monthly%rowtype;
  existing_request public.assistant_usage_requests%rowtype;
  hour_count integer;
  global_limit numeric := 9.00;
  user_limit integer := 100;
  hourly_limit integer := 10;
  remaining integer;
begin
  if auth.role() <> 'service_role' then
    raise exception using errcode = '42501', message = 'service role required';
  end if;
  if p_user_id is null or p_request_id is null or p_reservation_usd is null
     or p_reservation_usd <= 0 or p_reservation_usd > 1.00 then
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

  select count(*)::integer into hour_count
  from public.assistant_usage_requests
  where user_id = p_user_id and created_at >= now() - interval '1 hour';

  if global_row.committed_usd + p_reservation_usd > global_limit then
    return jsonb_build_object('ok', false, 'code', 'monthly_limit');
  end if;
  if user_row.request_count >= user_limit then
    return jsonb_build_object('ok', false, 'code', 'user_monthly_limit');
  end if;
  if hour_count >= hourly_limit then
    return jsonb_build_object('ok', false, 'code', 'rate_limit');
  end if;

  insert into public.assistant_usage_requests
    (request_id, user_id, month_start, reserved_usd, status)
  values (p_request_id, p_user_id, current_month, p_reservation_usd, 'reserved');
  update public.assistant_usage_monthly
  set committed_usd = committed_usd + p_reservation_usd, updated_at = now()
  where month_start = current_month;
  update public.assistant_usage_user_monthly
  set committed_usd = committed_usd + p_reservation_usd,
      request_count = request_count + 1,
      updated_at = now()
  where user_id = p_user_id and month_start = current_month;

  remaining := least(
    user_limit - user_row.request_count - 1,
    hourly_limit - hour_count - 1,
    floor((global_limit - global_row.committed_usd - p_reservation_usd) / p_reservation_usd)::integer
  );
  return jsonb_build_object(
    'ok', true,
    'used_usd', round((global_row.committed_usd + p_reservation_usd)::numeric, 6),
    'limit_usd', global_limit,
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
  global_used numeric := 0;
  user_count integer := 0;
  hour_count integer := 0;
  remaining integer;
begin
  if auth.role() <> 'service_role' then
    raise exception using errcode = '42501', message = 'service role required';
  end if;
  select coalesce(committed_usd, 0) into global_used
  from public.assistant_usage_monthly where month_start = current_month;
  select coalesce(request_count, 0) into user_count
  from public.assistant_usage_user_monthly
  where user_id = p_user_id and month_start = current_month;
  select count(*)::integer into hour_count
  from public.assistant_usage_requests
  where user_id = p_user_id and created_at >= now() - interval '1 hour';
  remaining := least(100 - user_count, 10 - hour_count, floor((9.00 - global_used) / 0.05)::integer);
  return jsonb_build_object(
    'used_usd', round(greatest(global_used, 0)::numeric, 6),
    'limit_usd', 9.00,
    'remaining_requests', greatest(remaining, 0)
  );
end;
$$;

revoke all on function public.assistant_reserve_usage(uuid, uuid, numeric) from public, anon, authenticated;
revoke all on function public.assistant_reconcile_usage(uuid, boolean, numeric) from public, anon, authenticated;
revoke all on function public.assistant_usage_status(uuid) from public, anon, authenticated;
grant execute on function public.assistant_reserve_usage(uuid, uuid, numeric) to service_role;
grant execute on function public.assistant_reconcile_usage(uuid, boolean, numeric) to service_role;
grant execute on function public.assistant_usage_status(uuid) to service_role;
