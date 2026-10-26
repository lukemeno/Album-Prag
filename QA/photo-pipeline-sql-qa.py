#!/usr/bin/env python3
"""Check photo RPC concurrency in a disposable local PostgreSQL database.

Requires a local PostgreSQL server and the anon/authenticated/service_role roles.
Never connects to Supabase or uses app credentials. Original table constraints
come from the repository migrations; only auth and extensions are stubbed.
"""
import concurrent.futures
import hashlib
import json
from pathlib import Path
import subprocess
import uuid

ROOT = Path(__file__).resolve().parents[1]
DATABASE = "album_photo_qa_" + uuid.uuid4().hex[:12]
CONNECTION = ["-h", "127.0.0.1", "-p", "65439", "-U", "postgres"]


def sql(statement, *, service=False, check=True):
    if service:
        statement = "set role service_role; set request.jwt.claim.role='service_role'; " + statement
    return subprocess.run(
        ["psql", *CONNECTION, "-d", DATABASE, "-XqAt", "-v", "ON_ERROR_STOP=1"],
        input=statement, text=True, capture_output=True, check=check,
    )


def rpc(statement):
    return json.loads(sql("select " + statement + ";", service=True).stdout.strip())


def main():
    subprocess.run(["createdb", *CONNECTION, DATABASE], check=True, capture_output=True)
    try:
        shared = (ROOT / "supabase/migrations/202609210001_shared_album.sql").read_text()
        jobs = (ROOT / "supabase/migrations/20261015222452_place_enrichment_jobs.sql").read_text()
        fixture = """
create schema auth;
create table auth.users(id uuid primary key,created_at timestamptz default now());
create function auth.role() returns text language sql stable as $$
select nullif(current_setting('request.jwt.claim.role',true),'') $$;
"""
        fixture += shared.split("create or replace function public.is_trip_member")[0]
        fixture += jobs.split("create table place_enrichment_private.worker_config")[0]
        fixture += """
grant usage on schema auth,place_enrichment_private to service_role;
grant select,insert,update,delete on all tables in schema auth,public,place_enrichment_private to service_role;
insert into auth.users(id) values('11111111-1111-4111-8111-111111111111');
"""
        sql(fixture)
        sql((ROOT / "supabase/migrations/202610260001_place_photo_pipeline.sql").read_text())
        sql((ROOT / "supabase/tests/place_photo_limits.sql").read_text())

        key = hashlib.sha256(uuid.uuid4().bytes).hexdigest()
        def claim(_):
            return rpc(f"public.place_photo_cache_claim('{key}','wikidata',1,'{uuid.uuid4()}',now())")
        with concurrent.futures.ThreadPoolExecutor(max_workers=16) as pool:
            claims = list(pool.map(claim, range(50)))
        assert sum(c["state"] == "claimed" for c in claims) == 1, claims
        assert sum(c["state"] == "busy" for c in claims) == 49, claims

        user = str(uuid.uuid4())
        sql(f"insert into auth.users(id) values('{user}');")
        run_ids = [str(uuid.uuid4()) for _ in range(50)]
        def reserve(run_id):
            return rpc(f"public.place_photo_reserve_run('{run_id}','{user}',null,null,false,now())")
        with concurrent.futures.ThreadPoolExecutor(max_workers=16) as pool:
            runs = list(pool.map(reserve, run_ids))
        assert sum(r.get("ok") is True for r in runs) == 30, runs
        assert sum(r.get("code") == "user_hour_limit" for r in runs) == 20, runs

        allowed = [run_id for run_id, result in zip(run_ids, runs) if result.get("ok")]
        first = rpc(f"public.place_photo_reserve_upstream('{allowed[0]}','wikimedia',now())")
        second = rpc(f"public.place_photo_reserve_upstream('{allowed[1]}','wikimedia',now())")
        assert first.get("ok") is True, first
        assert second.get("ok") is False and second.get("code") == "active_request", second
        sql(f"select public.place_photo_release_upstream('{allowed[0]}',{first['sequence']});", service=True)
        third = rpc(f"public.place_photo_reserve_upstream('{allowed[1]}','wikimedia',now())")
        assert third.get("ok") is True, third

        unauthorized = sql(
            "set role authenticated; select * from place_photo_private.private_cache;", check=False,
        )
        assert unauthorized.returncode != 0 and "permission denied" in unauthorized.stderr, unauthorized.stderr
        unauthorized_rpc = sql(
            f"set role authenticated; select public.place_photo_cache_claim('{key}','wikidata',1,'{uuid.uuid4()}',now());",
            check=False,
        )
        assert unauthorized_rpc.returncode != 0 and "permission denied" in unauthorized_rpc.stderr
        print(json.dumps({
            "schema_and_rpc_regression": "passed",
            "parallel_cache_claims": {"requests": 50, "owners": 1, "waiting": 49},
            "parallel_run_quota": {"requests": 50, "accepted": 30, "limited": 20},
            "global_http_semaphore": "held, rejected concurrent request, released, reclaimed",
            "authenticated_direct_access": "denied",
        }, ensure_ascii=False))
    finally:
        subprocess.run(["dropdb", *CONNECTION, DATABASE], check=True, capture_output=True)


if __name__ == "__main__":
    main()
