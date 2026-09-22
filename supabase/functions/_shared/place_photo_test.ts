import { assertEquals, assert } from "jsr:@std/assert";
import { choosePlace, rankCandidate, stripHTML, tokenSimilarity } from "./place_photo.ts";

Deno.test("exact nearby place wins over a different landmark", () => {
  const place = choosePlace([
    { id: "metronome", name: "Prague Metronome", latitude: 50.0948, longitude: 14.4157 },
    { id: "letna", name: "Letná", latitude: 50.0957, longitude: 14.4165 },
  ], "Letná", 50.0966, 14.4193);
  assertEquals(place?.id, "letna");
});

Deno.test("distant and weak matches are rejected", () => {
  assertEquals(rankCandidate({ id: "wrong", name: "Letná Café", latitude: 49.9, longitude: 14.4 }, "Letná", 50.0966, 14.4193), null);
  assertEquals(rankCandidate({ id: "wrong", name: "Completely Different", latitude: 50.0966, longitude: 14.4193 }, "Letná", 50.0966, 14.4193), null);
});

Deno.test("name scoring and metadata cleanup are deterministic", () => {
  assert(tokenSimilarity("Café Louvre", "Cafe Louvre") >= 0.99);
  assertEquals(stripHTML("<a href='#'>Anna&nbsp;Novák</a>"), "Anna Novák");
});
