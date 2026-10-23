import {
  DISCOVERY_TYPE_ROOTS,
  DiscoveryError,
  type DiscoveryCityDTO,
  type DiscoveryDeps,
  type DiscoveryImageDTO,
  type DiscoveryInterestCode,
  type DiscoveryPOIRow,
  type WikidataEntity,
} from "./discovery.ts";
import { fetchWikimediaP18Images } from "./wikimedia_photos.ts";

const USER_AGENT = "Album/1.0 (travel discovery; https://www.wikidata.org/wiki/Wikidata:Data_access)";

class Semaphore {
  private active = 0;
  private readonly waiting: Array<() => void> = [];
  constructor(private readonly maximum: number) {}
  async run<T>(signal: AbortSignal, work: () => Promise<T>): Promise<T> {
    if (signal.aborted) throw signal.reason;
    if (this.active >= this.maximum) await new Promise<void>((resolve, reject) => {
      const onAbort = () => { this.waiting.splice(this.waiting.indexOf(wake), 1); reject(signal.reason); };
      const wake = () => { signal.removeEventListener("abort", onAbort); resolve(); };
      signal.addEventListener("abort", onAbort, { once: true });
      this.waiting.push(wake);
    });
    if (signal.aborted) throw signal.reason;
    this.active++;
    try { return await work(); }
    finally { this.active--; this.waiting.shift()?.(); }
  }
}

// Shared across requests within one Edge isolate; cache leases and per-user limits bound misses across isolates.
const discoverySemaphore = new Semaphore(2);

export function buildDiscoveryPOIQuery(city: DiscoveryCityDTO): string {
  const interestValues = DISCOVERY_TYPE_ROOTS.map(root => `(\"${root.interest}\" wd:${root.qid})`).join(" ");
  const excludedValues = ["Q515", "Q6256", "Q1656682", "Q178561", "Q1248784", "Q18325841"].map(qid => `wd:${qid}`).join(" ");
  return `SELECT ?item ?coord ?distance ?interest ?sitelinks WHERE {
    {
      SELECT ?item ?coord ?distance ?sitelinks WHERE {
        SERVICE wikibase:around {
          ?item wdt:P625 ?coord.
          bd:serviceParam wikibase:center "Point(${city.longitude} ${city.latitude})"^^geo:wktLiteral;
            wikibase:radius "25";
            wikibase:distance ?distance.
        }
        ?item wikibase:sitelinks ?sitelinks.
        FILTER(?sitelinks >= 1)
      }
      ORDER BY DESC(?sitelinks) ASC(?distance)
      LIMIT 500
    }
    VALUES (?interest ?root) { ${interestValues} }
    ?item wdt:P31 ?directType.
    ?directType wdt:P279* ?root.
    FILTER NOT EXISTS {
      ?item wdt:P31 ?excludedType.
      VALUES ?excludedRoot { ${excludedValues} }
      ?excludedType wdt:P279* ?excludedRoot.
    }
  }
  ORDER BY DESC(?sitelinks) ASC(?distance)
  LIMIT 300`;
}

export function createWikidataDiscoveryDeps(): DiscoveryDeps {
  const hydratedEntities = new Map<string, WikidataEntity>();
  async function getJSON(url: URL, signal: AbortSignal): Promise<any> {
    return discoverySemaphore.run(signal, async () => {
      for (let attempt = 0; attempt < 2; attempt++) {
        let response: Response;
        try { response = await fetch(url, { headers: { "User-Agent": USER_AGENT, Accept: "application/sparql-results+json, application/json" }, signal }); }
        catch (error) { throw new DiscoveryError("source_unavailable", `Discovery source request failed: ${String(error)}`); }
        if (response.ok) return await response.json();
        const retryAfter = Math.max(1, Number(response.headers.get("retry-after")) || 1);
        await response.body?.cancel();
        if ((response.status === 429 || response.status === 503) && attempt === 0 && retryAfter <= 2 && !signal.aborted) {
          await new Promise((resolve, reject) => {
            const timer = setTimeout(resolve, retryAfter * 1000);
            signal.addEventListener("abort", () => { clearTimeout(timer); reject(signal.reason); }, { once: true });
          });
          continue;
        }
        throw new DiscoveryError("source_unavailable", `Discovery source returned HTTP ${response.status}`, retryAfter);
      }
      throw new DiscoveryError("source_unavailable", "Discovery source retry exhausted");
    });
  }
  async function wikidata(params: Record<string, string>, signal: AbortSignal) {
    const url = new URL("https://www.wikidata.org/w/api.php");
    for (const [key, value] of Object.entries({ format: "json", ...params })) url.searchParams.set(key, value);
    return await getJSON(url, signal);
  }
  async function getEntities(ids: string[], language: string, signal: AbortSignal): Promise<WikidataEntity[]> {
    const unique = [...new Set(ids)].filter(id => /^Q[1-9][0-9]*$/.test(id));
    const result: WikidataEntity[] = [];
    for (let offset = 0; offset < unique.length; offset += 50) {
      const batch = unique.slice(offset, offset + 50);
      const payload = await wikidata({ action: "wbgetentities", ids: batch.join("|"), props: "labels|descriptions|claims|sitelinks/urls", languages: [...new Set([language, "en"])].join("|") }, signal);
      for (const [id, raw] of Object.entries(payload.entities ?? {}) as Array<[string, any]>) {
        const coordinate = raw.claims?.P625?.[0]?.mainsnak?.datavalue?.value;
        result.push({ ...raw, id, latitude: coordinate?.latitude, longitude: coordinate?.longitude, image_title: raw.claims?.P18?.[0]?.mainsnak?.datavalue?.value });
      }
    }
    return result;
  }
  return {
    searchCityEntities: async (query, language, signal) => {
      const payload = await wikidata({ action: "wbsearchentities", search: query, language, uselang: language, type: "item", limit: "20" }, signal);
      return (payload.search ?? []).flatMap((item: any) => typeof item.id === "string" ? [item] : []);
    },
    getEntities,
    queryPOIs: async (city: DiscoveryCityDTO, language, signal): Promise<DiscoveryPOIRow[]> => {
      const interests: DiscoveryInterestCode[] = ["culture_museums", "history", "architecture", "nature_parks", "viewpoints", "art"];
      const querySignal = AbortSignal.any([signal, AbortSignal.timeout(12_000)]);
      const query = buildDiscoveryPOIQuery(city);
      const url = new URL("https://query.wikidata.org/sparql"); url.searchParams.set("query", query); url.searchParams.set("format", "json");
      const payload = await getJSON(url, querySignal);
      const rows = (payload.results?.bindings ?? []).flatMap((binding: any) => {
        const interest = binding.interest?.value;
        return interests.includes(interest) ? [{ binding, interest: interest as DiscoveryInterestCode }] : [];
      });
      const perInterest = new Map<DiscoveryInterestCode, Map<string, { latitude: number; longitude: number; distance: number; sitelinks: number }>>();
      for (const { binding, interest } of rows) {
        const id = binding.item?.value?.split("/").pop();
        const point = binding.coord?.value?.match(/Point\(([-\d.]+) ([-\d.]+)\)/);
        if (!id || !point || !interests.includes(interest)) continue;
        const entries = perInterest.get(interest) ?? new Map();
        if (!entries.has(id)) entries.set(id, { latitude: Number(point[2]), longitude: Number(point[1]), distance: Number(binding.distance?.value) * 1000, sitelinks: Number(binding.sitelinks?.value) || 0 });
        perInterest.set(interest, entries);
      }
      const byID = new Map<string, { interests: Set<DiscoveryInterestCode>; latitude: number; longitude: number; distance: number }>();
      for (const [interest, entries] of perInterest) for (const [id, value] of entries) {
        const previous = byID.get(id) ?? { interests: new Set<DiscoveryInterestCode>(), latitude: value.latitude, longitude: value.longitude, distance: value.distance };
        previous.interests.add(interest); byID.set(id, previous);
      }
      const selectedIDs: string[] = [];
      const selectionLists = interests.map(interest => [...(perInterest.get(interest) ?? new Map()).entries()].sort((a, b) => b[1].sitelinks - a[1].sitelinks || a[0].localeCompare(b[0])));
      for (let round = 0; selectedIDs.length < 50 && selectionLists.some(list => list.length); round++) {
        for (const list of selectionLists) {
          const candidate = list.shift()?.[0];
          if (candidate && !selectedIDs.includes(candidate) && byID.has(candidate) && selectedIDs.length < 50) selectedIDs.push(candidate);
        }
      }
      const entitySignal = AbortSignal.any([signal, AbortSignal.timeout(3_000)]);
      const entities = await getEntities(selectedIDs, language, entitySignal);
      const entityByID = new Map(entities.map(entity => [entity.id, entity]));
      for (const entity of entities) hydratedEntities.set(entity.id, entity);
      return selectedIDs.flatMap(id => {
        const values = byID.get(id)!;
        const entity = entityByID.get(id);
        if (!entity) return [];
        const interestsForPlace = interests.filter(interest => perInterest.get(interest)?.has(id));
        return [{ ...entity, latitude: values.latitude, longitude: values.longitude, distance_meters: values.distance, interests: interestsForPlace }];
      });
    },
    getP18Images: async (qids: string[], signal): Promise<Map<string, DiscoveryImageDTO>> => {
      const imageEntries = qids.flatMap(qid => {
        const title = hydratedEntities.get(qid)?.image_title;
        return typeof title === "string" ? [{ qid, title }] : [];
      });
      const timeoutSignal = AbortSignal.any([signal, AbortSignal.timeout(3_000)]);
      return await fetchWikimediaP18Images(imageEntries, timeoutSignal, discoverySemaphore);
    },
  };
}

export type DiscoveryImageEntry = { qid: string; title: string };
