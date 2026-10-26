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
  user_two uuid := '22222222-2222-4222-8222-222222222222';
  trip_id uuid := '33333333-3333-4333-8333-333333333333';
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
  if user_id is null then raise exception 'test requires an auth user fixture'; end if;
  insert into auth.users(id) values(user_two) on conflict do nothing;
  insert into public.trips(id,invite_token_hash) values(trip_id,'qa-place-photo-limits') on conflict do nothing;
  insert into public.trip_members(trip_id,user_id,role) values(trip_id,user_id,'owner'),(trip_id,user_two,'member') on conflict do nothing;
  claim := public.place_photo_private_cache_claim('11111111-1111-4111-8111-111111111111'::uuid,null,'local-place','r1',token,now());
  if claim->>'state' <> 'claimed' then raise exception 'local null-trip cache was not claimable'; end if;
  perform public.place_photo_private_cache_complete('11111111-1111-4111-8111-111111111111'::uuid,null,'local-place','r1',token,'[{"provider":"wikimedia"}]'::jsonb,now()+interval '1 day');
  claim := public.place_photo_private_cache_claim('11111111-1111-4111-8111-111111111111'::uuid,null,'local-place','r1',other,now());
  if claim->>'state' <> 'fresh' then raise exception 'local null-trip cache was not fresh'; end if;
  claim := public.place_photo_private_cache_claim('11111111-1111-4111-8111-111111111111'::uuid,trip_id,'shared-place','r1',token,now());
  if claim->>'state' <> 'claimed' then raise exception 'shared trip cache was not claimable'; end if;
  claim := public.place_photo_private_cache_claim(user_two,trip_id,'shared-place','r1',other,now());
  if claim->>'state' <> 'busy' then raise exception 'shared trip cache did not share the lease'; end if;

  result := public.place_photo_reserve_run(run_id, user_id, null, null, false, now());
  if not (result->>'ok')::boolean then raise exception 'run reservation failed: %', result; end if;
  for i in 1..10 loop
    result := public.place_photo_reserve_upstream(run_id, 'wikimedia', now());
    if not (result->>'ok')::boolean then raise exception 'upstream reservation % failed: %', i, result; end if;
    perform public.place_photo_release_upstream(run_id, (result->>'sequence')::integer);
  end loop;
  result := public.place_photo_reserve_upstream(run_id, 'wikimedia', now());
  if result->>'code' <> 'global_rate_limit' then raise exception 'expected global HTTP limit: %', result; end if;
  result := public.place_photo_reserve_upstream(run_id, 'wikimedia', now()+interval '2 minutes');
  perform public.place_photo_release_upstream(run_id, (result->>'sequence')::integer);
  result := public.place_photo_reserve_upstream(run_id, 'wikimedia', now()+interval '2 minutes');
  perform public.place_photo_release_upstream(run_id, (result->>'sequence')::integer);
  result := public.place_photo_reserve_upstream(run_id, 'wikimedia', now()+interval '2 minutes');
  if result->>'code' <> 'resolution_limit' then raise exception 'expected per-resolution limit: %', result; end if;
end;
$$;
rollback;
