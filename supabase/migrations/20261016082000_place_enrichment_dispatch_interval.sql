do $$
declare
  existing_job_id bigint;
begin
  if to_regclass('cron.job') is null then
    return;
  end if;

  select jobid into existing_job_id
    from cron.job
    where jobname = 'place-enrichment-worker'
    limit 1;

  if existing_job_id is not null then
    perform cron.unschedule(existing_job_id);
  end if;

  perform cron.schedule(
    'place-enrichment-worker',
    '10 seconds',
    'select public.place_enrichment_cron_tick()'
  );
end $$;
