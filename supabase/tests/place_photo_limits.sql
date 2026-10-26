begin;
set local role service_role;
set local request.jwt.claim.role = 'service_role';
do $$
declare
  key text := repeat('a', 64);
  token uuid := gen_random_uuid();
  other uuid := gen_random_uuid();
  claim jsonb;
  user_id uuid;
  run_id uuid := gen_random_uuid();
  result jsonb;
begin
  claim := public.place_photo_cache_claim(key, 'google', 1, token, now());
  if claim->>'state' <> 'claimed' then raise exception 'expected initial cache lease'; end if;
  claim := public.place_photo_cache_claim(key, 'google', 1, other, now());
  if claim->>'state' <> 'busy' then raise exception 'expected concurrent cache lease'; end if;
  if not public.place_photo_cache_complete(key, token, '[{"provider":"wikimedia","confidence":"verified"}]'::jsonb, now(), now()+interval '30 days', now()+interval '90 days') then
    raise exception 'cache completion failed';
  end if;
  claim := public.place_photo_cache_claim(key, 'google', 1, other, now());
  if claim->>'state' <> 'fresh' or jsonb_array_length(claim->'payload') <> 1 then raise exception 'fresh cache payload missing'; end if;

  select id into user_id from auth.users order by created_at limit 1;
  if user_id is null then return; end if;
  result := public.place_photo_reserve_run(run_id, user_id, null, null, false, now());
  if not (result->>'ok')::boolean then raise exception 'run reservation failed: %', result; end if;
  for i in 1..12 loop
    result := public.place_photo_reserve_upstream(run_id, 'wikimedia', now());
    if not (result->>'ok')::boolean then raise exception 'upstream reservation % failed: %', i, result; end if;
  end loop;
  result := public.place_photo_reserve_upstream(run_id, 'wikimedia', now());
  if result->>'code' <> 'resolution_limit' then raise exception 'expected per-resolution limit: %', result; end if;
end;
$$;
rollback;
