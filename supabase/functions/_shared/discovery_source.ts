import {
  DISCOVERY_EXCLUDED_TYPE_ROOTS,
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

const USER_AGENT = Deno.env.get("WIKIMEDIA_USER_AGENT") || "AlbumDiscoveryQA/1.0 (local development)";
const GEO_CANDIDATE_LIMIT = 500;
const HYDRATED_CANDIDATE_LIMIT = 180;
const TYPE_CANDIDATE_LIMIT = 1_000;
const TYPE_PARENT_QUERY_LIMIT = 500;
const TYPE_ANCESTOR_DEPTH_LIMIT = 32;
const TYPE_ANCESTOR_ENTITY_LIMIT = 2_500;
const TYPE_ROOT_CACHE_LIMIT = 5_000;
const TYPE_ROOT_CACHE_TTL_MS = 24 * 60 * 60 * 1_000;
const TYPE_ROOT_IDS = new Set([...DISCOVERY_TYPE_ROOTS.map(root => root.qid), ...DISCOVERY_EXCLUDED_TYPE_ROOTS]);
const TYPE_TRAVERSAL_BOUNDARY_IDS = new Set([...TYPE_ROOT_IDS, "Q43229"]); // organization: terminal but neither allowed nor globally excluded

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
const typeRootCache = new Map<string, { roots: Set<string>; expiresAt: number }>();
const typeParentCache = new Map<string, { parents: string[]; expiresAt: number }>();
let discoveryCooldownUntil = 0;

export function buildDiscoveryGeoSearch(city: DiscoveryCityDTO): string {
  return `nearcoord:25km,${city.latitude},${city.longitude}`;
}

export function buildDiscoveryDirectTypesQuery(candidateIDs: string[]): string {
  const items = [...new Set(candidateIDs)].filter(id => /^Q[1-9][0-9]*$/.test(id)).slice(0, GEO_CANDIDATE_LIMIT).map(id => `wd:${id}`).join(" ");
  return `SELECT ?item ?directType WHERE {
    VALUES ?item { ${items} }
    ?item wdt:P31 ?directType.
  }`;
}

export function buildDiscoveryParentQuery(typeIDs: string[]): string {
  const types = [...new Set(typeIDs)].filter(id => /^Q[1-9][0-9]*$/.test(id)).slice(0, TYPE_PARENT_QUERY_LIMIT).map(id => `wd:${id}`).join(" ");
  return `SELECT ?type ?parent WHERE {
    VALUES ?type { ${types} }
    ?type wikibase:statements ?statementCount.
    OPTIONAL { ?type wdt:P279 ?parent. }
  }`;
}

export function classifyDiscoveryRootIDs(rootIDs: Iterable<string>): DiscoveryInterestCode[] {
  const roots = new Set(rootIDs);
  if (DISCOVERY_EXCLUDED_TYPE_ROOTS.some(root => roots.has(root))) return [];
  return [...new Set(DISCOVERY_TYPE_ROOTS.flatMap(root => roots.has(root.qid) ? [root.interest] : []))];
}

function claimEntityIDs(entity: WikidataEntity, property: string): string[] {
  return (entity.claims?.[property] ?? []).flatMap(claim => {
    const value = claim.mainsnak?.datavalue?.value as { id?: unknown } | undefined;
    return typeof value?.id === "string" && /^Q[1-9][0-9]*$/.test(value.id) ? [value.id] : [];
  });
}

function hasValueClaim(entity: WikidataEntity, property: string): boolean {
  return (entity.claims?.[property] ?? []).some(claim =>
    claim.mainsnak?.snaktype === "value" && claim.mainsnak?.datavalue?.value !== undefined
  );
}

function entityCoordinates(entity: WikidataEntity): Array<{ latitude: number; longitude: number }> {
  return (entity.claims?.P625 ?? []).flatMap(claim => {
    const value = claim.mainsnak?.datavalue?.value as { latitude?: unknown; longitude?: unknown } | undefined;
    const latitude = Number(value?.latitude), longitude = Number(value?.longitude);
    return Number.isFinite(latitude) && Number.isFinite(longitude) && latitude >= -90 && latitude <= 90 && longitude >= -180 && longitude <= 180
      ? [{ latitude, longitude }]
      : [];
  });
}

function distanceMeters(latitude: number, longitude: number, centerLatitude: number, centerLongitude: number): number {
  const radians = Math.PI / 180;
  const deltaLatitude = (centerLatitude - latitude) * radians;
  const deltaLongitude = (centerLongitude - longitude) * radians;
  const a = Math.sin(deltaLatitude / 2) ** 2 + Math.cos(latitude * radians) * Math.cos(centerLatitude * radians) * Math.sin(deltaLongitude / 2) ** 2;
  return 6_371_000 * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

export function createWikidataDiscoveryDeps(): DiscoveryDeps {
  const hydratedEntities = new Map<string, WikidataEntity>();
  async function waitForCooldown(signal: AbortSignal) {
    const delay = discoveryCooldownUntil - Date.now();
    if (delay <= 0) return;
    await new Promise<void>((resolve, reject) => {
      const timer = setTimeout(() => { signal.removeEventListener("abort", onAbort); resolve(); }, delay);
      const onAbort = () => { clearTimeout(timer); reject(signal.reason); };
      signal.addEventListener("abort", onAbort, { once: true });
    });
  }
  async function getJSON(url: URL, signal: AbortSignal, init: RequestInit = {}): Promise<any> {
    return discoverySemaphore.run(signal, async () => {
      for (let attempt = 0; attempt < 2; attempt++) {
        await waitForCooldown(signal);
        let response: Response;
        try {
          response = await fetch(url, {
            ...init,
            headers: { "User-Agent": USER_AGENT, Accept: "application/sparql-results+json, application/json", ...(init.headers ?? {}) },
            signal,
          });
        }
        catch (error) { throw new DiscoveryError("source_unavailable", `Discovery source request failed: ${String(error)}`); }
        if (response.ok) {
          const payload = await response.json();
          if (!payload?.error) return payload;
          const code = String(payload.error.code ?? "unknown");
          const retryAfter = Math.max(1, Number(response.headers.get("retry-after")) || Number(payload.error.lag) || 30);
          if (code === "ratelimited") discoveryCooldownUntil = Math.max(discoveryCooldownUntil, Date.now() + retryAfter * 1000);
          if ((code === "maxlag" || code === "ratelimited") && attempt === 0 && retryAfter <= 2 && !signal.aborted) {
            if (code === "ratelimited") continue;
            await new Promise((resolve, reject) => {
              const timer = setTimeout(resolve, retryAfter * 1000);
              signal.addEventListener("abort", () => { clearTimeout(timer); reject(signal.reason); }, { once: true });
            });
            continue;
          }
          throw new DiscoveryError("source_unavailable", `Discovery source returned API error ${code}`, retryAfter);
        }
        const retryAfter = Math.max(1, Number(response.headers.get("retry-after")) || 1);
        if (response.status === 429) discoveryCooldownUntil = Math.max(discoveryCooldownUntil, Date.now() + retryAfter * 1000);
        await response.body?.cancel();
        if ((response.status === 429 || response.status === 503) && attempt === 0 && retryAfter <= 2 && !signal.aborted) {
          if (response.status === 429) continue;
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
  async function sparql(query: string, signal: AbortSignal) {
    const body = new URLSearchParams({ query, format: "json" });
    const url = new URL("https://query.wikidata.org/sparql");
    const querySignal = AbortSignal.any([signal, AbortSignal.timeout(8_000)]);
    return await getJSON(url, querySignal, {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded;charset=UTF-8" },
      body,
    });
  }
  function cachedRoots(type: string, now: number): Set<string> | undefined {
    if (TYPE_TRAVERSAL_BOUNDARY_IDS.has(type)) return new Set([type]);
    const cached = typeRootCache.get(type);
    if (cached && cached.expiresAt > now) return cached.roots;
    typeRootCache.delete(type);
    return undefined;
  }
  function cacheRoots(type: string, roots: Set<string>, now: number) {
    typeRootCache.set(type, { roots, expiresAt: now + TYPE_ROOT_CACHE_TTL_MS });
    while (typeRootCache.size > TYPE_ROOT_CACHE_LIMIT) typeRootCache.delete(typeRootCache.keys().next().value!);
  }
  function cachedParents(type: string, now: number): string[] | undefined {
    const cached = typeParentCache.get(type);
    if (cached && cached.expiresAt > now) return cached.parents;
    typeParentCache.delete(type);
    return undefined;
  }
  function cacheParents(type: string, parents: string[], now: number) {
    typeParentCache.set(type, { parents, expiresAt: now + TYPE_ROOT_CACHE_TTL_MS });
    while (typeParentCache.size > TYPE_ROOT_CACHE_LIMIT) typeParentCache.delete(typeParentCache.keys().next().value!);
  }
  async function loadTypeParents(typeIDs: string[], signal: AbortSignal, now: number): Promise<Map<string, string[]>> {
    const result = new Map<string, string[]>();
    const uncached: string[] = [];
    for (const type of typeIDs) {
      const parents = cachedParents(type, now);
      if (parents === undefined) uncached.push(type);
      else result.set(type, parents);
    }
    const batches: string[][] = [];
    for (let offset = 0; offset < uncached.length; offset += TYPE_PARENT_QUERY_LIMIT) batches.push(uncached.slice(offset, offset + TYPE_PARENT_QUERY_LIMIT));
    for (let offset = 0; offset < batches.length; offset += 2) {
      const group = batches.slice(offset, offset + 2);
      const settled = await Promise.allSettled(group.map(batch => sparql(buildDiscoveryParentQuery(batch), signal)));
      let failure: unknown;
      for (let index = 0; index < settled.length; index++) {
        const outcome = settled[index];
        if (outcome.status === "rejected") {
          failure ??= outcome.reason;
          continue;
        }
        const parentsByType = new Map<string, string[]>();
        for (const binding of outcome.value.results?.bindings ?? []) {
          const type = String(binding.type?.value ?? "").split("/").pop() ?? "";
          const parent = String(binding.parent?.value ?? "").split("/").pop() ?? "";
          if (!group[index].includes(type)) continue;
          const parents = parentsByType.get(type) ?? [];
          if (/^Q[1-9][0-9]*$/.test(parent) && !parents.includes(parent)) parents.push(parent);
          parentsByType.set(type, parents);
        }
        for (const type of group[index]) {
          const parents = parentsByType.get(type);
          if (!parents) {
            failure ??= new DiscoveryError("source_unavailable", `Wikidata type entity ${type} is unavailable`);
            continue;
          }
          result.set(type, parents);
          cacheParents(type, parents, now);
        }
      }
      if (failure) throw failure;
    }
    return result;
  }
  async function resolveTypeRoots(directTypeIDs: string[], signal: AbortSignal): Promise<Map<string, Set<string>>> {
    const directTypes = [...new Set(directTypeIDs)].filter(id => /^Q[1-9][0-9]*$/.test(id));
    if (directTypes.length > TYPE_CANDIDATE_LIMIT) throw new DiscoveryError("source_unavailable", "Wikidata type set exceeded its safety bound");
    const now = Date.now();
    const parents = new Map<string, string[]>();
    const seen = new Set<string>();
    let frontier = directTypes.filter(type => cachedRoots(type, now) === undefined);
    let depth = 0;
    while (frontier.length) {
      if (depth >= TYPE_ANCESTOR_DEPTH_LIMIT) throw new DiscoveryError("source_unavailable", `Wikidata type hierarchy exceeded depth ${TYPE_ANCESTOR_DEPTH_LIMIT} (nodes=${seen.size}, frontier=${frontier.length})`);
      if (seen.size + frontier.length > TYPE_ANCESTOR_ENTITY_LIMIT) throw new DiscoveryError("source_unavailable", `Wikidata type hierarchy exceeded ${TYPE_ANCESTOR_ENTITY_LIMIT} entities (depth=${depth}, nodes=${seen.size}, frontier=${frontier.length})`);
      depth++;
      for (const id of frontier) seen.add(id);
      const parentMap = await loadTypeParents(frontier, signal, now);
      const next = new Set<string>();
      for (const id of frontier) {
        const parentIDs = parentMap.get(id);
        if (!parentIDs) throw new DiscoveryError("source_unavailable", `Wikidata type entity ${id} is unavailable`);
        parents.set(id, parentIDs);
        for (const parent of parentIDs) {
          if (!seen.has(parent) && cachedRoots(parent, now) === undefined) next.add(parent);
        }
      }
      frontier = [...next];
    }

    const resolved = new Map([...parents.keys()].map(type => [type, new Set<string>()]));
    for (let pass = 0; pass <= TYPE_ANCESTOR_DEPTH_LIMIT; pass++) {
      let changed = false;
      for (const [type, parentIDs] of parents) {
        const roots = resolved.get(type)!;
        for (const parent of parentIDs) {
          const parentRoots = cachedRoots(parent, now) ?? resolved.get(parent) ?? new Set<string>();
          for (const root of parentRoots) if (!roots.has(root)) {
            roots.add(root);
            changed = true;
          }
        }
      }
      if (!changed) break;
      if (pass === TYPE_ANCESTOR_DEPTH_LIMIT) throw new DiscoveryError("source_unavailable", "Wikidata type hierarchy did not converge within its safety bound");
    }
    const result = new Map(directTypes.map(type => [type, cachedRoots(type, now) ?? resolved.get(type) ?? new Set<string>()]));
    for (const [type, roots] of resolved) cacheRoots(type, roots, now);
    return result;
  }
  async function classifyCandidates(candidateIDs: string[], signal: AbortSignal): Promise<Map<string, DiscoveryInterestCode[]>> {
    if (!candidateIDs.length) return new Map();
    const directPayload = await sparql(buildDiscoveryDirectTypesQuery(candidateIDs), signal);
    const typesByID = new Map<string, Set<string>>();
    for (const binding of directPayload.results?.bindings ?? []) {
      const id = String(binding.item?.value ?? "").split("/").pop() ?? "";
      const type = String(binding.directType?.value ?? "").split("/").pop() ?? "";
      if (!/^Q[1-9][0-9]*$/.test(id) || !/^Q[1-9][0-9]*$/.test(type)) continue;
      const types = typesByID.get(id) ?? new Set<string>();
      types.add(type); typesByID.set(id, types);
    }
    const allTypes = [...new Set([...typesByID.values()].flatMap(types => [...types]))];
    const rootsByType = await resolveTypeRoots(allTypes, signal);
    return new Map([...typesByID].flatMap(([id, types]) => {
      const roots = new Set([...types].flatMap(type => [...(rootsByType.get(type) ?? [])]));
      const interests = classifyDiscoveryRootIDs(roots);
      return interests.length ? [[id, interests] as const] : [];
    }));
  }
  async function fetchEntities(ids: string[], language: string, props: string, signal: AbortSignal): Promise<WikidataEntity[]> {
    const unique = [...new Set(ids)].filter(id => /^Q[1-9][0-9]*$/.test(id));
    const batches: string[][] = [];
    for (let offset = 0; offset < unique.length; offset += 50) batches.push(unique.slice(offset, offset + 50));
    const payloads: any[] = [];
    for (let offset = 0; offset < batches.length; offset += 2) {
      payloads.push(...await Promise.all(batches.slice(offset, offset + 2).map(batch => wikidata({
        action: "wbgetentities", ids: batch.join("|"), props,
        ...(props.includes("labels") || props.includes("descriptions") ? { languages: [...new Set([language, "en"])].join("|") } : {}),
      }, signal))));
    }
    return payloads.flatMap(payload => (Object.entries(payload.entities ?? {}) as Array<[string, any]>).flatMap(([id, raw]) => !raw || Object.prototype.hasOwnProperty.call(raw, "missing") ? [] : [{
      ...raw,
      id,
      image_title: raw.claims?.P18?.[0]?.mainsnak?.datavalue?.value,
    }]));
  }
  async function getEntities(ids: string[], language: string, signal: AbortSignal): Promise<WikidataEntity[]> {
    return await fetchEntities(ids, language, "labels|descriptions|claims|sitelinks/urls", signal);
  }
  return {
    searchCityEntities: async (query, language, signal) => {
      const payload = await wikidata({ action: "wbsearchentities", search: query, language, uselang: language, type: "item", limit: "20" }, signal);
      return (payload.search ?? []).flatMap((item: any) => typeof item.id === "string" ? [item] : []);
    },
    getEntities,
    queryPOIs: async (city: DiscoveryCityDTO, language, signal): Promise<DiscoveryPOIRow[]> => {
      const payload = await wikidata({
        action: "query", list: "search", srsearch: buildDiscoveryGeoSearch(city), srnamespace: "0",
        srlimit: String(GEO_CANDIDATE_LIMIT), srprop: "",
      }, signal);
      const candidateIDs: string[] = (payload.query?.search ?? []).flatMap((entry: any) => typeof entry.title === "string" && /^Q[1-9][0-9]*$/.test(entry.title) ? [entry.title] : []);
      const interestsByID = await classifyCandidates(candidateIDs, signal);
      const selectedIDs = candidateIDs.filter(id => interestsByID.has(id)).slice(0, HYDRATED_CANDIDATE_LIMIT);
      const entities = await getEntities(selectedIDs, language, signal);
      for (const entity of entities) hydratedEntities.set(entity.id, entity);
      return entities.flatMap(entity => {
        const interests = interestsByID.get(entity.id) ?? [];
        if (!interests.length || hasValueClaim(entity, "P576")) return [];
        const coordinates = entityCoordinates(entity).map(coordinate => ({
          ...coordinate,
          distance: distanceMeters(coordinate.latitude, coordinate.longitude, city.latitude, city.longitude),
        })).filter(coordinate => coordinate.distance <= 25_000).sort((a, b) => a.distance - b.distance);
        const coordinate = coordinates[0];
        if (!coordinate) return [];
        return [{ ...entity, latitude: coordinate.latitude, longitude: coordinate.longitude, distance_meters: coordinate.distance, interests }];
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
