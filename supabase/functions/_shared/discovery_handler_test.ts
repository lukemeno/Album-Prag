import { assertEquals, assertRejects } from "jsr:@std/assert";
import { DiscoveryError, type CatalogResponse, type DiscoveryDeps } from "./discovery.ts";
import { handleDiscoveryRequest, type DiscoveryCacheStore } from "./discovery_handler.ts";

const request = { protocol_version: 1, action: "catalog", city_qid: "Q1085", language_code: "en" };
const cachedCatalog: CatalogResponse = {
  protocol_version: 1, catalog_version: 1, ranking_version: 1,
  city: { qid: "Q1085", name: "Prague", country: "Czechia", latitude: 50.0755, longitude: 14.4378, source_url: "https://www.wikidata.org/wiki/Q1085" },
  language_code: "en", coverage: { kind: "radius", radius_meters: 25_000, label: "25 km um Prague" }, items: [],
  fetched_at: "2026-10-22T10:00:00Z", expires_at: "2026-10-29T10:00:00Z", stale_until: "2026-11-21T10:00:00Z", cache_status: "fresh",
};
function pragueDeps(queryError?: Error, calls = { upstream: 0 }): DiscoveryDeps {
  const city = {
    id: "Q1085",
    labels: { en: { value: "Prague" } },
    claims: {
      P31: [{ mainsnak: { datavalue: { value: { id: "Q515" } } } }],
      P625: [{ mainsnak: { datavalue: { value: { latitude: 50.0755, longitude: 14.4378 } } } }],
      P17: [{ mainsnak: { datavalue: { value: { id: "Q213" } } } }],
    },
  };
  return {
    async searchCityEntities() { calls.upstream++; return []; },
    async getEntities(ids: string[]) { calls.upstream++; return ids[0] === "Q1085" ? [city] : [{ id: "Q213", labels: { en: { value: "Czechia" } } }]; },
    async queryPOIs() { calls.upstream++; if (queryError) throw queryError; return []; },
    async getP18Images() { return new Map(); },
  } as unknown as DiscoveryDeps;
}

Deno.test("fresh catalog cache returns without upstream calls", async () => {
  const calls = { upstream: 0 };
  const cache: DiscoveryCacheStore = {
    async reserveRate() { return { ok: true }; },
    async claim() { return { state: "fresh", payload: cachedCatalog }; },
    async complete() { throw new Error("fresh cache must not be completed"); },
    async release() { throw new Error("fresh cache must not be released"); },
  };
  const result = await handleDiscoveryRequest(request, "user-1", pragueDeps(undefined, calls), cache, new AbortController().signal);
  assertEquals("cache_status" in result ? result.cache_status : undefined, "fresh");
  assertEquals(calls.upstream, 0);
});

Deno.test("stale cache is served when refresh source fails", async () => {
  const calls = { upstream: 0 };
  let releaseCount = 0;
  const cache: DiscoveryCacheStore = {
    async reserveRate() { return { ok: true }; },
    async claim() { return { state: "claimed", payload: cachedCatalog }; },
    async complete() { throw new Error("failed refresh must not complete"); },
    async release() { releaseCount++; return true; },
  };
  const result = await handleDiscoveryRequest(request, "user-1", pragueDeps(new DiscoveryError("source_unavailable", "upstream down"), calls), cache, new AbortController().signal);
  assertEquals("cache_status" in result ? result.cache_status : undefined, "stale");
  assertEquals(calls.upstream, 3);
  assertEquals(releaseCount, 1);
});

Deno.test("rate limit rejects before upstream calls", async () => {
  const calls = { upstream: 0 };
  const cache: DiscoveryCacheStore = {
    async reserveRate() { return { ok: false, retry_after_seconds: 42 }; },
    async claim() { throw new Error("rate limited request must not claim"); },
    async complete() { throw new Error("rate limited request must not complete"); },
    async release() { throw new Error("rate limited request must not release"); },
  };
  const error = await assertRejects(() => handleDiscoveryRequest(request, "user-1", pragueDeps(undefined, calls), cache, new AbortController().signal), DiscoveryError);
  assertEquals(error.code, "rate_limited");
  assertEquals(error.retryAfterSeconds, 42);
  assertEquals(calls.upstream, 0);
});

Deno.test("429 and 503 source errors are not cached as empty catalogs", async () => {
  for (const status of [429, 503]) {
    const calls = { upstream: 0 };
    let completed = 0;
    const cache: DiscoveryCacheStore = {
      async reserveRate() { return { ok: true }; },
      async claim() { return { state: "claimed" }; },
      async complete() { completed++; return true; },
      async release() { return true; },
    };
    const error = await assertRejects(
      () => handleDiscoveryRequest(request, "user-1", pragueDeps(new DiscoveryError("source_unavailable", `HTTP ${status}`, 30), calls), cache, new AbortController().signal),
      DiscoveryError,
    );
    assertEquals(error.code, "source_unavailable");
    assertEquals(completed, 0);
  }
});

Deno.test("cold catalog source failure releases lease with one-hour retry cooldown", async () => {
  const released: string[] = [];
  const cache: DiscoveryCacheStore = {
    async reserveRate() { return { ok: true }; },
    async claim() { return { state: "claimed" }; },
    async complete() { return true; },
    async release(_key, _token, nextRefreshAt) { released.push(nextRefreshAt); return true; },
  };

  const now = new Date("2026-10-23T10:00:00.000Z");
  await assertRejects(
    () => handleDiscoveryRequest(request, "user-1", pragueDeps(new DiscoveryError("source_unavailable", "test source failure", 30)), cache, new AbortController().signal, now),
    DiscoveryError,
    "test source failure",
  );
  assertEquals(released, ["2026-10-23T11:00:00.000Z"]);
});

