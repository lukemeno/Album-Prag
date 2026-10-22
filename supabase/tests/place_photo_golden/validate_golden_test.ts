import { assert, assertEquals } from "jsr:@std/assert";

type Case = {
  id: string; query: string; region: string; kind: string; category: string; tags: string[]; same_as: string | null; note: string;
  expected: { label_status: string; wikidata?: string; lat?: number; lng?: number; distance_m?: number; tolerance_m?: number; policy?: string; photo_kind?: string; must_not: string[] };
};
const golden = JSON.parse(await Deno.readTextFile(new URL("./golden.json", import.meta.url)));
const cases: Case[] = golden.cases;
const KINDS = ["landmark", "venue", "dish", "ambiguous", "chain", "variant"];

Deno.test("Testliste hat mindestens 100 Fälle mit eindeutigen IDs und Suchbegriffen", () => {
  assert(cases.length >= 100);
  assertEquals(new Set(cases.map(c => c.id)).size, cases.length);
  assertEquals(new Set(cases.map(c => `${c.query}|${c.region}`)).size, cases.length);
});

Deno.test("Jeder Fall hat bekannte Art, Region und Verbotsliste", () => {
  for (const c of cases) {
    assert(KINDS.includes(c.kind), `${c.id}: Art ${c.kind}`);
    assert(c.query.trim() && c.region.trim(), `${c.id}: leer`);
    assert(c.expected.must_not.length > 0, `${c.id}: must_not fehlt`);
  }
});

Deno.test("Schwierige Fälle des Nutzers sind enthalten", () => {
  const queries = new Set(cases.map(c => c.query));
  for (const q of ["Konzeptbar", "Pasta", "Fresca", "Franz-Kafka-Museum"]) assert(queries.has(q), `fehlt: ${q}`);
});

Deno.test("Abdeckung: jede Art und die schwierigen Gruppen sind vertreten", () => {
  const count = (k: string) => cases.filter(c => c.kind === k).length;
  assert(count("landmark") >= 30 && count("venue") >= 10 && count("dish") >= 10 && count("ambiguous") >= 10);
  assert(count("chain") >= 5 && count("variant") >= 5);
  assert(cases.some(c => c.tags.includes("schrift")), "nicht-lateinische Schrift fehlt");
});

Deno.test("Belegte Orte haben Wikidata-ID und Koordinaten; Regeln haben eine Richtlinie", () => {
  for (const c of cases) {
    const e = c.expected;
    if (e.label_status === "verified-wikidata") {
      assert(/^Q\d+$/.test(e.wikidata ?? ""), `${c.id}: Q-ID`);
      assert(typeof e.lat === "number" && typeof e.lng === "number", `${c.id}: Koordinaten`);
      assert((e.distance_m ?? 9e9) <= (e.tolerance_m ?? 300), `${c.id}: Abstand`);
      assert((e.tolerance_m ?? 300) <= 600, `${c.id}: Toleranz zu groß`);
    } else if (e.label_status === "rule") {
      assert(e.policy || e.photo_kind, `${c.id}: Richtlinie fehlt`);
    } else if (e.label_status === "same-as") {
      const target = cases.find(t => t.query === c.same_as);
      assert(target, `${c.id}: Verweis ${c.same_as} unbekannt`);
    } else {
      assertEquals(e.label_status, "needs-human-label");
    }
  }
});

Deno.test("Varianten verweisen auf einen belegten Ort, nicht auf Lokale ohne Beleg", () => {
  for (const c of cases.filter(x => x.kind === "variant")) {
    const target = cases.find(t => t.query === c.same_as)!;
    assertEquals(target.expected.label_status, "verified-wikidata", `${c.id} → ${c.same_as}`);
  }
});
