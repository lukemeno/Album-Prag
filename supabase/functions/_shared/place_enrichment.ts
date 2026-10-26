import { isUuid } from "./assistant_validation.ts";
import { validCoordinate, normalize, tokenSimilarity } from "./place_photo.ts";
import type { PublicPhotoIdentity } from "./place_photo_cache.ts";
import type { WikimediaRequestLimiter } from "./wikimedia_photos.ts";

export const MAX_ENRICHMENT_BODY = 32 * 1024;
export const ENRICHMENT_STATUSES = ["queued", "processing", "ready", "needs_review", "not_found", "retry_wait", "failed"] as const;
export type EnrichmentStatus = typeof ENRICHMENT_STATUSES[number];
export type EnrichmentPlace = { id: string; title: string; category: string; address: string; source_url: string; latitude: number | null; longitude: number | null; provider_place_id?: string | null; provider_protocol?: string | null };
export type EnrichmentRequest = { trip_id: string | null; google_photos: boolean; mode?: "automatic_photo_v1"; place: EnrichmentPlace; region: { name: string; latitude: number | null; longitude: number | null } };
export type PlaceImage = { image_url: string; source_url: string; credit: string; provider: "wikimedia" | "sourcePreview"; license_name?: string; license_url?: string; provider_place_id?: string | null; confidence: "verified" | "suggested"; caption?: string };
export type EnrichmentResult = { resolution: null | { provider: "google" | "wikidata" | "existing"; provider_place_id: string | null; latitude: number; longitude: number; confidence: "verified" }; image: PlaceImage | null; candidates: PlaceImage[]; selection_version: 4; review_reason: string | null };
export class EnrichmentError extends Error { constructor(readonly code: string, message: string, readonly status = 400, readonly retryAfterSeconds = 60) { super(message); } }

const object = (v: unknown): Record<string, unknown> => {
  if (!v || typeof v !== "object" || Array.isArray(v)) throw new EnrichmentError("invalid_request", "Ungültige Anfrage");
  return v as Record<string, unknown>;
};
function onlyKeys(value: Record<string, unknown>, allowed: string[]) {
  if (Object.keys(value).some(key => !allowed.includes(key))) throw new EnrichmentError("invalid_request", "Unerwartete Anfragefelder");
}
const text = (v: unknown, key: string, max: number, optional = false): string => {
  if (typeof v !== "string" || v.length > max || (!optional && !v.trim())) throw new EnrichmentError("invalid_request", `Ungültiges Feld: ${key}`);
  return v.trim();
};
const coordinate = (v: unknown, key: string, nullable = false): number | null => {
  if (nullable && v === null) return null;
  if (typeof v !== "number" || !Number.isFinite(v) || v < (key.endsWith("latitude") ? -90 : -180) || v > (key.endsWith("latitude") ? 90 : 180)) throw new EnrichmentError("invalid_request", `Ungültiges Feld: ${key}`);
  return v;
};

export function parseEnrichmentAction(value: unknown): { action: "enqueue"; request: EnrichmentRequest } | { action: "status" | "retry"; job_id: string } {
  const body = object(value);
  if (body.action === "status" || body.action === "retry") {
    onlyKeys(body, ["action", "job_id"]);
    if (!isUuid(body.job_id)) throw new EnrichmentError("invalid_request", "Ungültige Job-ID");
    return { action: body.action, job_id: body.job_id };
  }
  if (body.action !== "enqueue") throw new EnrichmentError("invalid_request", "Ungültige Aktion");
  onlyKeys(body, ["action", "trip_id", "google_photos", "mode", "place", "region"]);
  if (body.mode !== undefined && body.mode !== "automatic_photo_v1") throw new EnrichmentError("invalid_request", "Ungültiger Modus");
  if (body.google_photos !== undefined && typeof body.google_photos !== "boolean") throw new EnrichmentError("invalid_request", "Ungültiger Wert für google_photos");
  const rawPlace = object(body.place), rawRegion = object(body.region);
  onlyKeys(rawPlace, ["id", "title", "category", "address", "source_url", "latitude", "longitude", "provider_place_id", "provider_protocol"]);
  onlyKeys(rawRegion, ["name", "latitude", "longitude"]);
  const trip = body.trip_id ?? null;
  if (trip !== null && !isUuid(trip)) throw new EnrichmentError("invalid_request", "Ungültige Reise-ID");
  const latitude = coordinate(rawPlace.latitude ?? null, "place.latitude", true);
  const longitude = coordinate(rawPlace.longitude ?? null, "place.longitude", true);
  if ((latitude === null) !== (longitude === null)) throw new EnrichmentError("invalid_request", "Koordinaten müssen gemeinsam angegeben werden");
  const regionLat = coordinate(rawRegion.latitude ?? null, "region.latitude", true);
  const regionLng = coordinate(rawRegion.longitude ?? null, "region.longitude", true);
  if ((regionLat === null) !== (regionLng === null)) throw new EnrichmentError("invalid_request", "Regionskoordinaten müssen gemeinsam angegeben werden");
  const request = {
    trip_id: trip as string | null, google_photos: body.google_photos === true, ...(body.mode ? { mode: "automatic_photo_v1" as const } : {}),
    place: {
      id: text(rawPlace.id, "place.id", 128), title: text(rawPlace.title, "place.title", 200),
      category: text(rawPlace.category, "place.category", 64), address: text(rawPlace.address ?? "", "place.address", 500, true),
      source_url: text(rawPlace.source_url ?? "", "place.source_url", 2048, true), latitude, longitude,
      provider_place_id: rawPlace.provider_place_id == null ? null : text(rawPlace.provider_place_id, "place.provider_place_id", 256),
      provider_protocol: rawPlace.provider_protocol == null ? null : text(rawPlace.provider_protocol, "place.provider_protocol", 32),
    },
    region: { name: text(rawRegion.name ?? "", "region.name", 200, true), latitude: regionLat, longitude: regionLng },
  };
  if (regionLat !== null && regionLng !== null && !validCoordinate(regionLat, regionLng)) throw new EnrichmentError("invalid_request", "Ungültige Region");
  if (body.mode === "automatic_photo_v1" && (latitude === null || longitude === null)) throw new EnrichmentError("invalid_request", "Automatische Bildsuche benötigt Koordinaten");
  return { action: "enqueue", request };
}

export async function requestKey(request: EnrichmentRequest) {
  const clean = (value: string) => value.trim().normalize("NFC");
  const stableRequest: Record<string, unknown> = { trip_id: request.trip_id, place: {
    id: clean(request.place.id), title: clean(request.place.title), category: clean(request.place.category),
    address: clean(request.place.address), source_url: clean(request.place.source_url), latitude: request.place.latitude, longitude: request.place.longitude,
    provider_place_id: request.place.provider_place_id ?? null, provider_protocol: request.place.provider_protocol ?? null,
  }, region: { name: clean(request.region.name), latitude: request.region.latitude, longitude: request.region.longitude } };
  if (request.google_photos) stableRequest.google_photos = true;
  if (request.mode) stableRequest.mode = request.mode;
  const stable = JSON.stringify(stableRequest);
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(stable));
  return [...new Uint8Array(digest)].map(byte => byte.toString(16).padStart(2, "0")).join("");
}
export function hasLocationContext(request: EnrichmentRequest) {
  return Boolean(request.place.address.trim() || request.region.name.trim() ||
    (request.place.latitude !== null && request.place.longitude !== null) ||
    (request.region.latitude !== null && request.region.longitude !== null));
}

export type MatchCandidate = { id: string; name: string; address?: string; latitude: number; longitude: number; primaryType?: string; types?: string[] };
export function rankMatches(candidates: MatchCandidate[], place: EnrichmentPlace, region: EnrichmentRequest["region"]) {
  const query = normalize(place.title), wantedNumber = houseNumber(place.address);
  const hasPlaceCoordinates = place.latitude !== null && place.longitude !== null;
  const hasRegionCoordinates = !place.address.trim() && region.latitude !== null && region.longitude !== null;
  const placeAddressTokens = contextTokens(place.address.split(",")[0]);
  const regionCityTokens = contextTokens(canonicalCity(region.name.split(",")[0]));
  if (!placeAddressTokens.length && !regionCityTokens.length && !hasPlaceCoordinates && !hasRegionCoordinates) return [];
  return candidates.flatMap(candidate => {
    if (!candidate.id || !candidate.name || !validCoordinate(candidate.latitude, candidate.longitude)) return [];
    const name = normalize(candidate.name), similarity = tokenSimilarity(name, query);
    const foundNumber = houseNumber(candidate.address ?? "");
    if (wantedNumber && foundNumber && !sameHouseNumber(wantedNumber, foundNumber)) return [];
    const normalizedCandidateAddress = normalize(candidate.address ?? "");
    const candidateAddressTokens = new Set(canonicalCity(normalizedCandidateAddress).split(" ").filter(Boolean));
    const placeAddress = normalize(place.address.split(",")[0]);
    const regionCity = normalize(canonicalCity(region.name.split(",")[0]));
    const addressMatch = placeAddressTokens.length > 0 && (placeAddressTokens.every(token => candidateAddressTokens.has(token)) || normalizedCandidateAddress.includes(placeAddress));
    const regionMatch = regionCityTokens.length > 0 && (regionCityTokens.every(token => candidateAddressTokens.has(token)) || normalizedCandidateAddress.includes(regionCity));
    if (placeAddressTokens.length && !addressMatch) return [];
    if (!placeAddressTokens.length && regionCityTokens.length && !regionMatch) return [];
    const distance = hasPlaceCoordinates
      ? distanceMeters(place.latitude!, place.longitude!, candidate.latitude, candidate.longitude)
      : hasRegionCoordinates ? distanceMeters(region.latitude!, region.longitude!, candidate.latitude, candidate.longitude) : null;
    const queryTokens = query.split(" ").filter(Boolean), candidateTokens = name.split(" ").filter(Boolean);
    const genericSuffixes = new Set(["store", "shop", "restaurant", "cafe", "hotel", "bar", "praha", "prague", "prag", "sro"]);
    const nameAlias = queryTokens.length >= 2 && queryTokens.every(token => candidateTokens.includes(token)) && candidateTokens.every(token => queryTokens.includes(token) || genericSuffixes.has(token));
    if (similarity < 0.6 && !nameAlias && !addressMatch) return [];
    if (hasPlaceCoordinates && distance! > 1500 && !addressMatch) return [];
    const typeScore = categoryTypeScore(place.category, candidate);
    const score = (name === query ? 0.65 : nameAlias ? 0.65 : similarity * 0.45) + (addressMatch ? 0.25 : 0) + (wantedNumber && foundNumber && sameHouseNumber(wantedNumber, foundNumber) ? 0.2 : 0) + (distance === null ? 0 : Math.max(0, 0.1 - distance / 100000)) + typeScore;
    return [{ candidate, score, distance, similarity, addressMatch: Boolean(addressMatch) }];
  }).sort((a, b) => b.score - a.score);
}
function contextTokens(value: string) { return normalize(value).split(" ").filter(token => token.length > 1 && !/^\d+$/.test(token)); }
function canonicalCity(value: string) { return normalize(value).replace(/\b(?:prag|prague|praha)\b/g, "praha"); }
const categoryTypes: Record<string, { matches: string[]; conflicts: string[] }> = {
  "sehenswert": { matches: ["tourist_attraction", "historical_landmark", "monument", "museum", "church", "place_of_worship", "cultural_landmark", "art_gallery", "visitor_center"], conflicts: ["transit_station", "train_station", "bus_station", "subway_station", "airport", "restaurant", "cafe", "lodging"] },
  "aussicht": { matches: ["tourist_attraction", "park", "observation_deck", "hiking_area", "scenic_spot", "natural_feature"], conflicts: ["transit_station", "train_station", "bus_station", "subway_station", "airport", "restaurant", "cafe", "lodging"] },
  "essen trinken": { matches: ["restaurant", "cafe", "bakery", "bar", "meal_takeaway", "meal_delivery", "food"], conflicts: ["transit_station", "train_station", "bus_station", "subway_station", "airport", "museum", "church", "place_of_worship", "lodging"] },
  "unterkunft": { matches: ["lodging", "hotel", "hostel", "motel", "guest_house", "bed_and_breakfast"], conflicts: ["transit_station", "train_station", "bus_station", "subway_station", "airport", "museum", "church", "place_of_worship"] },
  "shopping": { matches: ["store", "shopping_mall", "clothing_store", "market", "department_store", "book_store"], conflicts: ["transit_station", "train_station", "bus_station", "subway_station", "airport", "museum", "church", "place_of_worship"] },
};
function categoryTypeScore(category: string, candidate: MatchCandidate) {
  const expected = categoryTypes[normalize(category)];
  if (!expected) return 0;
  const types = new Set([candidate.primaryType, ...(candidate.types ?? [])].filter((value): value is string => Boolean(value)));
  if (!types.size) return 0;
  if (expected.matches.some(type => types.has(type))) return 0.2;
  if (expected.conflicts.some(type => types.has(type))) return -0.2;
  return 0;
}
function houseNumber(address: string) {
  const street = address.split(",").map(part => part.trim()).find(part => !/\b(?:praha|prague|prag)\b/i.test(part) && !/\b\d{3}\s?\d{2}\b/.test(part) && /\b\d{1,4}[a-z]?(?:\s*\/\s*\d{1,4}[a-z]?)?\b/i.test(part));
  const match = street?.match(/\b(\d{1,4}[a-z]?(?:\s*\/\s*\d{1,4}[a-z]?)?)\b/i);
  return match?.[1].replace(/\s/g, "").toLowerCase() ?? "";
}
function sameHouseNumber(left: string, right: string) { return left === right; }
export function distanceMeters(lat1: number, lng1: number, lat2: number, lng2: number) {
  const r = (x: number) => x * Math.PI / 180, dLat = r(lat2 - lat1), dLng = r(lng2 - lng1);
  const a = Math.sin(dLat / 2) ** 2 + Math.cos(r(lat1)) * Math.cos(r(lat2)) * Math.sin(dLng / 2) ** 2;
  return 6371000 * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}
export function selectUnambiguousMatch(matches: ReturnType<typeof rankMatches>) {
  if (!matches.length || matches[0].score < 0.62) return { selected: null, ambiguous: false };
  if (matches[1] && matches[0].score - matches[1].score < 0.13) return { selected: null, ambiguous: true };
  return { selected: matches[0].candidate, ambiguous: false };
}

export const GOOGLE_ENDPOINT = "https://places.googleapis.com/v1/places:searchText";
export const GOOGLE_MASK = "places.id,places.displayName,places.formattedAddress,places.location,places.primaryType,places.types";
export function googleLanguage(regionName: string): string | undefined {
  const region = normalize(regionName);
  const hints: Array<[string, string[]]> = [
    ["pt", ["brazil", "brasil", "portugal", "rio de janeiro", "sao paulo", "lisbon"]],
    ["de", ["germany", "deutschland", "berlin", "austria", "osterreich", "wien", "vienna", "switzerland", "schweiz"]],
    ["cs", ["czech", "cesko", "prague", "praha", "prag"]],
    ["es", ["spain", "espana", "mexico", "argentina", "madrid", "buenos aires"]],
    ["fr", ["france", "paris", "belgium", "bruxelles", "brussels"]],
    ["it", ["italy", "italia", "rome", "roma"]],
    ["ja", ["japan", "tokyo", "kyoto"]],
    ["zh", ["china", "taiwan", "hong kong", "beijing", "shanghai"]],
  ];
  return hints.find(([, values]) => values.some(value => region.includes(normalize(value))))?.[0];
}
export function googleSearchBody(request: EnrichmentRequest): Record<string, unknown> {
  const context = request.place.address || request.region.name;
  const body: Record<string, unknown> = { textQuery: [request.place.title, context].filter(Boolean).join(", "), maxResultCount: 5 };
  const languageCode = googleLanguage(context || request.region.name);
  if (languageCode) body.languageCode = languageCode;
  const placeHasCoordinates = request.place.latitude !== null && request.place.longitude !== null;
  const regionHasCoordinates = !request.place.address.trim() && request.region.latitude !== null && request.region.longitude !== null;
  if (placeHasCoordinates || regionHasCoordinates) {
    const center = placeHasCoordinates
      ? { latitude: request.place.latitude!, longitude: request.place.longitude! }
      : { latitude: request.region.latitude!, longitude: request.region.longitude! };
    body.locationBias = { circle: { center, radius: placeHasCoordinates ? 1000 : 50000 } };
  }
  return body;
}
export async function searchGoogle(request: EnrichmentRequest, key: string, fetchImpl: typeof fetch = fetch, signal?: AbortSignal) {
  const controller = new AbortController(), timer = setTimeout(() => controller.abort(), 8000);
  const abort = () => controller.abort(); signal?.addEventListener("abort", abort, { once: true });
  try {
    const body = googleSearchBody(request);
    const response = await fetchImpl(GOOGLE_ENDPOINT, { method: "POST", headers: { "Content-Type": "application/json", "X-Goog-Api-Key": key, "X-Goog-FieldMask": GOOGLE_MASK }, body: JSON.stringify(body), signal: controller.signal });
    if (!response.ok) throw new EnrichmentError("google_unavailable", "Ortsauflösung vorübergehend nicht verfügbar", 503);
    const payload = await response.json(), values = payload && typeof payload === "object" && Array.isArray(payload.places) ? payload.places : [];
    return values.flatMap((v: unknown) => {
      if (!v || typeof v !== "object") return [];
      const row = v as Record<string, unknown>, name = (row.displayName as Record<string, unknown> | undefined)?.text;
      const loc = row.location as Record<string, unknown> | undefined;
      if (typeof row.id !== "string" || typeof name !== "string" || typeof loc?.latitude !== "number" || typeof loc.longitude !== "number") return [];
      return [{ id: row.id, name, address: typeof row.formattedAddress === "string" ? row.formattedAddress : "", latitude: loc.latitude, longitude: loc.longitude, primaryType: typeof row.primaryType === "string" ? row.primaryType : undefined, types: Array.isArray(row.types) ? row.types.filter((type): type is string => typeof type === "string") : undefined }];
    });
  } catch (error) {
    if (error instanceof EnrichmentError) throw error;
    if (error instanceof DOMException && error.name === "AbortError") throw new EnrichmentError("google_timeout", "Ortsauflösung hat zu lange gedauert", 503);
    throw new EnrichmentError("google_unavailable", "Ortsauflösung vorübergehend nicht verfügbar", 503);
  } finally { clearTimeout(timer); signal?.removeEventListener("abort", abort); }
}

export function safePreviewURL(value: string) {
  try {
    const url = new URL(value);
    const host = url.hostname.toLowerCase().replace(/^\[|\]$/g, "");
    if (url.protocol !== "https:" || url.username || url.password || url.port || host === "localhost" || host.endsWith(".localhost") || host.endsWith(".local") ||
      host.includes(":") || /^\d+(?:\.\d+){3}$/.test(host) ||
      /^(?:0|10|127|169\.254|192\.168|224|240)\./.test(host) || /^172\.(?:1[6-9]|2\d|3[01])\./.test(host)) return null;
    return url;
  } catch { return null; }
}
export async function fetchPreviewImage(source: string, fetchImpl: typeof fetch = fetch, resolveHost: (host: string) => Promise<string[]> = async host => {
  if (typeof Deno !== "undefined" && typeof Deno.resolveDns === "function") {
    const a = await Deno.resolveDns(host, "A").catch(() => []);
    const aaaa = await Deno.resolveDns(host, "AAAA").catch(() => []);
    return [...a, ...aaaa];
  }
  return [];
}, allowedHosts: string[] = (typeof Deno !== "undefined" ? Deno.env.get("PLACE_PREVIEW_ALLOWED_HOSTS") ?? "" : "").split(",").map(host => host.trim().toLowerCase()).filter(Boolean)): Promise<PlaceImage | null> {
  const url = safePreviewURL(source); if (!url) return null;
  const host = url.hostname.toLowerCase();
  if (!allowedHosts.some(allowed => host === allowed || host.endsWith(`.${allowed}`))) return null;
  try {
    const addresses = await resolveHost(url.hostname);
    if (!addresses.length || addresses.some(address => !isPublicAddress(address))) return null;
    const response = await fetchImpl(url, { redirect: "manual", signal: AbortSignal.timeout(5000), headers: { Accept: "text/html" } });
    if (!response.ok || response.headers.get("location") || !/text\/html/i.test(response.headers.get("content-type") ?? "")) return null;
    const reader = response.body?.getReader(); if (!reader) return null;
    const decoder = new TextDecoder(); let html = "", bytes = 0;
    try { while (bytes < 256 * 1024) { const { done, value } = await reader.read(); if (done) break; if (bytes + value.length > 256 * 1024) return null; bytes += value.length; html += decoder.decode(value, { stream: true }); } }
    finally { await reader.cancel().catch(() => {}); }
    const match = html.match(/<meta\s+(?:property|name)=["'](?:og:image|twitter:image)["']\s+content=["']([^"']+)["']/i) ?? html.match(/<meta\s+content=["']([^"']+)["']\s+(?:property|name)=["'](?:og:image|twitter:image)["']/i);
    if (!match) return null;
    const imageURL = safePreviewURL(new URL(match[1].replaceAll("&amp;", "&"), url).toString()); if (!imageURL) return null;
    const imageAddresses = await resolveHost(imageURL.hostname);
    if (!imageAddresses.length || imageAddresses.some(address => !isPublicAddress(address))) return null;
    return { image_url: imageURL.toString(), source_url: url.toString(), credit: url.hostname, provider: "sourcePreview", confidence: "suggested" };
  } catch { return null; }
}
function isPublicAddress(value: string) {
  const host = value.toLowerCase();
  if (host.includes(":")) {
    const first = Number.parseInt(host.split(":")[0] || "0", 16);
    return first >= 0x2000 && first <= 0x3fff && !host.startsWith("2001:db8:");
  }
  const octets = host.split(".").map(Number);
  if (octets.length !== 4 || octets.some(n => !Number.isInteger(n) || n < 0 || n > 255)) return false;
  return !(octets[0] === 0 || octets[0] === 10 || octets[0] === 127 || octets[0] >= 224 || (octets[0] === 169 && octets[1] === 254) || (octets[0] === 172 && octets[1] >= 16 && octets[1] <= 31) || (octets[0] === 192 && octets[1] === 168));
}

export function makeResponse(job: Record<string, unknown>) {
  return { job_id: job.job_id, request_key: job.request_key, status: job.status, result: job.result ?? null, retry_after_seconds: job.retry_after_seconds ?? null, error_code: job.error_code ?? null };
}

export type EnrichmentAuth = { userId: string; admin: any };
export type EnrichmentHandlerDependencies = {
  authenticate: (request: Request) => Promise<EnrichmentAuth>;
  rpc: (admin: any, name: string, args: Record<string, unknown>) => Promise<any>;
  isTripMember: (admin: any, userId: string, tripId: string) => Promise<boolean>;
};
function json(value: unknown, status = 200) { return new Response(JSON.stringify(value), { status, headers: { "Content-Type": "application/json", "Cache-Control": "no-store" } }); }
function publicError(error: unknown) {
  if (error instanceof EnrichmentError) return json({ error: error.message, code: error.code }, error.status);
  if (error instanceof Response) return json({ error: error.status === 401 ? "Nicht angemeldet" : "Anfrage nicht zulässig.", code: error.status === 401 ? "unauthorized" : "request_error" }, error.status || 500);
  return json({ error: "Ortsanreicherung vorübergehend nicht verfügbar.", code: "enrichment_unavailable" }, 503);
}
export function createPlaceEnrichmentHandler(deps: EnrichmentHandlerDependencies) {
  return async (request: Request) => {
    if (request.method !== "POST") return new Response(null, { status: 405, headers: { "Cache-Control": "no-store" } });
    try {
      const auth = await deps.authenticate(request);
      if (Number(request.headers.get("content-length") || 0) > MAX_ENRICHMENT_BODY) throw new EnrichmentError("request_too_large", "Anfrage ist zu groß", 413);
      if (!/^application\/json(?:\s*;|$)/i.test(request.headers.get("content-type") ?? "")) throw new EnrichmentError("invalid_request", "JSON wird erwartet");
      const buffer = await readLimitedBody(request);
      let parsed: unknown; try { parsed = JSON.parse(new TextDecoder().decode(buffer)); } catch { throw new EnrichmentError("invalid_request", "Ungültiges JSON"); }
      const action = parseEnrichmentAction(parsed);
      if (action.action === "enqueue") {
        if (action.request.trip_id && !await deps.isTripMember(auth.admin, auth.userId, action.request.trip_id)) throw new EnrichmentError("forbidden_trip", "Kein Zugriff auf diese Reise", 403);
        const key = await requestKey(action.request);
        const job = await deps.rpc(auth.admin, "place_enrichment_enqueue", { p_user_id: auth.userId, p_trip_id: action.request.trip_id, p_request_key: key, p_snapshot: action.request });
        return json(makeResponse(unwrap(job)));
      }
      if (action.action === "status") {
        const job = await deps.rpc(auth.admin, "place_enrichment_status", { p_user_id: auth.userId, p_job_id: action.job_id });
        const value = unwrap(job); if (!value) throw new EnrichmentError("job_not_found", "Job nicht gefunden", 404);
        return json(makeResponse(value));
      }
      const job = await deps.rpc(auth.admin, "place_enrichment_retry", { p_user_id: auth.userId, p_job_id: action.job_id });
      const value = unwrap(job); if (!value) throw new EnrichmentError("job_not_found", "Job nicht gefunden", 404);
      if (value.error_code === "not_retryable") throw new EnrichmentError("not_retryable", "Dieser Job kann nicht erneut gestartet werden.", 409);
      return json(makeResponse(value));
    } catch (error) { return publicError(error); }
  };
}
async function readLimitedBody(request: Request) {
  const reader = request.body?.getReader();
  if (!reader) return new Uint8Array();
  const chunks: Uint8Array[] = [];
  let length = 0;
  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      if (length + value.length > MAX_ENRICHMENT_BODY) {
        await reader.cancel();
        throw new EnrichmentError("request_too_large", "Anfrage ist zu groß", 413);
      }
      chunks.push(value); length += value.length;
    }
  } finally { reader.releaseLock(); }
  const bytes = new Uint8Array(length);
  let offset = 0;
  for (const chunk of chunks) { bytes.set(chunk, offset); offset += chunk.length; }
  return bytes;
}
function unwrap(value: any): any { if (value?.error) throw value.error; return value?.data ?? value; }

export type WorkerDependencies = {
  verifyToken: (token: string) => Promise<boolean>;
  claim: (limit: number) => Promise<Array<Record<string, any>>>;
  reserveGoogle: (job: Record<string, any>) => Promise<{ ok: boolean; code?: string; retry_after_seconds?: number }>;
  defer?: (job: Record<string, any>, seconds: number, code: string) => Promise<void>;
  complete: (job: Record<string, any>, result: EnrichmentResult, status?: "ready" | "needs_review" | "not_found") => Promise<void>;
  fail: (job: Record<string, any>, code: string, retryable: boolean) => Promise<void>;
  googleKey: () => string | undefined;
  fetchGoogle?: typeof searchGoogle;
  fetchWikimedia?: typeof import("./wikimedia_photos.ts").resolveWikimedia;
  wikimediaLimiter?: (job: Record<string, any>) => WikimediaRequestLimiter;
  cacheWikimedia?: (job: Record<string, any>, input: EnrichmentRequest, identity: PublicPhotoIdentity | null, load: () => Promise<PlaceImage[]>) => Promise<PlaceImage[]>;
  fetchPreview?: typeof fetchPreviewImage;
  waitUntil?: (promise: Promise<unknown>) => void;
};
export function createPlaceEnrichmentWorker(deps: WorkerDependencies) {
  return async (request: Request) => {
    if (request.method !== "POST") return new Response(null, { status: 405 });
    const token = request.headers.get("X-Place-Enrichment-Worker");
    if (!token || !await deps.verifyToken(token)) return json({ error: "Unauthorized" }, 401);
    const task = (async () => {
    const jobs = await deps.claim(2);
    let processed = 0;
    for (const job of jobs) {
      try {
        const input = job.snapshot as EnrichmentRequest;
        const hasCoordinates = input.place.latitude !== null && input.place.longitude !== null;
        // Provider IDs supplied by clients are hints only.  A durable public
        // cache is populated after this worker verifies a Google match below.
        let publicIdentity: PublicPhotoIdentity | null = null;
        let resolution: EnrichmentResult["resolution"] = hasCoordinates ? { provider: "existing", provider_place_id: null, latitude: input.place.latitude!, longitude: input.place.longitude!, confidence: "verified" } : null;
        let latitude = input.place.latitude, longitude = input.place.longitude;
        if (latitude === null || (input.google_photos && input.mode !== "automatic_photo_v1")) {
          if (!hasLocationContext(input)) {
            const result: EnrichmentResult = { resolution: null, image: null, candidates: [], selection_version: 4, review_reason: "insufficient_location_context" };
            await deps.complete(job, result, "needs_review"); processed++; continue;
          }
          const key = deps.googleKey();
          if (!key) { await deps.fail(job, "google_not_configured", false); processed++; continue; }
          const quota = await deps.reserveGoogle(job);
          if (!quota.ok) {
            if (quota.code === "rate_limit" && deps.defer) await deps.defer(job, quota.retry_after_seconds ?? 60, quota.code);
            else await deps.fail(job, quota.code || "google_quota", false);
            processed++; continue;
          }
          let candidates: MatchCandidate[] = await (deps.fetchGoogle ?? searchGoogle)(input, key);
          if (hasCoordinates) candidates = candidates.filter(candidate => distanceMeters(input.place.latitude!, input.place.longitude!, candidate.latitude, candidate.longitude) <= 1500);
          const matches = selectUnambiguousMatch(rankMatches(candidates, input.place, input.region));
          if (matches.ambiguous && !hasCoordinates) {
            const result: EnrichmentResult = { resolution: null, image: null, candidates: [], selection_version: 4, review_reason: "multiple_locations" };
            await deps.complete(job, result, "needs_review"); processed++; continue;
          }
          if (!matches.selected && !hasCoordinates) { const result: EnrichmentResult = { resolution: null, image: null, candidates: [], selection_version: 4, review_reason: null }; await deps.complete(job, result, "not_found"); processed++; continue; }
          if (matches.selected) {
            latitude = matches.selected.latitude; longitude = matches.selected.longitude;
            resolution = { provider: "google", provider_place_id: matches.selected.id, latitude, longitude, confidence: "verified" };
            publicIdentity = { id: matches.selected.id, protocol: "google" };
          }
        }
        const loadWikimedia = async (): Promise<PlaceImage[]> => (await (deps.fetchWikimedia ?? (await import("./wikimedia_photos.ts")).resolveWikimedia)(input.place.title, input.place.category, latitude!, longitude!, input.place.address, input.region.name, undefined, deps.wikimediaLimiter?.(job))).map(photo => ({ ...photo, provider: "wikimedia" as const }));
        const photos = await (deps.cacheWikimedia ? deps.cacheWikimedia(job, input, publicIdentity, loadWikimedia) : loadWikimedia());
        const safePhotos: PlaceImage[] = photos.filter(photo => photo.confidence === "verified" || photo.confidence === "suggested").map(photo => ({ ...photo, provider: "wikimedia" as const }));
        const verified = safePhotos.find(photo => photo.confidence === "verified") ?? null;
        if (!verified && input.place.source_url) {
          const preview = await (deps.fetchPreview ?? fetchPreviewImage)(input.place.source_url);
          if (preview) safePhotos.push(preview);
        }
        const needsImageReview = !verified;
        const result: EnrichmentResult = { resolution, image: verified, candidates: safePhotos, selection_version: 4, review_reason: needsImageReview ? "no_verified_photo" : null };
        await deps.complete(job, result, needsImageReview ? "needs_review" : "ready"); processed++;
      } catch (error) {
        const code = error instanceof EnrichmentError ? error.code : "provider_unavailable";
        const retryable = !(error instanceof EnrichmentError && error.code === "google_not_configured");
        try {
          if (error instanceof EnrichmentError && error.status === 429 && deps.defer) await deps.defer(job, error.retryAfterSeconds, code);
          else await deps.fail(job, code, retryable);
        } catch { /* expired lease is reclaimed by the database */ }
      }
    }
    return { processed };
    })();
    if (deps.waitUntil) { deps.waitUntil(task); return json({ accepted: true }, 202); }
    await task;
    return json({ accepted: true }, 202);
  };
}
