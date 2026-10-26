import { assertEquals, assertRejects } from "jsr:@std/assert";
import { createDistributedPhotoCache, createPhotoCache, publicPhotoCacheKey } from "./place_photo_cache.ts";
Deno.test("identical photo lookups share one request and expire", async () => {
  let calls = 0, time = 0;
  const load = createPhotoCache(async () => {
    calls++;
    return ["photo"];
  }, () => time);
  assertEquals(await Promise.all([load("place"), load("place")]), [["photo"], [
    "photo",
  ]]);
  await load("place");
  assertEquals(calls, 1);
  time = 3_600_001;
  await load("place");
  assertEquals(calls, 2);
  await load("other-place");
  assertEquals(calls, 3);
});
Deno.test("source failures are not cached as no matches", async () => {
  let calls = 0;
  const load = createPhotoCache(async () => {
    if (++calls === 1) throw new Error("offline");
    return ["photo"];
  });
  await assertRejects(() => load("place"));
  assertEquals(await load("place"), ["photo"]);
  assertEquals(calls, 2);
});
Deno.test("empty results are retried after a short cache interval", async () => {
  let calls = 0, time = 0;
  const load = createPhotoCache(async () => {
    calls++;
    return [];
  }, () => time);
  await load("place");
  time = 60_001;
  await load("place");
  assertEquals(calls, 2);
});

Deno.test("distributed cache uses a fresh claim and completes once", async () => {
  let loads = 0, completes = 0;
  const cache = createDistributedPhotoCache<string>({
    claim: async () => ({ state: "claimed", payload: [] }),
    complete: async (_key, _token, payload) => { completes++; assertEquals(payload, ["one"]); },
    release: async () => { throw new Error("must not release"); },
  });
  assertEquals(await cache("k", async () => { loads++; return ["one"]; }), ["one"]);
  assertEquals(loads, 1); assertEquals(completes, 1);
});

Deno.test("distributed cache returns durable payload on a concurrent lease", async () => {
  let loads = 0;
  const cache = createDistributedPhotoCache<string>({
    claim: async () => ({ state: "busy", payload: ["stale"] }),
    complete: async () => undefined, release: async () => undefined,
  });
  assertEquals(await cache("k", async () => { loads++; return ["new"]; }), ["stale"]);
  assertEquals(loads, 0);
});

Deno.test("public cache key is deterministic and identity-scoped", async () => {
  const a = await publicPhotoCacheKey({ id: "ChIJ1", protocol: "Google" });
  assertEquals(a, await publicPhotoCacheKey({ id: "ChIJ1", protocol: "google" }));
  const b = await publicPhotoCacheKey({ id: "ChIJ2", protocol: "google" });
  assertEquals(a === b, false);
  assertEquals(a === await publicPhotoCacheKey({ id: "ChIJ1", protocol: "google" }, 2), false);
  const autoRevision = await publicPhotoCacheKey({ id: `${"a".repeat(64)}\u001fauto-main-v1`, protocol: "private-revision" });
  const manualRevision = await publicPhotoCacheKey({ id: `${"a".repeat(64)}\u001fmanual-gallery-v1`, protocol: "private-revision" });
  assertEquals(autoRevision.length, 64);
  assertEquals(autoRevision === manualRevision, false);
});
