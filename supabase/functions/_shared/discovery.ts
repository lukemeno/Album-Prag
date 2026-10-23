import { validCoordinate } from "./place_photo.ts";
import { supportedWikipediaLanguage } from "./photo_context.ts";

export const DISCOVERY_PROTOCOL_VERSION = 1;
export const CATALOG_VERSION = 1;
export const RANKING_VERSION = 1;
export const RADIUS_METERS = 25_000;
export const MAX_ITEMS = 60;

export type DiscoveryInterestCode = "culture_museums" | "history" | "architecture" | "nature_parks" | "viewpoints" | "art";
export type DiscoveryCityDTO = { qid: string; name: string; country: string; latitude: number; longitude: number; source_url: string };
export type DiscoveryImageDTO = { image_url: string; source_url: string; credit: string; provider: "wikimedia"; license_name: string; license_url: string; provider_place_id: string; confidence: "verified"; caption?: string };
export type DiscoveryItemDTO = { qid: string; name: string; description?: string; latitude: number; longitude: number; interests: DiscoveryInterestCode[]; wikipedia_language_count: number; source_url: string; distance_meters: number; image?: DiscoveryImageDTO };
export type SearchCitiesRequest = { protocol_version: 1; action: "search_cities"; query: string; language_code: string };
export type CatalogRequest = { protocol_version: 1; action: "catalog"; city_qid: string; language_code: string };
export type DiscoveryRequest = SearchCitiesRequest | CatalogRequest;

export class DiscoveryError extends Error {
  constructor(readonly code: "invalid_request" | "rate_limited" | "source_unavailable" | "disabled", message: string, readonly retryAfterSeconds?: number) { super(message); }
}

export function validQID(value: unknown): value is string { return typeof value === "string" && /^Q[1-9][0-9]*$/.test(value); }

export function normalizeDiscoveryLanguage(value: unknown): string {
  return supportedWikipediaLanguage(value)?.split("-")[0].toLowerCase() ?? "en";
}

export function parseDiscoveryRequest(value: unknown): DiscoveryRequest {
  if (!value || typeof value !== "object" || Array.isArray(value)) throw new DiscoveryError("invalid_request", "Invalid request");
  const body = value as Record<string, unknown>;
  if (body.protocol_version !== DISCOVERY_PROTOCOL_VERSION) throw new DiscoveryError("invalid_request", "Unsupported protocol version");
  const language_code = normalizeDiscoveryLanguage(body.language_code);
  if (body.action === "search_cities") {
    if (Object.keys(body).some(key => !["protocol_version", "action", "query", "language_code"].includes(key))) throw new DiscoveryError("invalid_request", "Unexpected request field");
    if (typeof body.query !== "string" || !body.query.trim() || body.query.length > 120) throw new DiscoveryError("invalid_request", "Invalid city query");
    return { protocol_version: 1, action: "search_cities", query: body.query.trim(), language_code };
  }
  if (body.action === "catalog") {
    if (Object.keys(body).some(key => !["protocol_version", "action", "city_qid", "language_code"].includes(key))) throw new DiscoveryError("invalid_request", "Unexpected request field");
    if (!validQID(body.city_qid)) throw new DiscoveryError("invalid_request", "Invalid city QID");
    return { protocol_version: 1, action: "catalog", city_qid: body.city_qid, language_code };
  }
  throw new DiscoveryError("invalid_request", "Invalid action");
}

// Versioned conservative P31/P279 roots. General building, artwork, city and event roots are intentionally absent.
export const DISCOVERY_TAXONOMY_VERSION = 1;
export const DISCOVERY_TYPE_ROOTS: ReadonlyArray<{ qid: string; interest: DiscoveryInterestCode }> = [
  { qid: "Q33506", interest: "culture_museums" }, // museum
  { qid: "Q207694", interest: "culture_museums" }, // art museum
  { qid: "Q17431399", interest: "culture_museums" }, // national museum
  { qid: "Q740437", interest: "culture_museums" }, // pinacotheca
  { qid: "Q839954", interest: "history" }, // archaeological site
  { qid: "Q23413", interest: "history" }, // castle
  { qid: "Q4989906", interest: "history" }, // monument
  { qid: "Q5275", interest: "history" }, // astronomical clock
  { qid: "Q56242215", interest: "history" }, // Catholic cathedral
  { qid: "Q5393308", interest: "history" }, // Buddhist temple
  { qid: "Q845945", interest: "history" }, // Shinto shrine
  { qid: "Q143912", interest: "history" }, // triumphal arch
  { qid: "Q16970", interest: "history" }, // church building
  { qid: "Q16560", interest: "history" }, // palace
  { qid: "Q12280", interest: "architecture" }, // bridge
  { qid: "Q23413", interest: "architecture" }, // castle
  { qid: "Q16560", interest: "architecture" }, // palace
  { qid: "Q16970", interest: "architecture" }, // church building
  { qid: "Q2977", interest: "architecture" }, // cathedral
  { qid: "Q56242215", interest: "architecture" }, // Catholic cathedral
  { qid: "Q108325", interest: "architecture" }, // chapel
  { qid: "Q5393308", interest: "architecture" }, // Buddhist temple
  { qid: "Q845945", interest: "architecture" }, // Shinto shrine
  { qid: "Q3397526", interest: "architecture" }, // stone bridge
  { qid: "Q158438", interest: "architecture" }, // arch bridge
  { qid: "Q1068842", interest: "architecture" }, // footbridge
  { qid: "Q143912", interest: "architecture" }, // triumphal arch
  { qid: "Q1440300", interest: "architecture" }, // observation tower
  { qid: "Q1068623", interest: "architecture" }, // transmitter mast
  { qid: "Q1440476", interest: "architecture" }, // lattice tower
  { qid: "Q22698", interest: "nature_parks" }, // park
  { qid: "Q1107656", interest: "nature_parks" }, // garden
  { qid: "Q167346", interest: "nature_parks" }, // botanical garden
  { qid: "Q179049", interest: "nature_parks" }, // nature reserve
  { qid: "Q46169", interest: "nature_parks" }, // national park
  { qid: "Q8502", interest: "nature_parks" }, // mountain
  { qid: "Q34038", interest: "nature_parks" }, // waterfall
  { qid: "Q23397", interest: "nature_parks" }, // lake
  { qid: "Q40080", interest: "nature_parks" }, // beach
  { qid: "Q1440300", interest: "viewpoints" }, // observation tower
  { qid: "Q207694", interest: "art" }, // art museum
  { qid: "Q740437", interest: "art" }, // pinacotheca
  { qid: "Q860861", interest: "art" }, // sculpture
];
export const DISCOVERY_EXCLUDED_TYPE_ROOTS = ["Q515", "Q6256", "Q1656682", "Q178561", "Q1248784", "Q18325841"] as const; // cities, countries, events, battles, airports and public-transport networks; concrete museums remain allowlisted

export type WikidataEntity = {
  id: string;
  labels?: Record<string, { value?: string }>;
  descriptions?: Record<string, { value?: string }>;
  claims?: Record<string, Array<{ mainsnak?: { snaktype?: string; datavalue?: { value?: unknown } } }>>;
  sitelinks?: unknown;
  latitude?: number;
  longitude?: number;
  distance_meters?: number;
  matched_types?: string[];
  excluded_types?: string[];
  image_title?: string;
  city_country?: string;
};

const rootInterests = new Map<string, Set<DiscoveryInterestCode>>();
for (const entry of DISCOVERY_TYPE_ROOTS) {
  const interests = rootInterests.get(entry.qid) ?? new Set<DiscoveryInterestCode>();
  interests.add(entry.interest);
  rootInterests.set(entry.qid, interests);
}
export function classifyDiscoveryEntity(entity: WikidataEntity): DiscoveryInterestCode[] {
  if (entity.excluded_types?.some(type => DISCOVERY_EXCLUDED_TYPE_ROOTS.includes(type as typeof DISCOVERY_EXCLUDED_TYPE_ROOTS[number]))) return [];
  const types = entity.matched_types ?? (entity.claims?.P31 ?? []).flatMap(claim => {
    const value = claim.mainsnak?.datavalue?.value as { id?: unknown } | undefined;
    return typeof value?.id === "string" ? [value.id] : [];
  });
  return [...new Set(types.flatMap(type => [...(rootInterests.get(type) ?? [])]))];
}

export function countWikipediaLanguageArticles(sitelinks: unknown): number {
  if (!sitelinks || typeof sitelinks !== "object" || Array.isArray(sitelinks)) return 0;
  const urls = new Set<string>();
  for (const raw of Object.values(sitelinks as Record<string, unknown>)) {
    if (!raw || typeof raw !== "object") continue;
    const url = (raw as Record<string, unknown>).url;
    if (typeof url !== "string") continue;
    try {
      const parsed = new URL(url);
      if (/^[a-z0-9-]+\.wikipedia\.org$/i.test(parsed.hostname)) urls.add(parsed.href);
    } catch { /* malformed sitelink URLs are ignored */ }
  }
  return urls.size;
}

export function mergeAndRankDiscoveryItems(items: DiscoveryItemDTO[]): DiscoveryItemDTO[] {
  const merged = new Map<string, DiscoveryItemDTO>();
  for (const item of items) {
    const previous = merged.get(item.qid);
    if (!previous) merged.set(item.qid, { ...item, interests: [...new Set(item.interests)] });
    else merged.set(item.qid, { ...previous, ...item, interests: [...new Set([...previous.interests, ...item.interests])] });
  }
  const sorted = [...merged.values()].sort((a, b) => b.wikipedia_language_count - a.wikipedia_language_count || a.distance_meters - b.distance_meters || a.qid.localeCompare(b.qid));
  const counts = new Map<DiscoveryInterestCode, number>();
  const selected: DiscoveryItemDTO[] = [];
  for (const item of sorted) {
    const eligible = item.interests.filter(interest => (counts.get(interest) ?? 0) < 10);
    if (!eligible.length || selected.length >= MAX_ITEMS) continue;
    selected.push({ ...item, interests: eligible });
    for (const interest of eligible) counts.set(interest, (counts.get(interest) ?? 0) + 1);
  }
  return selected;
}

export type DiscoveryCitySearchEntity = { id: string; labels?: Record<string, { value?: string }>; descriptions?: Record<string, { value?: string }>; claims?: WikidataEntity["claims"]; sitelinks?: unknown };
export type DiscoveryPOIRow = WikidataEntity & { interests: DiscoveryInterestCode[] };
export type DiscoveryDeps = {
  searchCityEntities(query: string, language: string, signal: AbortSignal): Promise<DiscoveryCitySearchEntity[]>;
  getEntities(ids: string[], language: string, signal: AbortSignal): Promise<WikidataEntity[]>;
  queryPOIs(city: DiscoveryCityDTO, language: string, signal: AbortSignal): Promise<DiscoveryPOIRow[]>;
  getP18Images(qids: string[], signal: AbortSignal): Promise<Map<string, DiscoveryImageDTO>>;
};

export type CatalogResponse = { protocol_version: 1; catalog_version: 1; ranking_version: 1; city: DiscoveryCityDTO; language_code: string; coverage: { kind: "radius"; radius_meters: 25000; label: string }; items: DiscoveryItemDTO[]; fetched_at: string; expires_at: string; stale_until: string; cache_status: "fresh" | "stale" };

const cityTypes = new Set(["Q515", "Q5119", "Q1549591", "Q3957"]); // city, capital, big city, town
function claimIDs(claims: WikidataEntity["claims"], property: string) {
  return (claims?.[property] ?? []).flatMap(claim => {
    const value = claim.mainsnak?.datavalue?.value as { id?: unknown } | undefined;
    return typeof value?.id === "string" ? [value.id] : [];
  });
}
function localizedLabel(entity: { labels?: Record<string, { value?: string }> }, language: string) {
  return entity.labels?.[language]?.value || entity.labels?.en?.value || Object.values(entity.labels ?? {}).find(label => label.value)?.value || "";
}
function isoDate(date: Date) { return date.toISOString().replace(/\.\d{3}Z$/, "Z"); }

export async function searchDiscoveryCities(query: string, language: string, deps: DiscoveryDeps, signal: AbortSignal): Promise<DiscoveryCityDTO[]> {
  const matches = (await deps.searchCityEntities(query, language, signal)).filter(match => validQID(match.id)).slice(0, 20);
  const entities = await deps.getEntities(matches.map(match => match.id), language, signal);
  const byID = new Map(entities.map(entity => [entity.id, entity]));
  const cityRecords = matches.flatMap(match => {
    const entity = byID.get(match.id);
    const point = entity?.claims?.P625?.[0]?.mainsnak?.datavalue?.value as { latitude?: unknown; longitude?: unknown } | undefined;
    const latitude = Number(point?.latitude), longitude = Number(point?.longitude);
    if (!entity || !claimIDs(entity.claims, "P31").some(id => cityTypes.has(id)) || !validCoordinate(latitude, longitude)) return [];
    const countryID = claimIDs(entity.claims, "P17")[0];
    return [{ entity, qid: match.id, countryID, latitude, longitude }];
  });
  const countries = await deps.getEntities([...new Set(cityRecords.flatMap(record => record.countryID ? [record.countryID] : []))], language, signal);
  const countryByID = new Map(countries.map(entity => [entity.id, localizedLabel(entity, language)]));
  return cityRecords.map(record => ({ qid: record.qid, name: localizedLabel(record.entity, language), country: countryByID.get(record.countryID ?? "") ?? "", latitude: record.latitude, longitude: record.longitude, source_url: `https://www.wikidata.org/wiki/${record.qid}` }))
    .filter(city => city.name && city.country).slice(0, 5);
}

export async function buildDiscoveryCatalog(cityQID: string, language: string, deps: DiscoveryDeps, signal: AbortSignal): Promise<Omit<CatalogResponse, "fetched_at" | "expires_at" | "stale_until" | "cache_status">> {
  if (!validQID(cityQID)) throw new DiscoveryError("invalid_request", "Invalid city QID");
  const cityEntities = await deps.getEntities([cityQID], language, signal);
  const cityEntity = cityEntities.find(entity => entity.id === cityQID);
  const coordinates = cityEntity?.claims?.P625?.[0]?.mainsnak?.datavalue?.value as { latitude?: unknown; longitude?: unknown } | undefined;
  const latitude = Number(coordinates?.latitude), longitude = Number(coordinates?.longitude);
  if (!cityEntity || !claimIDs(cityEntity.claims, "P31").some(id => cityTypes.has(id)) || !validCoordinate(latitude, longitude)) throw new DiscoveryError("invalid_request", "QID is not a supported city");
  const countryID = claimIDs(cityEntity.claims, "P17")[0];
  const country = countryID ? (await deps.getEntities([countryID], language, signal))[0] : undefined;
  const city: DiscoveryCityDTO = { qid: cityQID, name: localizedLabel(cityEntity, language), country: country ? localizedLabel(country, language) : "", latitude, longitude, source_url: `https://www.wikidata.org/wiki/${cityQID}` };
  if (!city.name || !city.country) throw new DiscoveryError("source_unavailable", "City metadata unavailable");
  const candidates = await deps.queryPOIs(city, language, signal);
  const deduplicated = new Map<string, DiscoveryItemDTO>();
  for (const entity of candidates) {
    if (!validQID(entity.id) || !validCoordinate(Number(entity.latitude), Number(entity.longitude))) continue;
    const interests = [...new Set(entity.interests.filter(value => ["culture_museums", "history", "architecture", "nature_parks", "viewpoints", "art"].includes(value)))];
    if (!interests.length) continue;
    const count = countWikipediaLanguageArticles(entity.sitelinks);
    const name = localizedLabel(entity, language);
    if (!name || count === 0) continue;
    const description = entity.descriptions?.[language]?.value || entity.descriptions?.en?.value;
    deduplicated.set(entity.id, { qid: entity.id, name, description, latitude: Number(entity.latitude), longitude: Number(entity.longitude), interests, wikipedia_language_count: count, source_url: `https://www.wikidata.org/wiki/${entity.id}`, distance_meters: Math.round(Math.max(0, Number(entity.distance_meters) || 0)) });
  }
  const items = mergeAndRankDiscoveryItems([...deduplicated.values()]);
  let images = new Map<string, DiscoveryImageDTO>();
  try { images = await deps.getP18Images(items.map(item => item.qid), signal); }
  catch { /* catalog results remain usable when optional Commons metadata is unavailable */ }
  for (const item of items) item.image = images.get(item.qid);
  return { protocol_version: 1, catalog_version: 1, ranking_version: 1, city, language_code: language, coverage: { kind: "radius", radius_meters: RADIUS_METERS, label: `25 km um ${city.name}` }, items };
}

export function makeCatalogResponse(catalog: Omit<CatalogResponse, "fetched_at" | "expires_at" | "stale_until" | "cache_status">, now = new Date(), fetchedAt = now): CatalogResponse {
  return { ...catalog, fetched_at: isoDate(fetchedAt), expires_at: isoDate(new Date(fetchedAt.getTime() + 7 * 86400_000)), stale_until: isoDate(new Date(fetchedAt.getTime() + 30 * 86400_000)), cache_status: "fresh" };
}
