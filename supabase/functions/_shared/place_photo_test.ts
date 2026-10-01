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

import { rankPhotos, scorePhoto } from "./place_photo.ts";

const photo = (title: string, extra: Partial<import("./place_photo.ts").PhotoCandidate> = {}) =>
  ({ title, source: "category" as const, uses: 0, assessments: "", width: 3000, height: 2000, ...extra });

Deno.test("a viewpoint does not borrow an unnamed nearby panorama", () => {
  const ranked = rankPhotos([
    photo("File:Praha, Letná, sad.jpg", { source: "main" }),
    photo("File:Praha, Letná, Toyota Arena.jpg", { uses: 5, source: "nearby" }),
    photo("File:Vltava in Prague at sunset.jpg", { uses: 2, assessments: "quality", source: "nearby" }),
  ], "Letná", "Aussicht");
  assertEquals(ranked[0].photo.title, "File:Praha, Letná, sad.jpg");
  assert(!ranked.some(item => item.photo.title === "File:Vltava in Prague at sunset.jpg"));
});

Deno.test("protests, maps and unrelated nearby photos are dropped", () => {
  assertEquals(scorePhoto(photo("File:Demonstrace na Letné 01.jpg"), "Letná", "Aussicht"), null);
  assertEquals(scorePhoto(photo("File:Mapa Letná.jpg"), "Letná", "Aussicht"), null);
  assertEquals(scorePhoto(photo("File:Spálená, kostel.jpg", { source: "nearby" }), "Letná", "Aussicht"), null);
  assertEquals(scorePhoto(photo("File:Letná.svg"), "Letná", "Aussicht"), null);
});

Deno.test("a café prefers its interior", () => {
  const ranked = rankPhotos([
    photo("File:Café Louvre, Národní 22.jpg", { source: "main" }),
    photo("File:Café Louvre interior.jpg"),
  ], "Café Louvre", "Essen & Trinken");
  assertEquals(ranked[0].photo.title, "File:Café Louvre interior.jpg");
});

Deno.test("only the best photo of a series is kept", () => {
  const ranked = rankPhotos([
    photo("File:1Procházka po Karlově mostě 20250818 182341.jpg"),
    photo("File:1Procházka po Karlově mostě 20250818 182343.jpg"),
    photo("File:Charles Bridge at dawn.jpg", { uses: 3 }),
  ], ["Karlův most", "Charles Bridge"], "Sehenswert");
  assertEquals(ranked.length, 2);
  assertEquals(ranked[0].photo.title, "File:Charles Bridge at dawn.jpg");
});

Deno.test("a sight needs photos of itself, not views from nearby towers", () => {
  const names = ["Karlsbrücke", "Karlův most", "Charles Bridge"];
  assertEquals(scorePhoto(photo("File:Prague View from Petrinska Tower.jpg", { source: "nearby" }), names, "Sehenswert"), null);
  assert(scorePhoto(photo("File:Procházka po Karlově mostě.jpg", { source: "nearby" }), names, "Sehenswert") !== null);
  assert(scorePhoto(photo("File:Charles Bridge at night.jpg", { source: "nearby" }), names, "Sehenswert") !== null);
});

Deno.test("a view taken from the sight ranks below a photo of it", () => {
  const names = ["Karlsbrücke", "Charles Bridge"];
  const ranked = rankPhotos([
    photo("File:Prague View from Charles Bridge of Smetana Museum.jpg", { source: "nearby", uses: 4 }),
    photo("File:Prague Charles Bridge.jpg", { source: "nearby" }),
  ], names, "Sehenswert");
  assertEquals(ranked[0].photo.title, "File:Prague Charles Bridge.jpg");
});

Deno.test("an unrelated panorama cannot stand in for a viewpoint", () => {
  assertEquals(scorePhoto(photo("File:Vltava in Prague at sunset.jpg", { source: "nearby", uses: 10 }), "Letná", "Aussicht"), null);
});

Deno.test("a view from a sight is rejected even when it is the only candidate", () => {
  assertEquals(rankPhotos([photo("File:Prague View from Charles Bridge of Smetana Museum.jpg", { source: "main", uses: 10 })], "Charles Bridge", "Sehenswert"), []);
});

Deno.test("a matching branch far from the selected place is rejected", () => {
  assertEquals(choosePlace([{ id: "other", name: "Café Louvre", latitude: 50.092, longitude: 14.4185 }], "Café Louvre", 50.0819, 14.4185), undefined);
});

Deno.test("a shared generic word does not identify a different restaurant", () => {
  assertEquals(choosePlace([{ id: "other", name: "Café Louvre Gallery", latitude: 50.0819, longitude: 14.4185 }], "Café Louvre", 50.0819, 14.4185), undefined);
});

Deno.test("ambiguous nearby entities require confirmation", () => {
  assertEquals(choosePlace([
    { id: "one", name: "Café Louvre", latitude: 50.0819, longitude: 14.4185 },
    { id: "two", name: "Café Louvre", latitude: 50.082, longitude: 14.4185 },
  ], "Café Louvre", 50.0819, 14.4185), undefined);
});

Deno.test("a conflicting house number rejects an otherwise exact place", () => {
  const candidate = { id: "one", name: "Café Louvre", latitude: 50.0819, longitude: 14.4185, address: "Národní 22" };
  assertEquals(choosePlace([candidate], "Café Louvre", 50.0819, 14.4185, "Národní 24, Prag"), undefined);
  assertEquals(choosePlace([candidate], "Café Louvre", 50.0819, 14.4185, "Národní 116/22, Prag")?.id, "one");
});

Deno.test("structured evidence alone does not make an unnamed panorama automatic", () => {
  const ranked = rankPhotos([photo("File:Vltava in Prague at sunset.jpg", { source: "nearby", depictsPlace: true })], "Letná", "Aussicht");
  assertEquals(ranked[0].confidence, "suggested");
});

Deno.test("a named viewpoint with structured evidence can be automatic", () => {
  const ranked = rankPhotos([photo("File:View from Letná over Prague.jpg", { source: "nearby", depictsPlace: true })], "Letná", "Aussicht");
  assertEquals(ranked[0].confidence, "verified");
});

Deno.test("an orchard main image is not an automatic viewpoint photo", () => {
  const ranked = rankPhotos([photo("File:Praha Letná sad.jpg", { source: "main" })], "Letná", "Aussicht");
  assertEquals(ranked[0].confidence, "suggested");
});

Deno.test("a nearby name match stays a suggestion without entity evidence", () => {
  const ranked = rankPhotos([photo("File:Charles Bridge at night.jpg", { source: "nearby" })], "Charles Bridge", "Sehenswert");
  assertEquals(ranked[0].confidence, "suggested");
});

Deno.test("low quality leftovers are not selected", () => {
  assertEquals(rankPhotos([photo("File:Charles Bridge.jpg", { width: 400, height: 800 })], "Charles Bridge", "Sehenswert"), []);
});

Deno.test('Prague district number does not replace the street house number', () => {
  const place = { id: 'Q12879009', name: 'Café Louvre', latitude: 50.082014, longitude: 14.418599, address: 'Praha 1-Nové Město, Národní 1987/22' };
  assertEquals(choosePlace([place], 'Café Louvre', 50.08199, 14.41944, 'Národní 22, Praha'), place);
  assertEquals(choosePlace([place], 'Café Louvre', 50.08199, 14.41944, 'Národní 24, Praha'), undefined);
});
