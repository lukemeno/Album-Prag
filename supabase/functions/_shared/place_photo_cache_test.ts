import { assertEquals, assertRejects } from "jsr:@std/assert";
import { createPhotoCache } from "./place_photo_cache.ts";
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
