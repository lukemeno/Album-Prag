\set ON_ERROR_STOP on
select set_config('request.jwt.role', 'service_role', false);
insert into auth.users (id) values ('00000000-0000-4000-8000-00000000000a');

create or replace function pg_temp.check(cond boolean, msg text) returns void language plpgsql as $$
begin
  if cond is distinct from true then raise exception 'FAILED: %', msg; end if;
  raise notice 'ok: %', msg;
end $$;

do $$
declare
  u uuid := '00000000-0000-4000-8000-00000000000a';
  cm date := date_trunc('month', now())::date;
  r jsonb;
  ok_before boolean;
begin
  perform pg_temp.check((select global_limit_usd = 9 and user_monthly_requests = 100 and solo_monthly_requests = 20
    and hourly_requests = 10 and reservation_usd = 0.05 and stale_after = interval '10 minutes' and enabled
    from public.assistant_limits where id), 'default limits seeded');
  perform pg_temp.check((select count(*) = 1 from public.assistant_model_prices where model = 'gpt-6-luna'
    and input_usd_per_million = 0.10 and output_usd_per_million = 0.50 and web_search_usd = 0.01), 'model price seeded');

  -- 1. trip reservation with default amount
  r := public.assistant_reserve_usage(u, '00000000-0000-4000-8000-000000000001', null, true);
  perform pg_temp.check(r->>'ok' = 'true' and (r->>'limit_usd')::numeric = 9, 'trip reservation ok: ' || r::text);
  perform pg_temp.check((select has_trip from public.assistant_usage_requests where request_id = '00000000-0000-4000-8000-000000000001'), 'has_trip stored true');

  -- 2. stale reservation of same user is released before the next reservation counts
  update public.assistant_usage_requests set created_at = now() - interval '2 hours'
    where request_id = '00000000-0000-4000-8000-000000000001';
  r := public.assistant_reserve_usage(u, '00000000-0000-4000-8000-000000000002', null, true);
  perform pg_temp.check(r->>'ok' = 'true', 'reservation after stale ok: ' || r::text);
  perform pg_temp.check((select status from public.assistant_usage_requests where request_id = '00000000-0000-4000-8000-000000000001') = 'failed', 'stale reservation marked failed');
  perform pg_temp.check((select request_count from public.assistant_usage_user_monthly where user_id = u and month_start = cm) = 1, 'stale request released from request_count');
  perform pg_temp.check((select committed_usd from public.assistant_usage_user_monthly where user_id = u and month_start = cm) = 0.05, 'user committed holds only live reservation');
  perform pg_temp.check((select committed_usd from public.assistant_usage_monthly where month_start = cm) = 0.05, 'global committed holds only live reservation');
  perform pg_temp.check(public.assistant_reconcile_usage('00000000-0000-4000-8000-000000000001', true, 0.02) = false, 'reconcile of released reservation is a no-op');

  -- 3. failed reconcile rolls back committed amounts and request count
  perform pg_temp.check(public.assistant_reconcile_usage('00000000-0000-4000-8000-000000000002', false, null) = true, 'failed reconcile returns true');
  perform pg_temp.check((select committed_usd = 0 and request_count = 0 from public.assistant_usage_user_monthly where user_id = u and month_start = cm), 'failure rolls back user committed and count');
  perform pg_temp.check((select committed_usd = 0 from public.assistant_usage_monthly where month_start = cm), 'failure rolls back global committed');
  perform pg_temp.check((select status = 'failed' from public.assistant_usage_requests where request_id = '00000000-0000-4000-8000-000000000002'), 'failed reconcile sets status failed');

  -- 4. successful reconcile keeps actual cost
  r := public.assistant_reserve_usage(u, '00000000-0000-4000-8000-000000000003', null, true);
  perform pg_temp.check(public.assistant_reconcile_usage('00000000-0000-4000-8000-000000000003', true, 0.03) = true, 'successful reconcile');
  perform pg_temp.check((select actual_usd = 0.03 and status = 'completed' from public.assistant_usage_requests where request_id = '00000000-0000-4000-8000-000000000003'), 'completed keeps actual cost');

  -- 5. solo limit only counts non-trip requests that were not rolled back
  update public.assistant_limits set solo_monthly_requests = 1 where id;
  r := public.assistant_reserve_usage(u, '00000000-0000-4000-8000-000000000004', null, false);
  perform pg_temp.check(r->>'ok' = 'true' and (r->>'remaining_requests')::int >= 0, 'first solo request allowed: ' || r::text);
  r := public.assistant_reserve_usage(u, '00000000-0000-4000-8000-000000000005', null, false);
  perform pg_temp.check(r->>'code' = 'solo_monthly_limit', 'second solo request blocked: ' || r::text);
  r := public.assistant_reserve_usage(u, '00000000-0000-4000-8000-000000000006', null, true);
  perform pg_temp.check(r->>'ok' = 'true', 'trip request not blocked by solo limit: ' || r::text);
  perform pg_temp.check(public.assistant_reconcile_usage('00000000-0000-4000-8000-000000000004', false, null) = true, 'failed solo request reconciled');
  r := public.assistant_reserve_usage(u, '00000000-0000-4000-8000-000000000007', null, false);
  perform pg_temp.check(r->>'ok' = 'true', 'failed solo request does not count toward solo limit: ' || r::text);
  update public.assistant_limits set solo_monthly_requests = 20 where id;

  -- 6. user monthly limit applies to trip and solo requests alike
  update public.assistant_limits set user_monthly_requests = (select request_count from public.assistant_usage_user_monthly where user_id = u and month_start = cm) where id;
  r := public.assistant_reserve_usage(u, '00000000-0000-4000-8000-000000000008', null, true);
  perform pg_temp.check(r->>'code' = 'user_monthly_limit', 'user monthly limit blocks trip request: ' || r::text);
  r := public.assistant_reserve_usage(u, '00000000-0000-4000-8000-000000000009', null, false);
  perform pg_temp.check(r->>'code' = 'user_monthly_limit', 'user monthly limit blocks solo request: ' || r::text);
  update public.assistant_limits set user_monthly_requests = 100 where id;

  -- 7. global monthly limit and rate limit come from the table
  update public.assistant_limits set global_limit_usd = 0.01 where id;
  r := public.assistant_reserve_usage(u, '00000000-0000-4000-8000-00000000000a', null, true);
  perform pg_temp.check(r->>'code' = 'monthly_limit', 'monthly limit from table: ' || r::text);
  update public.assistant_limits set global_limit_usd = 9 where id;
  update public.assistant_limits set hourly_requests = 1 where id;
  r := public.assistant_reserve_usage(u, '00000000-0000-4000-8000-00000000000b', null, true);
  perform pg_temp.check(r->>'code' = 'rate_limit', 'hourly limit from table: ' || r::text);
  update public.assistant_limits set hourly_requests = 10 where id;

  -- 8. kill switch
  update public.assistant_limits set enabled = false where id;
  r := public.assistant_reserve_usage(u, '00000000-0000-4000-8000-00000000000c', null, true);
  perform pg_temp.check(r->>'code' = 'disabled', 'kill switch returns disabled: ' || r::text);
  update public.assistant_limits set enabled = true where id;

  -- 9. reservation amount validation and override
  begin
    perform public.assistant_reserve_usage(u, '00000000-0000-4000-8000-00000000000d', 2.0, true);
    raise exception 'FAILED: reservation above 1.00 accepted';
  exception when sqlstate '22023' then
    raise notice 'ok: reservation above 1.00 rejected';
  end;
  begin
    perform public.assistant_reserve_usage(u, '00000000-0000-4000-8000-00000000000d', 0, true);
    raise exception 'FAILED: zero reservation accepted';
  exception when sqlstate '22023' then
    raise notice 'ok: zero reservation rejected';
  end;
  r := public.assistant_reserve_usage(u, '00000000-0000-4000-8000-00000000000e', 0.10, true);
  perform pg_temp.check(r->>'ok' = 'true', 'explicit reservation amount accepted');

  -- 10. duplicate request id
  r := public.assistant_reserve_usage(u, '00000000-0000-4000-8000-000000000003', null, true);
  perform pg_temp.check(r->>'code' = 'duplicate_request', 'duplicate request detected');

  -- 11. status uses table limits
  update public.assistant_limits set user_monthly_requests = 50 where id;
  r := public.assistant_usage_status(u);
  perform pg_temp.check((r->>'limit_usd')::numeric = 9 and (r->>'remaining_requests')::int >= 0, 'status reads table limits: ' || r::text);
  update public.assistant_limits set user_monthly_requests = 100 where id;

  raise notice 'status example: %', r::text;
end $$;

-- 12. privileges and signatures
select pg_temp.check(count(*) = 1, 'only the 4-argument reserve function exists') from pg_proc where proname = 'assistant_reserve_usage';
select pg_temp.check(not has_table_privilege('authenticated', 'public.assistant_limits', 'select')
  and not has_table_privilege('anon', 'public.assistant_limits', 'select')
  and has_table_privilege('service_role', 'public.assistant_limits', 'select'), 'limits: service_role only');
select pg_temp.check(not has_table_privilege('authenticated', 'public.assistant_model_prices', 'select')
  and has_table_privilege('service_role', 'public.assistant_model_prices', 'select'), 'prices: service_role only');
select pg_temp.check(not has_function_privilege('authenticated', 'public.assistant_reserve_usage(uuid,uuid,numeric,boolean)', 'execute')
  and has_function_privilege('service_role', 'public.assistant_reserve_usage(uuid,uuid,numeric,boolean)', 'execute'), 'reserve: execute only for service_role');
select pg_temp.check(not has_function_privilege('anon', 'public.assistant_usage_status(uuid)', 'execute'), 'status: no anon execute');
