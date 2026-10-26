import { assertEquals } from "jsr:@std/assert";
import { createPlacePhotoHandler } from "./place-photo/index.ts";

Deno.test("automatic fresh private cache does not call Terra or source quotas", async () => {
  const previousApproved = Deno.env.get("PAID_PHOTO_PROVIDERS_APPROVED");
  const previousTerra = Deno.env.get("TRIPADVISOR_TERRA_ENABLED");
  const previousKey = Deno.env.get("TRIPADVISOR_TERRA_API_KEY");
  const calls: string[] = [];
  const originalFetch = globalThis.fetch;
  globalThis.fetch = async () => { throw new Error("unexpected paid or upstream fetch"); };
  Deno.env.set("PAID_PHOTO_PROVIDERS_APPROVED", "true");
  Deno.env.set("TRIPADVISOR_TERRA_ENABLED", "true");
  Deno.env.set("TRIPADVISOR_TERRA_API_KEY", "test-key");
  const admin = {
    rpc: async (name: string) => {
      calls.push(name);
      if (name === "place_photo_reserve_endpoint") return { data: { ok: true }, error: null };
      if (name === "place_photo_private_cache_claim") return { data: { state: "fresh", payload: [] }, error: null };
      throw new Error(`unexpected RPC ${name}`);
    },
  };
  const handler = createPlacePhotoHandler(async () => ({ user: { id: "11111111-1111-4111-8111-111111111111" } as any, admin } as any));
  const response = await handler(new Request("https://example.test/place-photo", {
    method: "POST",
    body: JSON.stringify({
      title: "Museum", category: "Sehenswert", address: "Prag", latitude: 50, longitude: 14,
      mode: "automatic_photo_v1", manual: false, trip_id: null, place_id: "place-1", revision: "a".repeat(64),
      region: "Prague", selection_version: 4,
    }),
    headers: { "Content-Type": "application/json" },
  }));
  const body = await response.json();
  assertEquals(response.status, 200);
  assertEquals(body.candidates, []);
  assertEquals(calls, ["place_photo_reserve_endpoint", "place_photo_private_cache_claim"]);
  globalThis.fetch = originalFetch;
  for (const [key, value] of [["PAID_PHOTO_PROVIDERS_APPROVED", previousApproved], ["TRIPADVISOR_TERRA_ENABLED", previousTerra], ["TRIPADVISOR_TERRA_API_KEY", previousKey]] as const) {
    if (value === undefined) Deno.env.delete(key); else Deno.env.set(key, value);
  }
});
