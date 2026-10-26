#!/usr/bin/env python3
"""Read-only migration check. Prints counts/hashes, never album contents or tokens."""
import argparse
import hashlib
import json
from pathlib import Path


def manifest(root):
    return {
        str(path.relative_to(root)): hashlib.sha256(path.read_bytes()).hexdigest()
        for path in sorted(root.rglob("*")) if path.is_file()
    }


def check(source, target, baseline=None):
    before = manifest(source)
    original = json.loads((source / "album.json").read_text())
    copied = json.loads((target / "album.json").read_text())
    assert copied["albumID"] == original["albumID"], "album identity changed"
    assert copied.get("collaboration") == original.get("collaboration"), "sharing identity changed"
    for field in ("documents", "tripMemories"):
        assert copied.get(field, []) == original.get(field, []), field + " changed"
    for field in ("hotel", "outbound", "arrival", "route", "flightNumber", "notes", "flights",
                  "hotelDetails", "bookingNumber", "travelers", "expenses", "settlements"):
        assert copied.get("trip", {}).get(field) == original.get("trip", {}).get(field), "travel information changed: " + field
    original_places = {p["id"]: p for p in original.get("places", [])}
    copied_places = {p["id"]: p for p in copied.get("places", [])}
    protected = {
        key: place for key, place in original_places.items()
        if place.get("updatedAt", 0) > -60_000_000_000
        or place.get("approvals") or place.get("passedBy") or "uploaded" in (place.get("image") or {})
    }
    for key, place in protected.items():
        assert key in copied_places, "a protected place is missing"
        for field in ("title", "note", "sourceURL", "image", "approvals", "passedBy", "visited"):
            assert place.get(field) == copied_places[key].get(field), "a protected place changed: " + field
    resources = {rel: digest for rel, digest in before.items() if rel != "album.json"}
    for rel, digest in resources.items():
        path = target / rel
        assert path.is_file() and hashlib.sha256(path.read_bytes()).hexdigest() == digest, "an attachment changed"
    after = manifest(source)
    assert before == after, "legacy source changed during inspection"
    if baseline is not None:
        expected = json.loads(baseline.read_text())
        expected_hashes = {name: entry["sha256"] if isinstance(entry, dict) else entry for name, entry in expected.items()}
        assert after == expected_hashes, "legacy source changed since the pre-migration snapshot"
    return {
        "passed": True, "legacy_unchanged": True, "source_files": len(before),
        "preserved_attachments": len(resources), "protected_places": len(protected),
        "source_places": len(original_places), "target_places": len(copied_places),
        "documents": len(copied.get("documents", [])), "memories": len(copied.get("tripMemories", [])),
    }


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("target", type=Path)
    parser.add_argument("--baseline", type=Path)
    args = parser.parse_args()
    print(json.dumps(check(args.source, args.target, args.baseline)))
