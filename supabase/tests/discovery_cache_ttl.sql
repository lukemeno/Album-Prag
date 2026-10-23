begin;
set local role service_role;
set local request.jwt.claim.role = 'service_role';
do $$
declare
  zone text;
  sample record;
  token uuid;
  key text;
begin
  foreach zone in array array['UTC', 'Europe/Berlin', 'America/New_York'] loop
    perform set_config('TimeZone', zone, true);
    for sample in select * from (values
      ('2026-10-23T12:34:56Z'::timestamptz, '2026-10-30T12:34:56Z'::timestamptz, '2026-11-22T12:34:56Z'::timestamptz),
      ('2026-03-06T12:34:56Z'::timestamptz, '2026-03-13T12:34:56Z'::timestamptz, '2026-04-05T12:34:56Z'::timestamptz)
    ) as dates(fetched, expires, stale) loop
      token := gen_random_uuid();
      key := 'qa-discovery-dst-' || token::text;
      perform public.discovery_cache_claim(key, 1, 'Q1085', 'de', token, sample.fetched);
      if not public.discovery_cache_complete(key, token, '{"qa":true}'::jsonb, sample.fetched, sample.expires, sample.stale) then
        raise exception 'Fixed-duration catalog TTL rejected in timezone %', zone;
      end if;
    end loop;
  end loop;
end;
$$;
rollback;
