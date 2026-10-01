export type PlaceCandidate = {
  id: string;
  name: string;
  address?: string;
  latitude: number;
  longitude: number;
  image?: string;
  sourceURL?: string;
  /// Commons-Kategorie des Orts (Wikidata P373), dort liegen meist die bekannten Motive.
  commonsCategory?: string;
  raw?: unknown;
};

export type WikimediaFile = {
  imageURL: string;
  sourceURL: string;
  credit: string;
  licenseName?: string;
  licenseURL?: string;
};

export function choosePlace(candidates: PlaceCandidate[], title: string, latitude: number, longitude: number, address = "") {
  const ranked = candidates
    .map(candidate => ({ candidate, rank: rankCandidate(candidate, title, latitude, longitude, address) }))
    .filter(value => value.rank !== null)
    .sort((left, right) => left.rank! - right.rank!);
  const best = ranked[0];
  if (!best) return undefined;
  const other = ranked.find(value => value.candidate.id !== best.candidate.id);
  if (other && other.rank! - best.rank! < 50) return undefined;
  return best.candidate;
}

export function rankCandidate(candidate: PlaceCandidate, title: string, latitude: number, longitude: number, address = "") {
  if (!candidate.id || !candidate.name || !validCoordinate(candidate.latitude, candidate.longitude)) return null;
  const wanted = houseNumbers(address);
  const found = houseNumbers(candidate.address ?? "");
  if (wanted.length && found.length && !wanted.some(number => found.includes(number))) return null;
  const query = normalize(title);
  const name = normalize(candidate.name);
  const meters = distanceMeters(candidate.latitude, candidate.longitude, latitude, longitude);
  const exact = name === query;
  const similarity = tokenSimilarity(name, query);
  if (exact && meters <= 350) return meters;
  if (similarity >= 0.8 && meters <= 120) return 10_000 + (1 - similarity) * 1_000 + meters;
  return null;
}

function houseNumbers(address: string): string[] {
  const street = address.split(",").map(part => part.trim()).find(part =>
    !/^(?:praha|prague|prag)\s+\d/i.test(part) && !/^\d{5}\b/.test(part) && /\d{1,4}[a-z]?\s*$/.test(part)
  ) ?? "";
  const number = street.match(/\b(\d{1,4}[a-z]?)(?:\s*\/\s*(\d{1,4}[a-z]?))?\s*$/i);
  return number?.slice(1).filter(Boolean).map(value => value.toLowerCase()) ?? [];
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

/// Ein Foto-Kandidat von Wikimedia Commons, bevor er bewertet wird.
export type PhotoCandidate = {
  title: string;
  source: "main" | "category" | "nearby";
  uses: number;
  assessments: string;
  width: number;
  height: number;
  meters?: number;
  depictsPlace?: boolean;
};

export function photoConfidence(photo: PhotoCandidate, placeNames: string | string[], category: string): "verified" | "suggested" {
  const fileStems = new Set(stems(photo.title));
  const names = (Array.isArray(placeNames) ? placeNames : [placeNames]).map(stems).filter(words => words.length);
  const matchesName = names.some(words => words.every(word => fileStems.has(word)));
  const viewpoint = category !== "Aussicht" || categoryHints.Aussicht.some(word => normalize(photo.title).includes(word));
  const tiedToPlace = photo.source === "main" || (matchesName && (photo.source === "category" || photo.depictsPlace));
  return viewpoint && tiedToPlace ? "verified" : "suggested";
}

// Worte im Dateinamen, die zur Kategorie passen: Bei einer Aussicht will man den Blick, beim Café den Raum.
const categoryHints: Record<string, string[]> = {
  "Aussicht": ["view", "panorama", "vyhled", "pohled", "blick", "aussicht", "skyline", "sunset", "sunrise", "vltava", "moldau", "nad prahou", "over prague"],
  "Essen & Trinken": ["interior", "interier", "cafe", "kavarna", "restaurant", "restaurace", "food", "bar", "pub", "hospoda"],
  // Bei Sehenswürdigkeiten zeigt „view“ meist den Blick *von* dort, nicht den Ort selbst.
  "Sehenswert": ["facade", "fasada", "exterior"],
  "Unterkunft": ["hotel", "facade", "fasada", "exterior"],
};

// Motive, die fast nie das sind, wofür man einen Ort besucht.
const offTopic = ["demonstr", "protest", "pochod", "exhibition", "vystava", "obnova", "oprava", "construction", "brouk", "beetle",
  "kick", "match", "zapas", "map", "mapa", "plan ", "logo", "coat of arms", "znak", "sign", "tabul", "plaque", "deska", "dort", "cake"];

/// Wortanfänge (4 Zeichen), damit Beugungen passen: „Karlův most“ trifft „Karlově mostě“.
const stems = (value: string) => normalize(value).split(" ").filter(token => token.length >= 3).map(token => token.slice(0, 4));

/// Punkte für ein Foto: typisch (oft in Wikipedia verwendet, ausgezeichnet), passend zur Kategorie, nicht nebensächlich.
/// `placeNames` sind alle Namen des Orts (Titel in der App plus Wikidata-Namen in allen Sprachen). Null heißt: nicht verwenden.
export function scorePhoto(photo: PhotoCandidate, placeNames: string | string[], category: string): number | null {
  if (!/\.(jpe?g|webp)$/i.test(photo.title)) return null;
  const name = normalize(photo.title.replace(/^File:/i, "").replace(/\.[a-z]+$/i, ""));
  if (offTopic.some(word => name.includes(word))) return null;
  if (category === "Aussicht" && ["stadion", "stadium", "arena"].some(word => name.includes(word))) return null;
  const words = name.split(" ").filter(Boolean);
  const wordStems = new Set(words.map(word => word.slice(0, 4)));
  const names = (Array.isArray(placeNames) ? placeNames : [placeNames]).map(stems).filter(list => list.length);
  // Ein Name trifft, wenn alle seine Wörter im Dateinamen vorkommen.
  const matchesPlace = names.some(list => list.every(stem => wordStems.has(stem)));
  // Stichworte zählen nur außerhalb des Ortsnamens: Bei „Café Louvre“ sagt „cafe“ im Dateinamen nichts über das Motiv.
  const placeStems = new Set(names.flat());
  const rest = words.filter(word => !placeStems.has(word.slice(0, 4))).join(" ");
  const hint = (categoryHints[category] ?? []).some(word => rest.includes(word));
  // Fotos aus der Umgebung brauchen einen Bezug: den Ortsnamen, bei Aussichtspunkten reicht auch ein Blick-Stichwort.
  if (photo.source === "nearby" && !matchesPlace && !photo.depictsPlace) return null;

  // Das Hauptbild steckt in jeder Infobox; seine Verwendung zählt deshalb nur begrenzt.
  // „View from Charles Bridge of …“ zeigt etwas anderes, von der Brücke aus fotografiert.
  const fromIndex = words.findIndex(word => ["from", "von", "vom", "z", "ze"].includes(word));
  const viewFromPlace = fromIndex >= 0 && words.slice(fromIndex + 1).some(word => placeStems.has(word.slice(0, 4)));
  if (viewFromPlace && category !== "Aussicht") return null;

  let score = Math.min(photo.uses, photo.source === "main" ? 5 : 10) * 3;
  const assessed = photo.assessments.toLowerCase();
  if (assessed.includes("featured") || assessed.includes("poty")) score += 30;
  else if (assessed.includes("quality") || assessed.includes("valued")) score += 15;
  if (hint) score += 20;
  if (matchesPlace) score += 8;
  if (photo.source === "main") score += 12;
  if (photo.depictsPlace) score += 30;
  if (photo.width >= photo.height) score += 5; else score -= 5;
  if (photo.width < 1000) score -= 15;
  if (photo.meters != null) score -= photo.meters / 50;
  return score;
}

/// Die besten Fotos, bestes zuerst. Aus einer Serie („… 01“, „… 02“, gleicher Name mit Zeitstempel) bleibt nur das beste.
export function rankPhotos(photos: PhotoCandidate[], placeNames: string | string[], category: string, limit = 8) {
  const series = new Set<string>();
  return photos
    .map(photo => ({ photo, score: scorePhoto(photo, placeNames, category), confidence: photoConfidence(photo, placeNames, category) }))
    .filter((value): value is { photo: PhotoCandidate; score: number; confidence: "verified" | "suggested" } => value.score !== null && value.score >= 10)
    .sort((left, right) => Number(right.confidence === "verified") - Number(left.confidence === "verified") || right.score - left.score)
    .filter(({ photo }) => {
      const key = seriesKey(photo.title);
      return !series.has(key) && !!series.add(key);
    })
    .slice(0, limit);
}

export function seriesKey(title: string) {
  return normalize(title.replace(/^File:/i, "").replace(/\.[a-z]+$/i, "")).replace(/\d+/g, "").replace(/\s+/g, " ").trim();
}
