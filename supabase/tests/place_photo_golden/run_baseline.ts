// Messlauf: ruft die Wikimedia-Bildsuche von place-photo lokal gegen die goldene Liste auf. Nur lesend (Wikimedia), kein Supabase.
// Aufruf: WIKIMEDIA_USER_AGENT="AlbumGoldenSet/1.0 (...)" deno run --allow-net --allow-read --allow-write --allow-env run_baseline.ts <name> <pfad-zu-_shared-ordner>
const [name, sharedArg] = Deno.args;
if (!name || !sharedArg) throw new Error("Aufruf: run_baseline.ts <name> <_shared-ordner>");
const shared = new URL(`file://${sharedArg.startsWith("/") ? sharedArg : Deno.cwd() + "/" + sharedArg}/wikimedia_photos.ts`);
const mod: any = await import(shared.href);
const golden = JSON.parse(await Deno.readTextFile(new URL("./golden.json", import.meta.url)));
const cases: any[] = golden.cases;
const byQuery = new Map(cases.map(c => [c.query, c]));
const CENTER: Record<string, [number, number]> = { Prag: [50.0875, 14.4213] }; // Ersatz, wenn ein Fall keine Referenzkoordinate hat
const sleep = (ms: number) => new Promise(r => setTimeout(r, ms));

function coordsFor(c: any): { lat: number; lng: number; stand_in: boolean } {
  const e = c.expected;
  if (typeof e.lat === "number") return { lat: e.lat, lng: e.lng, stand_in: false };
  if (c.kind === "variant") { const t = byQuery.get(c.same_as); if (t && typeof t.expected.lat === "number") return { lat: t.expected.lat, lng: t.expected.lng, stand_in: false }; }
  const [lat, lng] = CENTER[c.region] ?? CENTER.Prag; return { lat, lng, stand_in: true };
}
const expectedQid = (c: any): string | null => {
  if (c.kind === "variant") return byQuery.get(c.same_as)?.expected.wikidata ?? null;
  return c.expected.wikidata ?? null;
};

async function search(c: any) {
  const { lat, lng } = coordsFor(c);
  for (let attempt = 0; attempt < 4; attempt++) {
    try { return { images: await mod.resolveWikimedia(c.query, c.category, lat, lng, "", c.region), error: null as string | null }; }
    catch (error) {
      const msg = String((error as Error)?.message ?? error);
      if (attempt === 3) return { images: [] as any[], error: msg };
      await sleep(20_000 * (attempt + 1));
    }
  }
  return { images: [] as any[], error: "unbekannt" };
}

function judge(c: any, images: any[], error: string | null) {
  if (error) return "fehler";
  const best = images.find(i => i.confidence === "verified") ?? images[0];
  const qid = expectedQid(c);
  if (c.kind === "dish") return images.length ? (best.confidence === "verified" ? "falsch_zu_sicher" : "luecke_unsicher") : "luecke_kein_bild";
  if (c.kind === "ambiguous") return images.some(i => i.confidence === "verified") ? "falsch_zu_sicher" : (images.length ? "ok_nur_vorschlag" : "ok_kein_bild");
  if (c.kind === "chain") return images.some(i => i.confidence === "verified") ? "pruefen" : (images.length ? "ok_nur_vorschlag" : "ok_kein_bild");
  if (!images.length) return "kein_bild";
  if (qid) {
    if (best.confidence === "verified" && best.provider_place_id === qid) return "treffer";
    if (images.some(i => i.provider_place_id === qid)) return best.provider_place_id === qid ? "treffer_unsicher" : "treffer_nur_kandidat";
    return best.confidence === "verified" ? "abweichend_sicher" : "abweichend_unsicher";
  }
  return "ohne_referenz"; // Lokale ohne Beleg: nur Mensch kann urteilen
}

const out: any[] = [];
const t0 = Date.now();
for (const [i, c] of cases.entries()) {
  const k = coordsFor(c);
  const { images, error } = await search(c);
  const best = images.find((x: any) => x.confidence === "verified") ?? images[0] ?? null;
  out.push({
    id: c.id, query: c.query, region: c.region, kind: c.kind, status: judge(c, images, error), error, stand_in_coords: k.stand_in,
    expected_qid: expectedQid(c), n_images: images.length,
    best: best && { image_url: best.image_url, source_url: best.source_url, credit: best.credit, confidence: best.confidence, provider_place_id: best.provider_place_id, caption: best.caption, license_name: best.license_name },
    others: images.filter((x: any) => x !== best).slice(0, 3).map((x: any) => ({ image_url: x.image_url, confidence: x.confidence, provider_place_id: x.provider_place_id, caption: x.caption })),
  });
  await Deno.writeTextFile(new URL(`./results/${name}.json`, import.meta.url), JSON.stringify({ name, shared: sharedArg, run_at: new Date().toISOString(), progress: `${i + 1}/${cases.length}`, results: out }, null, 1));
  console.log(`${String(i + 1).padStart(3)}/${cases.length} ${c.id} ${c.query.slice(0, 24).padEnd(24)} ${out.at(-1).status}${error ? " (" + error.slice(0, 60) + ")" : ""}`);
  await sleep(500);
}
console.log(`fertig in ${Math.round((Date.now() - t0) / 1000)} s`);
