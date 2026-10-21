create or replace function public.place_enrichment_reserve_google(p_job_id uuid,p_lease_token uuid)
returns jsonb language plpgsql security definer set search_path=public,place_enrichment_private,pg_temp as $$
declare job place_enrichment_private.jobs%rowtype; month date := date_trunc('month',now() at time zone 'UTC')::date; usage_row place_enrichment_private.google_usage_monthly%rowtype; hour_count integer; retry_seconds integer;
begin
  if auth.role() is distinct from 'service_role' then raise exception using errcode='42501', message='service role required'; end if;
  select * into job from place_enrichment_private.jobs where job_id=p_job_id and status='processing' and lease_token=p_lease_token for update;
  if not found then return jsonb_build_object('ok',false,'code','lease_expired'); end if;
  if exists(select 1 from place_enrichment_private.google_usage_calls where job_id=p_job_id and lease_token=p_lease_token) then return jsonb_build_object('ok',false,'code','duplicate_reservation'); end if;
  insert into place_enrichment_private.google_usage_monthly(month_start) values(month) on conflict do nothing;
  select * into usage_row from place_enrichment_private.google_usage_monthly where month_start=month for update;
  select count(*)::integer into hour_count from place_enrichment_private.google_usage_calls where user_id=job.user_id and created_at >= now()-interval '1 hour';
  if hour_count >= 100 then
    select greatest(1,ceil(extract(epoch from (min(created_at)+interval '1 hour'-now())))::integer) into retry_seconds
      from place_enrichment_private.google_usage_calls where user_id=job.user_id and created_at >= now()-interval '1 hour';
    return jsonb_build_object('ok',false,'code','rate_limit','retry_after_seconds',retry_seconds);
  end if;
  if usage_row.call_count >= 1000 then return jsonb_build_object('ok',false,'code','monthly_limit'); end if;
  insert into place_enrichment_private.google_usage_calls(job_id,lease_token,user_id) values(p_job_id,p_lease_token,job.user_id);
  update place_enrichment_private.google_usage_monthly set call_count=call_count+1 where month_start=month;
  return jsonb_build_object('ok',true);
end $$;

create or replace function public.place_enrichment_defer(p_job_id uuid,p_lease_token uuid,p_delay_seconds integer,p_error_code text)
returns void language plpgsql security definer set search_path=public,place_enrichment_private,pg_temp as $$
begin
  if auth.role() is distinct from 'service_role' then raise exception using errcode='42501', message='service role required'; end if;
  update place_enrichment_private.jobs
    set status='retry_wait', ready_at=now()+make_interval(secs => greatest(1,least(3600,p_delay_seconds))),
        attempts=greatest(attempts-1,0), lease_until=null, lease_token=null,
        error_code=left(p_error_code,80), updated_at=now()
    where job_id=p_job_id and status='processing' and lease_token=p_lease_token;
end $$;

revoke all on function public.place_enrichment_reserve_google(uuid,uuid) from public,anon,authenticated;
revoke all on function public.place_enrichment_defer(uuid,uuid,integer,text) from public,anon,authenticated;
grant execute on function public.place_enrichment_reserve_google(uuid,uuid) to service_role;
grant execute on function public.place_enrichment_defer(uuid,uuid,integer,text) to service_role;
