import { assertEquals } from "jsr:@std/assert";
import { handleTripLifecycle, type TripLifecycleStore, TRIP_BUCKETS } from "./trip_lifecycle.ts";

const TRIP = "8b0a6d8e-4c1f-4b7e-9d2a-1f3c5e7a9b11";
const OWNER = "owner-user";
const MEMBER = "member-user";
const STRANGER = "stranger-user";

function fakeStore(options: { failStorage?: boolean } = {}) {
  const members = new Map<string, "owner" | "member">([[OWNER, "owner"], [MEMBER, "member"]]);
  let tripExists = true;
  const files = new Map<string, string[]>(TRIP_BUCKETS.map(bucket => [bucket, [`${TRIP}/a.jpg`, `${TRIP}/${OWNER}/b.jpg`]]));
  const store: TripLifecycleStore = {
    tripExists: () => Promise.resolve(tripExists),
    role: (_trip, user) => Promise.resolve(tripExists ? members.get(user) ?? null : null),
    memberCount: () => Promise.resolve(members.size),
    deleteTrip: () => { tripExists = false; members.clear(); return Promise.resolve(); },
    removeMember: (_trip, user) => { members.delete(user); return Promise.resolve(); },
    listFiles: (bucket, prefix) => Promise.resolve((files.get(bucket) ?? []).filter(path => path.startsWith(prefix))),
    removeFiles: (bucket, paths) => {
      if (options.failStorage) return Promise.reject(new Error("storage down"));
      files.set(bucket, (files.get(bucket) ?? []).filter(path => !paths.includes(path)));
      return Promise.resolve();
    },
  };
  return { store, members, files, isTripGone: () => !tripExists };
}

Deno.test("invalid trip id is rejected", async () => {
  const { store } = fakeStore();
  assertEquals((await handleTripLifecycle("delete", "kein-uuid", OWNER, store)).status, 400);
});

Deno.test("stranger can neither delete nor leave", async () => {
  const { store, isTripGone } = fakeStore();
  assertEquals((await handleTripLifecycle("delete", TRIP, STRANGER, store)).status, 403);
  assertEquals((await handleTripLifecycle("leave", TRIP, STRANGER, store)).status, 403);
  assertEquals(isTripGone(), false);
});

Deno.test("member cannot delete the trip for everyone", async () => {
  const { store, isTripGone } = fakeStore();
  assertEquals((await handleTripLifecycle("delete", TRIP, MEMBER, store)).status, 403);
  assertEquals(isTripGone(), false);
});

Deno.test("member leaves and only loses their own membership", async () => {
  const { store, members, isTripGone } = fakeStore();
  const result = await handleTripLifecycle("leave", TRIP, MEMBER, store);
  assertEquals(result.status, 200);
  assertEquals(members.has(MEMBER), false);
  assertEquals(members.has(OWNER), true);
  assertEquals(isTripGone(), false);
});

Deno.test("owner cannot leave while others remain", async () => {
  const { store, members } = fakeStore();
  assertEquals((await handleTripLifecycle("leave", TRIP, OWNER, store)).status, 409);
  assertEquals(members.has(OWNER), true);
});

Deno.test("owner as last member leaving deletes the trip", async () => {
  const { store, members, isTripGone } = fakeStore();
  members.delete(MEMBER);
  assertEquals((await handleTripLifecycle("leave", TRIP, OWNER, store)).status, 200);
  assertEquals(isTripGone(), true);
});

Deno.test("owner delete removes the trip and every stored file", async () => {
  const { store, files, isTripGone } = fakeStore();
  const result = await handleTripLifecycle("delete", TRIP, OWNER, store);
  assertEquals(result.status, 200);
  assertEquals(result.body.status, "deleted");
  assertEquals(isTripGone(), true);
  for (const bucket of TRIP_BUCKETS) assertEquals(files.get(bucket), []);
});

Deno.test("repeating a delete after success answers gone, not an error", async () => {
  const { store } = fakeStore();
  await handleTripLifecycle("delete", TRIP, OWNER, store);
  const again = await handleTripLifecycle("delete", TRIP, OWNER, store);
  assertEquals(again.status, 200);
  assertEquals(again.body.status, "gone");
});

Deno.test("storage failure still deletes the trip and reports leftovers", async () => {
  const { store, isTripGone } = fakeStore({ failStorage: true });
  const result = await handleTripLifecycle("delete", TRIP, OWNER, store);
  assertEquals(result.status, 200);
  assertEquals(isTripGone(), true);
  assertEquals(result.body.storageCleanup, "incomplete");
});
