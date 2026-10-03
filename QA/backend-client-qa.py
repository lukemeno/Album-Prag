#!/usr/bin/env python3
"""Exercise the deployed Album backend with three isolated anonymous clients.

The script deliberately does not delete data. It writes a mode-600 receipt with
only QA identifiers; the caller must run the guarded cleanup SQL through the
Supabase MCP tool and then verify the baseline counts.
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import pathlib
import re
import tempfile
import urllib.error
import urllib.parse
import urllib.request
import uuid


PROJECT_ID = "akzrlkbylglwrlbaacjo"
DEFAULT_URL = "https://akzrlkbylglwrlbaacjo.supabase.co"
DEFAULT_ANON_KEY = "sb_publishable_yQgk23feVRz0OYzaIlff2g_zD999Wjh"


def now() -> str:
    return dt.datetime.now(dt.timezone.utc).isoformat()


class Client:
    def __init__(self, url: str, anon_key: str, label: str):
        self.url = url.rstrip("/")
        self.anon_key = anon_key
        self.label = label
        self.access_token: str | None = None
        self.user_id: str | None = None

    def call(self, method: str, path: str, body=None, query=None, prefer: str | None = None):
        url = self.url + path
        if query:
            url += "?" + urllib.parse.urlencode(query)
        headers = {"apikey": self.anon_key, "Accept": "application/json"}
        if self.access_token:
            headers["Authorization"] = "Bearer " + self.access_token
        if body is not None:
            headers["Content-Type"] = "application/json"
        if prefer:
            headers["Prefer"] = prefer
        request = urllib.request.Request(url, method=method, headers=headers)
        if body is not None:
            request.data = json.dumps(body, separators=(",", ":")).encode()
        try:
            with urllib.request.urlopen(request, timeout=30) as response:
                raw = response.read()
                return response.status, self.decode(raw), dict(response.headers)
        except urllib.error.HTTPError as error:
            raw = error.read()
            return error.code, self.decode(raw), dict(error.headers)

    @staticmethod
    def decode(raw: bytes):
        if not raw:
            return None
        try:
            return json.loads(raw)
        except json.JSONDecodeError:
            return raw.decode(errors="replace")[:300]

    def signup(self, run_id: str):
        status, payload, _ = self.call("POST", "/auth/v1/signup", {"data": {"qa_run": run_id, "qa_role": self.label}})
        if status not in (200, 201):
            raise RuntimeError(f"{self.label} anonymous signup HTTP {status}")
        self.access_token = payload.get("access_token")
        self.user_id = (payload.get("user") or {}).get("id")
        if not self.access_token or not self.user_id:
            raise RuntimeError(f"{self.label} anonymous signup returned no session")
        return status

    def edge(self, function: str, body=None):
        return self.call("POST", "/functions/v1/" + function, body)

    def rest(self, table: str, method="GET", body=None, query=None, prefer="return=representation"):
        return self.call(method, "/rest/v1/" + table, body, query, prefer)


def row(kind: str, entry_id: str, author_id: str, author_name: str, **fields):
    timestamp = now()
    payload = {
        "id": entry_id,
        "kind": kind,
        "postID": fields.get("postID"),
        "authorID": author_id,
        "authorName": author_name,
        "createdAt": timestamp,
        "updatedAt": timestamp,
        "text": fields.get("text"),
        "url": fields.get("url"),
        "canonicalURL": fields.get("canonicalURL"),
        "displayTitle": fields.get("displayTitle"),
        "caption": fields.get("caption"),
        "thumbnailURL": fields.get("thumbnailURL"),
        "metadataState": fields.get("metadataState"),
        "placeID": fields.get("placeID"),
        "active": fields.get("active"),
        "deleted": False,
    }
    return {
        "trip_id": fields["trip_id"],
        "id": entry_id,
        "payload": payload,
        "version": fields.get("version", 1),
        "deleted": False,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--url", default=os.environ.get("SUPABASE_URL", DEFAULT_URL))
    parser.add_argument("--anon-key", default=os.environ.get("SUPABASE_ANON_KEY", DEFAULT_ANON_KEY))
    args = parser.parse_args()

    run_id = "backend-qa-" + uuid.uuid4().hex
    receipt_dir = pathlib.Path(tempfile.mkdtemp(prefix="album-backend-qa-"))
    receipt_dir.chmod(0o700)
    receipt = receipt_dir / "cleanup-receipt.json"
    cleanup = {"run_id": run_id, "project_id": PROJECT_ID, "user_ids": [], "trip_id": None, "receipt": str(receipt)}

    def save_receipt():
        receipt.write_text(json.dumps(cleanup, indent=2) + "\n", encoding="utf-8")
        receipt.chmod(0o600)

    save_receipt()
    clients = [Client(args.url, args.anon_key, label) for label in ("A", "B", "C")]
    checks: list[dict] = []

    def check(name: str, actual: int, expected, detail=""):
        allowed = expected if isinstance(expected, tuple) else (expected,)
        passed = actual in allowed
        checks.append({"name": name, "status": actual, "expected": list(allowed), "passed": passed, "detail": detail})
        if not passed:
            raise AssertionError(f"{name}: HTTP {actual}, expected {allowed}")

    try:
        for client in clients:
            status = client.signup(run_id)
            check(f"anonymous signup {client.label}", status, (200, 201))
            cleanup["user_ids"].append(client.user_id)
            save_receipt()

        status, payload, _ = clients[0].edge("create-trip")
        check("create-trip A", status, 200)
        trip_id = payload["trip_id"]
        invite_token = payload["invite_token"]
        cleanup["trip_id"] = trip_id
        save_receipt()

        status, _, _ = clients[0].rest("trips", "PATCH", {"payload": {"qa_run": run_id, "qa_role": "backend-client-qa"}}, {"id": "eq." + trip_id})
        check("mark QA trip A", status, 200)

        status, payload, _ = clients[1].edge("join-trip", {"invite_token": invite_token})
        check("join-trip B", status, 200)
        check("join-trip B trip identity", 200 if payload.get("trip_id") == trip_id else 500, 200)
        status, payload, _ = clients[1].edge("join-trip", {"invite_token": invite_token})
        check("repeat join-trip B", status, 200)
        check("repeat join-trip identity", 200 if payload.get("trip_id") == trip_id else 500, 200)

        status, _, _ = clients[2].edge("join-trip", {"invite_token": uuid.uuid4().hex + uuid.uuid4().hex})
        check("wrong invite C", status, 404)

        post_id = "qa-post-" + uuid.uuid4().hex
        post = row("post", post_id, clients[0].user_id, "QA A", trip_id=trip_id, text="QA post", url="https://example.com/qa", canonicalURL="https://example.com/qa", displayTitle="QA", metadataState="available")
        status, _, _ = clients[0].rest("collection_entries", "POST", post)
        check("insert post A", status, (200, 201))
        status, payload, _ = clients[1].rest("collection_entries", "GET", query={"trip_id": "eq." + trip_id, "id": "eq." + post_id})
        check("read post B", status, 200)
        check("read post B payload", 200 if len(payload) == 1 and payload[0]["payload"]["text"] == "QA post" else 500, 200)

        comment_id = "qa-comment-" + uuid.uuid4().hex
        comment = row("comment", comment_id, clients[1].user_id, "QA B", trip_id=trip_id, postID=post_id, text="QA comment")
        status, _, _ = clients[1].rest("collection_entries", "POST", comment)
        check("insert comment B", status, (200, 201))

        reaction_id = "qa-reaction-" + uuid.uuid4().hex
        reaction = row("reaction", reaction_id, clients[1].user_id, "QA B", trip_id=trip_id, postID=post_id, active=True)
        status, _, _ = clients[1].rest("collection_entries", "POST", reaction)
        check("insert reaction B", status, (200, 201))
        status, _, _ = clients[1].rest("collection_entries", "PATCH", {"payload": {**reaction["payload"], "active": False}, "version": 2}, {"trip_id": "eq." + trip_id, "id": "eq." + reaction_id, "version": "eq.1"})
        check("unlike reaction B", status, 200)

        link_id = "qa-link-" + uuid.uuid4().hex
        link = row("placeLink", link_id, clients[0].user_id, "QA A", trip_id=trip_id, postID=post_id, placeID="qa-place-link", active=True)
        status, _, _ = clients[0].rest("collection_entries", "POST", link)
        check("insert placeLink A", status, (200, 201))

        status, _, _ = clients[1].rest("collection_entries", "POST", post)
        check("duplicate post conflict B", status, (409, 422))

        status, _, _ = clients[0].rest("collection_entries", "PATCH", {"payload": {**post["payload"], "text": "A wins CAS"}, "version": 2}, {"trip_id": "eq." + trip_id, "id": "eq." + post_id, "version": "eq.1"})
        check("CAS update A", status, 200)
        status, payload, _ = clients[1].rest("collection_entries", "PATCH", {"payload": {**post["payload"], "text": "stale B"}, "version": 2}, {"trip_id": "eq." + trip_id, "id": "eq." + post_id, "version": "eq.1"})
        check("CAS stale conflict B", status, 200)
        check("CAS stale conflict empty", 200 if payload == [] else 500, 200)

        status, payload, _ = clients[1].rest("collection_entries", "GET", query={"trip_id": "eq." + trip_id})
        check("read collection set B", status, 200)
        check("collection set contains four rows", 200 if len(payload) == 4 else 500, 200)

        status, payload, _ = clients[2].rest("collection_entries", "GET", query={"trip_id": "eq." + trip_id})
        check("outsider read isolation C", status, 200)
        check("outsider sees no rows C", 200 if payload == [] else 500, 200)
        outsider = row("comment", "qa-outsider-" + uuid.uuid4().hex, clients[2].user_id, "QA C", trip_id=trip_id, postID=post_id, text="must be denied")
        status, _, _ = clients[2].rest("collection_entries", "POST", outsider)
        check("outsider write isolation C", status, (401, 403))
    finally:
        save_receipt()

    print(json.dumps({"run_id": run_id, "trip_id": cleanup["trip_id"], "user_count": len(cleanup["user_ids"]), "receipt": str(receipt), "checks": checks}, indent=2))
    return 0 if all(item["passed"] for item in checks) else 1


if __name__ == "__main__":
    raise SystemExit(main())
