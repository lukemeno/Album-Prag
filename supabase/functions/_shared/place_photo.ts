export type PlaceCandidate = {
  id: string;
  name: string;
  latitude: number;
  longitude: number;
  image?: string;
  sourceURL?: string;
  raw?: unknown;
};

export type WikimediaFile = {
  imageURL: string;
  sourceURL: string;
  credit: string;
  licenseName?: string;
  licenseURL?: string;
};

export function choosePlace(candidates: PlaceCandidate[], title: string, latitude: number, longitude: number) {
  return candidates
    .map(candidate => ({ candidate, rank: rankCandidate(candidate, title, latitude, longitude) }))
    .filter(value => value.rank !== null)
    .sort((left, right) => left.rank! - right.rank!)[0]?.candidate;
}

export function rankCandidate(candidate: PlaceCandidate, title: string, latitude: number, longitude: number) {
  if (!candidate.id || !candidate.name || !validCoordinate(candidate.latitude, candidate.longitude)) return null;
  const query = normalize(title);
  const name = normalize(candidate.name);
  const meters = distanceMeters(candidate.latitude, candidate.longitude, latitude, longitude);
  const exact = name === query;
  const similarity = tokenSimilarity(name, query);
  const contains = name.includes(query) || query.includes(name);
  if (exact && meters <= 2_000) return meters;
  if ((contains || similarity >= 0.6) && meters <= 250) return 10_000 + (1 - similarity) * 1_000 + meters;
  return null;
}

export function normalize(value: string) {
  return value.normalize("NFD").replace(/\p{Diacritic}/gu, "").replace(/[^a-zA-Z0-9]+/g, " ").trim().toLocaleLowerCase("en");
}

export function tokenSimilarity(left: string, right: string) {
  const a = new Set(normalize(left).split(" ").filter(Boolean));
  const b = new Set(normalize(right).split(" ").filter(Boolean));
  if (!a.size || !b.size) return 0;
  const intersection = [...a].filter(value => b.has(value)).length;
  return intersection / new Set([...a, ...b]).size;
}

export function distanceMeters(lat1: number, lng1: number, lat2: number, lng2: number) {
  const radians = (value: number) => value * Math.PI / 180;
  const dLat = radians(lat2 - lat1);
  const dLng = radians(lng2 - lng1);
  const a = Math.sin(dLat / 2) ** 2 + Math.cos(radians(lat1)) * Math.cos(radians(lat2)) * Math.sin(dLng / 2) ** 2;
  return 6_371_000 * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

export function validCoordinate(latitude: number, longitude: number) {
  return Number.isFinite(latitude) && Number.isFinite(longitude) && Math.abs(latitude) <= 90 && Math.abs(longitude) <= 180;
}

export function stripHTML(value?: string) {
  return value?.replace(/<[^>]*>/g, " ").replace(/&nbsp;/g, " ").replace(/&amp;/g, "&").replace(/&#39;/g, "'").replace(/&quot;/g, '"').replace(/\s+/g, " ").trim();
}

export function firstArray(payload: unknown): unknown[] {
  if (Array.isArray(payload)) return payload;
  if (!payload || typeof payload !== "object") return [];
  const value = payload as Record<string, unknown>;
  for (const key of ["data", "results", "content", "items", "locations", "search"]) {
    if (Array.isArray(value[key])) return value[key] as unknown[];
    if (value[key] && typeof value[key] === "object") {
      const nested = firstArray(value[key]);
      if (nested.length) return nested;
    }
  }
  return [];
}
