create table public.place_rating_usage_monthly (
  month_start date primary key,
  call_count integer not null default 0 check (call_count >= 0),
  updated_at timestamptz not null default now()
);

create table public.place_rating_usage_requests (
  request_id uuid primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  month_start date not null,
  created_at timestamptz not null default now()
);

create index place_rating_usage_requests_user_created_idx
  on public.place_rating_usage_requests (user_id, created_at desc);

alter table public.place_rating_usage_monthly enable row level security;
alter table public.place_rating_usage_requests enable row level security;
revoke all on public.place_rating_usage_monthly from public, anon, authenticated;
revoke all on public.place_rating_usage_requests from public, anon, authenticated;

create or replace function public.place_rating_reserve_call(
  p_user_id uuid,
  p_request_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  current_month date := date_trunc('month', now() at time zone 'UTC')::date;
  usage_row public.place_rating_usage_monthly%rowtype;
  hourly_count integer;
begin
  if auth.role() is distinct from 'service_role' then
    raise exception using errcode = '42501', message = 'service role required';
  end if;
  if p_user_id is null or p_request_id is null then
    raise exception using errcode = '22023', message = 'invalid rating reservation';
  end if;

  insert into public.place_rating_usage_requests (request_id, user_id, month_start)
  values (p_request_id, p_user_id, current_month)
  on conflict (request_id) do nothing;
  if not found then
    return jsonb_build_object('ok', false, 'code', 'duplicate_request');
  end if;

  insert into public.place_rating_usage_monthly (month_start)
  values (current_month)
  on conflict (month_start) do nothing;
  select * into usage_row
  from public.place_rating_usage_monthly
  where month_start = current_month
  for update;

  select count(*)::integer into hourly_count
  from public.place_rating_usage_requests
  where user_id = p_user_id and created_at >= now() - interval '1 hour';

  if usage_row.call_count >= 1000 then
    return jsonb_build_object('ok', false, 'code', 'monthly_limit');
  end if;
  if hourly_count > 10 then
    return jsonb_build_object('ok', false, 'code', 'rate_limit');
  end if;

  update public.place_rating_usage_monthly
  set call_count = call_count + 1, updated_at = now()
  where month_start = current_month;
  return jsonb_build_object('ok', true, 'call_count', usage_row.call_count + 1, 'limit', 1000);
end;
$$;

revoke all on function public.place_rating_reserve_call(uuid, uuid) from public, anon, authenticated;
grant execute on function public.place_rating_reserve_call(uuid, uuid) to service_role;
