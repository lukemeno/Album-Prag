import type { SQLiteDatabase } from 'expo-sqlite';

export interface OpeningHoursCandidate {
  id: string;
  title: string;
  address: string;
  category: string;
  lat: number;
  lng: number;
  openingHours: null;
}

export interface OpeningHoursRefreshResult { updated: number; unknown: number; errors: number; cancelled: boolean; }
interface OverpassElement { tags?: Record<string, string>; }
interface OverpassPayload { elements?: OverpassElement[]; }
interface FetchResult { id: string; hours: string | null; }

function finiteCoordinate(place: Pick<OpeningHoursCandidate, 'lat' | 'lng'>): boolean {
  return Number.isFinite(place.lat) && Number.isFinite(place.lng) && place.lat >= -90 && place.lat <= 90 && place.lng >= -180 && place.lng <= 180;
}

function words(value: string): Set<string> {
  return new Set(value.normalize('NFKD').replace(/[\u0300-\u036f]/gu, '').toLocaleLowerCase('de-DE').split(/[^\p{L}\p{N}]+/u).filter((word) => word.length >= 2));
}

export function bestOpeningHoursMatch(elements: readonly Record<string, string>[], title: string): string | null {
  const wanted = words(title);
  if (!wanted.size) return null;
  let best: { hours: string; score: number } | null = null;
  for (const tags of elements) {
    if (typeof tags.name !== 'string' || typeof tags.opening_hours !== 'string') continue;
    const found = words(tags.name);
    const union = new Set([...wanted, ...found]);
    const score = union.size ? [...wanted].filter((word) => found.has(word)).length / union.size : 0;
    if (score >= 0.5 && (!best || score > best.score)) best = { hours: tags.opening_hours, score };
  }
  return best?.hours ?? null;
}

async function fetchForPlace(place: OpeningHoursCandidate, signal: AbortSignal): Promise<FetchResult> {
  if (signal.aborted || !finiteCoordinate(place)) return { id: place.id, hours: null };
  const query = `[out:json][timeout:15];nwr(around:80,${place.lat},${place.lng})["opening_hours"]["name"];out tags;`;
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 20_000);
  const abort = () => controller.abort();
  signal.addEventListener('abort', abort, { once: true });
  try {
    const response = await fetch('https://overpass-api.de/api/interpreter', { method: 'POST', headers: { 'Content-Type': 'application/x-www-form-urlencoded', Accept: 'application/json', 'User-Agent': 'PragueAlbum/1.0' }, body: `data=${encodeURIComponent(query)}`, signal: controller.signal });
    if (!response.ok) return { id: place.id, hours: null };
    const payload = await response.json() as OverpassPayload;
    const elements = Array.isArray(payload.elements) ? payload.elements.flatMap((element) => element.tags ? [element.tags] : []) : [];
    return { id: place.id, hours: bestOpeningHoursMatch(elements, place.title) ?? '' };
  } catch { return { id: place.id, hours: null }; }
  finally { clearTimeout(timer); signal.removeEventListener('abort', abort); }
}

async function albumScope(db: SQLiteDatabase): Promise<{ tripID: string; albumID: string }> {
  const rows = await db.getAllAsync<{ key: string; value: string }>("SELECT key,value FROM album_settings WHERE key IN ('tripID','albumID')");
  const values = Object.fromEntries(rows.map((row) => [row.key, row.value]));
  return { tripID: values.tripID ?? '', albumID: values.albumID ?? '' };
}

export async function refreshOpeningHours(db: SQLiteDatabase, expectedTripID: string | null, signal: AbortSignal = new AbortController().signal): Promise<OpeningHoursRefreshResult> {
  const initialScope = await albumScope(db);
  const initialTripID = initialScope.tripID;
  const scopeTripID = expectedTripID ?? initialTripID;
  if (initialTripID !== scopeTripID) throw new Error('Die Reise wurde geändert. Bitte die Vorschau neu laden.');
  const rows = await db.getAllAsync<{ id: string; title: string; address: string; category: string; lat: number | null; lng: number | null; opening_hours: string | null }>('SELECT id,title,address,category,lat,lng,opening_hours FROM places WHERE deleted = 0 AND franked = 1 AND category <> \'Unterkunft\' AND opening_hours IS NULL AND lat IS NOT NULL AND lng IS NOT NULL');
  const candidates: OpeningHoursCandidate[] = rows.filter((row): row is typeof row & { lat: number; lng: number; opening_hours: null } => typeof row.lat === 'number' && typeof row.lng === 'number' && row.opening_hours === null && finiteCoordinate({ lat: row.lat, lng: row.lng })).map((row) => ({ id: row.id, title: row.title, address: row.address, category: row.category, lat: row.lat, lng: row.lng, openingHours: null }));
  const result: OpeningHoursRefreshResult = { updated: 0, unknown: 0, errors: 0, cancelled: false };
  for (let start = 0; start < candidates.length; start += 3) {
    if (signal.aborted) { result.cancelled = true; return result; }
    const batch = candidates.slice(start, start + 3);
    const fetched = await Promise.all(batch.map((candidate) => fetchForPlace(candidate, signal)));
    if (signal.aborted) { result.cancelled = true; return result; }
    for (const item of fetched) {
      if (signal.aborted) { result.cancelled = true; return result; }
      if (item.hours === null) { result.errors += 1; continue; }
      await db.withExclusiveTransactionAsync(async (transaction) => {
        const currentScope = await albumScope(transaction);
        if (currentScope.tripID !== scopeTripID || currentScope.albumID !== initialScope.albumID) throw new Error('Die Reise wurde geändert. Bitte die Vorschau neu laden.');
        const current = await transaction.getFirstAsync<{ id: string; title: string; address: string; category: string; lat: number | null; lng: number | null; opening_hours: string | null; updated_at: number; franked: number; deleted: number }>('SELECT id,title,address,category,lat,lng,opening_hours,updated_at,franked,deleted FROM places WHERE id = ?', [item.id]);
        const requested = candidates.find((candidate) => candidate.id === item.id);
        if (!current || !requested || !current.franked || current.deleted || current.opening_hours !== null || current.title !== requested.title || current.address !== requested.address || current.category !== requested.category || current.lat !== requested.lat || current.lng !== requested.lng) return;
        await transaction.runAsync('UPDATE places SET opening_hours = ?, updated_at = MAX(updated_at + 1, ?) WHERE id = ?', [item.hours, Date.now(), item.id]);
        if (item.hours) result.updated += 1;
        else result.unknown += 1;
      });
    }
  }
  return result;
}
