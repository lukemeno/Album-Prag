import { assertEquals, assertRejects, assertStringIncludes } from "jsr:@std/assert";
import { buildDiscoveryDirectTypesQuery, buildDiscoveryGeoSearch, buildDiscoveryParentQuery, classifyDiscoveryRootIDs, createWikidataDiscoveryDeps } from "./discovery_source.ts";
import { DiscoveryError } from "./discovery.ts";

Deno.test("production candidate search is a bounded 25 km Wikidata Cirrus query", () => {
  assertEquals(buildDiscoveryGeoSearch({ qid: "Q1085", name: "Prague", country: "Czechia", latitude: 50.0755, longitude: 14.4378, source_url: "https://www.wikidata.org/wiki/Q1085" }), "nearcoord:25km,50.0755,14.4378");
});

Deno.test("bounded classification query only fetches direct types for known candidates", () => {
  const directQuery = buildDiscoveryDirectTypesQuery(["Q188399", "Q204871", "Q188399", "not-a-qid"]);
  assertStringIncludes(directQuery, "VALUES ?item { wd:Q188399 wd:Q204871 }");
  assertStringIncludes(directQuery, "?item wdt:P31 ?directType");
  assertEquals(directQuery.includes("DISTINCT"), false);
  assertEquals(directQuery.includes("P279"), false);
  const parentQuery = buildDiscoveryParentQuery(["Q33506", "Q33506", "invalid"]);
  assertStringIncludes(parentQuery, "VALUES ?type { wd:Q33506 }");
  assertStringIncludes(parentQuery, "?type wikibase:statements ?statementCount");
  assertStringIncludes(parentQuery, "OPTIONAL { ?type wdt:P279 ?parent. }");
  assertEquals(parentQuery.includes("P279*"), false);
});

Deno.test("root classification keeps visitable POIs and rejects any excluded ancestry", () => {
  assertEquals(classifyDiscoveryRootIDs(["Q33506"]), ["culture_museums"]);
  assertEquals(classifyDiscoveryRootIDs(["Q207694"]), ["culture_museums", "art"]);
  assertEquals(classifyDiscoveryRootIDs(["Q740437"]), ["culture_museums", "art"]);
  assertEquals(classifyDiscoveryRootIDs(["Q33506", "Q43229"]), ["culture_museums"]);
  assertEquals(classifyDiscoveryRootIDs(["Q4989906", "Q1656682"]), []);
  assertEquals(classifyDiscoveryRootIDs(["Q43229"]), []);
});

Deno.test("only a concrete demolition date excludes an otherwise visitable POI", async () => {
  const original = globalThis.fetch;
  const candidateIDs = ["Q910000001", "Q910000002", "Q910000003"];
  globalThis.fetch = async (input, init) => {
    const url = new URL(String(input));
    if (url.hostname === "query.wikidata.org") {
      const query = new URLSearchParams(String(init?.body)).get("query") ?? "";
      return Response.json({ results: { bindings: candidateIDs.map(id => ({
        item: { value: `http://www.wikidata.org/entity/${id}` },
        directType: { value: "http://www.wikidata.org/entity/Q23413" },
      })) } });
    }
    if (url.searchParams.get("list") === "search") {
      return Response.json({ query: { search: candidateIDs.map(title => ({ title })) } });
    }
    const ids = (url.searchParams.get("ids") ?? "").split("|").filter(Boolean);
    const demolitionClaims: Record<string, unknown[]> = {
      Q910000001: [{ mainsnak: { snaktype: "value", datavalue: { value: { time: "+1789-07-14T00:00:00Z" } } } }],
      Q910000002: [{ mainsnak: { snaktype: "somevalue" } }],
      Q910000003: [{ mainsnak: { snaktype: "novalue" } }],
    };
    return Response.json({ entities: Object.fromEntries(ids.map(id => [id, {
      claims: {
        P625: [{ mainsnak: { datavalue: { value: { latitude: 50.08, longitude: 14.43 } } } }],
        P576: demolitionClaims[id],
      },
      sitelinks: {},
    }])) });
  };
  try {
    const rows = await createWikidataDiscoveryDeps().queryPOIs(
      { qid: "Q1085", name: "Prague", country: "Czechia", latitude: 50.0755, longitude: 14.4378, source_url: "https://www.wikidata.org/wiki/Q1085" },
      "en",
      new AbortController().signal,
    );
    assertEquals(rows.map(row => row.id), ["Q910000002", "Q910000003"]);
  } finally {
    globalThis.fetch = original;
  }
});

Deno.test("production classification resolves P279 locally and never sends a closure query", async () => {
  const original = globalThis.fetch;
  let sparqlCalls = 0;
  const parentRequests: string[] = [];
  globalThis.fetch = async (input, init) => {
    const url = new URL(String(input));
    if (url.hostname === "query.wikidata.org") {
      sparqlCalls++;
      const query = new URLSearchParams(String(init?.body)).get("query") ?? "";
      if (query.includes("?item wdt:P31 ?directType")) return Response.json({ results: { bindings: [
        { item: { value: "http://www.wikidata.org/entity/Q900000001" }, directType: { value: "http://www.wikidata.org/entity/Q900000002" } },
        { item: { value: "http://www.wikidata.org/entity/Q900000001" }, directType: { value: "http://www.wikidata.org/entity/Q43229" } },
        { item: { value: "http://www.wikidata.org/entity/Q900000005" }, directType: { value: "http://www.wikidata.org/entity/Q43229" } },
      ] } });
      assertEquals(query.includes("P279*"), false);
      parentRequests.push(...[...query.matchAll(/wd:(Q[1-9][0-9]*)/g)].map(match => match[1]));
      return Response.json({ results: { bindings: [{
        type: { value: "http://www.wikidata.org/entity/Q900000002" },
        parent: { value: "http://www.wikidata.org/entity/Q33506" },
      }] } });
    }
    if (url.searchParams.get("list") === "search") return Response.json({ query: { search: [{ title: "Q900000001" }, { title: "Q900000005" }] } });
    const ids = url.searchParams.get("ids") ?? "";
    if (ids === "Q900000001") return Response.json({ entities: { Q900000001: { claims: { P625: [{ mainsnak: { datavalue: { value: { latitude: 50.08, longitude: 14.43 } } } }] }, sitelinks: {} } } });
    throw new Error(`Unexpected request ${url}`);
  };
  try {
    const rows = await createWikidataDiscoveryDeps().queryPOIs(
      { qid: "Q1085", name: "Prague", country: "Czechia", latitude: 50.0755, longitude: 14.4378, source_url: "https://www.wikidata.org/wiki/Q1085" },
      "en",
      new AbortController().signal,
    );
    assertEquals(sparqlCalls, 2);
    assertEquals(parentRequests, ["Q900000002"]);
    assertEquals(rows.map(row => row.id), ["Q900000001"]);
    assertEquals(rows[0].interests, ["culture_museums"]);
  } finally {
    globalThis.fetch = original;
  }
});

Deno.test("a missing type row in the sparse parent query fails closed instead of producing an empty catalog", async () => {
  const original = globalThis.fetch;
  globalThis.fetch = async (input, init) => {
    const url = new URL(String(input));
    if (url.hostname === "query.wikidata.org") {
      const query = new URLSearchParams(String(init?.body)).get("query") ?? "";
      if (query.includes("?item wdt:P31 ?directType")) return Response.json({ results: { bindings: [{
        item: { value: "http://www.wikidata.org/entity/Q900000003" },
        directType: { value: "http://www.wikidata.org/entity/Q900000004" },
      }] } });
      return Response.json({ results: { bindings: [] } });
    }
    if (url.searchParams.get("list") === "search") return Response.json({ query: { search: [{ title: "Q900000003" }] } });
    throw new Error(`Unexpected request ${url}`);
  };
  try {
    await assertRejects(
      () => createWikidataDiscoveryDeps().queryPOIs(
        { qid: "Q1085", name: "Prague", country: "Czechia", latitude: 50.0755, longitude: 14.4378, source_url: "https://www.wikidata.org/wiki/Q1085" },
        "en",
        new AbortController().signal,
      ),
      DiscoveryError,
      "type entity Q900000004 is unavailable",
    );
  } finally {
    globalThis.fetch = original;
  }
});

Deno.test("successful type-parent batches survive a later source failure and warm the retry", async () => {
  const original = globalThis.fetch;
  const candidateID = "Q930000001";
  const typeIDs = Array.from({ length: 501 }, (_, index) => `Q94${String(index + 1).padStart(7, "0")}`);
  const typeRequests: string[][] = [];
  let failLastBatch = true;
  globalThis.fetch = async (input, init) => {
    const url = new URL(String(input));
    if (url.hostname === "query.wikidata.org") {
      const query = new URLSearchParams(String(init?.body)).get("query") ?? "";
      if (query.includes("?item wdt:P31 ?directType")) return Response.json({ results: { bindings: typeIDs.map(type => ({
        item: { value: `http://www.wikidata.org/entity/${candidateID}` },
        directType: { value: `http://www.wikidata.org/entity/${type}` },
      })) } });
      const requested = [...query.matchAll(/wd:(Q[1-9][0-9]*)/g)].map(match => match[1]);
      typeRequests.push(requested);
      if (failLastBatch && requested.includes(typeIDs.at(-1)!)) return new Response("busy", { status: 503, headers: { "Retry-After": "30" } });
      return Response.json({ results: { bindings: requested.map(type => ({
        type: { value: `http://www.wikidata.org/entity/${type}` },
        parent: { value: "http://www.wikidata.org/entity/Q33506" },
      })) } });
    }
    if (url.searchParams.get("list") === "search") return Response.json({ query: { search: [{ title: candidateID }] } });
    const ids = (url.searchParams.get("ids") ?? "").split("|").filter(Boolean);
    assertEquals(init?.method, undefined);
    return Response.json({ entities: Object.fromEntries(ids.map(id => [id, { claims: { P625: [{ mainsnak: { datavalue: { value: { latitude: 50.08, longitude: 14.43 } } } }] }, sitelinks: {} }])) });
  };
  const city = { qid: "Q1085", name: "Prague", country: "Czechia", latitude: 50.0755, longitude: 14.4378, source_url: "https://www.wikidata.org/wiki/Q1085" };
  try {
    await assertRejects(
      () => createWikidataDiscoveryDeps().queryPOIs(city, "en", new AbortController().signal),
      DiscoveryError,
      "HTTP 503",
    );
    failLastBatch = false;
    const rows = await createWikidataDiscoveryDeps().queryPOIs(city, "en", new AbortController().signal);
    assertEquals(rows.length, 1);
    assertEquals(typeRequests.map(ids => ids.length), [500, 1, 1]);
    assertEquals(typeRequests[2], [typeIDs.at(-1)!]);
  } finally {
    globalThis.fetch = original;
  }
});

Deno.test("HTTP 200 API errors fail closed instead of becoming empty source data", async () => {
  const original = globalThis.fetch;
  globalThis.fetch = () => Promise.resolve(Response.json({ error: { code: "maxlag", lag: 30, info: "Waiting for replicas" } }));
  try {
    const error = await assertRejects(
      () => createWikidataDiscoveryDeps().searchCityEntities("Prague", "en", new AbortController().signal),
      DiscoveryError,
      "API error maxlag",
    );
    assertEquals(error.code, "source_unavailable");
    assertEquals(error.retryAfterSeconds, 30);
  } finally {
    globalThis.fetch = original;
  }
});

