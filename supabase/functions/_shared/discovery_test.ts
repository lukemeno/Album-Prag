import { assertEquals, assertThrows } from "jsr:@std/assert";
import {
  buildDiscoveryCatalog,
  classifyDiscoveryEntity,
  countWikipediaLanguageArticles,
  mergeAndRankDiscoveryItems,
  normalizeDiscoveryLanguage,
  parseDiscoveryRequest,
  searchDiscoveryCities,
  type DiscoveryDeps,
  type DiscoveryItemDTO,
} from "./discovery.ts";

Deno.test("discovery request parser is strict and normalizes supported language", () => {
  assertEquals(parseDiscoveryRequest({ protocol_version: 1, action: "search_cities", query: "  Tokyo  ", language_code: "ja-JP" }), { protocol_version: 1, action: "search_cities", query: "Tokyo", language_code: "ja" });
  assertEquals(parseDiscoveryRequest({ protocol_version: 1, action: "catalog", city_qid: "Q1085", language_code: "en-US" }).language_code, "en");
  assertEquals(normalizeDiscoveryLanguage("../../injected"), "en");
  for (const invalid of [
    { protocol_version: 2, action: "catalog", city_qid: "Q1085" },
    { protocol_version: 1, action: "catalog", city_qid: "https://example.com" },
    { protocol_version: 1, action: "search_cities", query: "x".repeat(121) },
    { protocol_version: 1, action: "catalog", city_qid: "Q1085", trip_id: "secret" },
  ]) assertThrows(() => parseDiscoveryRequest(invalid));
});

Deno.test("taxonomy allows visitable museum roots and excludes city, event, battle, airport, transit network and country types", () => {
  assertEquals(classifyDiscoveryEntity({ id: "Q1", matched_types: ["Q33506", "Q207694"] }), ["culture_museums", "art"]);
  // A visitable museum may also be classified as an institution/organization.
  assertEquals(classifyDiscoveryEntity({ id: "Q2", matched_types: ["Q33506", "Q43229"] }), ["culture_museums"]);
  // Real museum entities checked in Wikidata: National Museums in Prague/Tokyo, Louvre, and MASP.
  // Tokyo's national-museum type is a subclass of museum; Louvre and MASP are art museums.
  for (const museum of [
    { id: "Q188112", matched_types: ["Q17431399", "Q33506", "Q43229"] },
    { id: "Q653433", matched_types: ["Q17431399", "Q33506"] },
  ]) assertEquals(classifyDiscoveryEntity(museum), ["culture_museums"]);
  for (const artMuseum of [
    { id: "Q19675", matched_types: ["Q207694", "Q33506"] },
    { id: "Q82941", matched_types: ["Q207694", "Q33506"] },
    { id: "Q99999", matched_types: ["Q740437", "Q33506"] },
  ]) assertEquals(classifyDiscoveryEntity(artMuseum), ["culture_museums", "art"]);
  assertEquals(classifyDiscoveryEntity({ id: "Q2", matched_types: ["Q12280", "Q4989906"] }), ["architecture", "history"]);
  assertEquals(classifyDiscoveryEntity({ id: "Q3", matched_types: ["Q22698"] }), ["nature_parks"]);
  assertEquals(classifyDiscoveryEntity({ id: "Q4", matched_types: ["Q8502"] }), ["nature_parks"]);
  assertEquals(classifyDiscoveryEntity({ id: "Q5", matched_types: ["Q23413"] }), ["history", "architecture"]);
  assertEquals(classifyDiscoveryEntity({ id: "Q6", matched_types: ["Q1440300"] }), ["architecture", "viewpoints"]);
  for (const excluded of ["Q515", "Q6256", "Q1656682", "Q178561", "Q1248784", "Q18325841"]) {
    assertEquals(classifyDiscoveryEntity({ id: "Q3", matched_types: ["Q23413"], excluded_types: [excluded] }), []);
  }
  assertEquals(classifyDiscoveryEntity({ id: "Q4", matched_types: ["Q43229"] }), []);
});

Deno.test("only unique Wikipedia article URLs count as language coverage", () => {
  assertEquals(countWikipediaLanguageArticles({
    enwiki: { url: "https://en.wikipedia.org/wiki/Tokyo" },
    jawiki: { url: "https://ja.wikipedia.org/wiki/%E6%9D%B1%E4%BA%AC" },
    enwikiDuplicate: { url: "https://en.wikipedia.org/wiki/Tokyo" },
    commonswiki: { url: "https://commons.wikimedia.org/wiki/Tokyo" },
    wikivoyage: { url: "https://en.wikivoyage.org/wiki/Tokyo" },
    malformed: { url: "javascript:alert(1)" },
  }), 2);
});

const item = (qid: string, interests: DiscoveryItemDTO["interests"], count: number, distance: number): DiscoveryItemDTO => ({
  qid, name: qid, latitude: 0, longitude: 0, interests, wikipedia_language_count: count,
  source_url: `https://www.wikidata.org/wiki/${qid}`, distance_meters: distance,
});

Deno.test("catalog ranking deduplicates QIDs, unions themes, applies deterministic ties and limits", () => {
  const input = [item("Q2", ["history"], 20, 500), item("Q1", ["architecture"], 20, 100), item("Q2", ["architecture"], 20, 500)];
  const ranked = mergeAndRankDiscoveryItems(input);
  assertEquals(ranked.map(value => value.qid), ["Q1", "Q2"]);
  assertEquals(ranked[1].interests, ["history", "architecture"]);
  const many = Array.from({ length: 80 }, (_, index) => item(`Q${index + 10}`, ["history"], 100 - index, index));
  assertEquals(mergeAndRankDiscoveryItems(many).length, 10);
});

function baseDeps(): DiscoveryDeps {
  const city = { id: "Q1490", labels: { en: { value: "Tokyo" } }, claims: { P31: [{ mainsnak: { datavalue: { value: { id: "Q515" } } } }], P625: [{ mainsnak: { datavalue: { value: { latitude: 35.68, longitude: 139.76 } } } }], P17: [{ mainsnak: { datavalue: { value: { id: "Q17" } } } }] } };
  const country = { id: "Q17", labels: { en: { value: "Japan" } } };
  return {
    async searchCityEntities() { return [{ id: "Q1490" }, { id: "Q999" }]; },
    async getEntities(ids: string[]) { return ids.flatMap(id => id === "Q1490" ? [city] : id === "Q17" ? [country] : []); },
    async queryPOIs() { return [
      { id: "Q183536", labels: { en: { value: "Tokyo Tower" } }, descriptions: { en: { value: "tower" } }, sitelinks: { enwiki: { url: "https://en.wikipedia.org/wiki/Tokyo_Tower" }, commonswiki: { url: "https://commons.wikimedia.org/wiki/Category:Tokyo_Tower" } }, latitude: 35.6586, longitude: 139.7454, distance_meters: 3000.27, interests: ["architecture", "viewpoints"] },
      { id: "Q57965", labels: { en: { value: "Tokyo Skytree" } }, sitelinks: { enwiki: { url: "https://en.wikipedia.org/wiki/Tokyo_Skytree" } }, latitude: 35.71, longitude: 139.81, distance_meters: 9000, interests: ["architecture", "viewpoints"] },
    ]; },
    async getP18Images() { return new Map(); },
  } as unknown as DiscoveryDeps;
}

Deno.test("city search requires verified city type and a country", async () => {
  const cities = await searchDiscoveryCities("Tokyo", "en", baseDeps(), new AbortController().signal);
  assertEquals(cities, [{ qid: "Q1490", name: "Tokyo", country: "Japan", latitude: 35.68, longitude: 139.76, source_url: "https://www.wikidata.org/wiki/Q1490" }]);
});

Deno.test("catalog uses city center, exact QID source and tolerates missing licensed images", async () => {
  const catalog = await buildDiscoveryCatalog("Q1490", "en", baseDeps(), new AbortController().signal);
  assertEquals(catalog.city.qid, "Q1490");
  assertEquals(catalog.coverage.radius_meters, 25_000);
  assertEquals(catalog.items.length, 2);
  assertEquals(catalog.items[0].source_url, "https://www.wikidata.org/wiki/Q183536");
  assertEquals(catalog.items[0].wikipedia_language_count, 1);
  assertEquals(catalog.items[0].distance_meters, 3000);
  assertEquals(Number.isInteger(catalog.items[0].distance_meters), true);
  assertEquals(catalog.items[0].image, undefined);
});
