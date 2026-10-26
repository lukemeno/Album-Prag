import { assertEquals, assertThrows } from "jsr:@std/assert";
import { parseEnrichmentAction, requestKey } from "./place_enrichment.ts";

const base = {
  action: "enqueue", trip_id: null, google_photos: false, mode: "automatic_photo_v1",
  place: { id: "p1", title: "Museum", category: "Sehenswert", address: "Prag", source_url: "", latitude: 50.0755, longitude: 14.4378 },
  region: { name: "Prague", latitude: 50.0755, longitude: 14.4378 },
};

Deno.test("automatic photo requests require confirmed coordinates", () => {
  assertThrows(() => parseEnrichmentAction({ ...base, place: { ...base.place, latitude: null, longitude: null } }));
  const parsed = parseEnrichmentAction(base);
  if (parsed.action !== "enqueue") throw new Error("expected enqueue");
  assertEquals(parsed.request.mode, "automatic_photo_v1");
});

Deno.test("provider hints do not change the privacy-safe request key unexpectedly", async () => {
  const first = parseEnrichmentAction(base), second = parseEnrichmentAction({ ...base, place: { ...base.place, provider_place_id: "client-hint", provider_protocol: "google" } });
  if (first.action !== "enqueue" || second.action !== "enqueue") throw new Error("expected enqueue");
  const a = await requestKey(first.request);
  const b = await requestKey(second.request);
  assertEquals(a === b, false);
});
