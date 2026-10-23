import { assertStringIncludes } from "jsr:@std/assert";
import { buildDiscoveryPOIQuery } from "./discovery_source.ts";

Deno.test("production POI query rejects mixed entities through every P31 type", () => {
  // A POI can have both an allowed monument type and an excluded event type.
  // The anti-join must inspect all P31 types on ?item, not just the allowed ?directType row.
  const query = buildDiscoveryPOIQuery({ qid: "Q1085", name: "Prague", country: "Czechia", latitude: 50.0755, longitude: 14.4378, source_url: "https://www.wikidata.org/wiki/Q1085" });
  assertStringIncludes(query, "?item wdt:P31 ?directType.");
  assertStringIncludes(query, "FILTER NOT EXISTS {");
  assertStringIncludes(query, "?item wdt:P31 ?excludedType.");
  assertStringIncludes(query, "?excludedType wdt:P279* ?excludedRoot.");
  assertStringIncludes(query, "VALUES ?excludedRoot { wd:Q515 wd:Q6256 wd:Q1656682 wd:Q178561 wd:Q1248784 wd:Q18325841 }");
  assertStringIncludes(query, "?directType wdt:P279* ?root.");
  assertStringIncludes(query, "LIMIT 500");
});

