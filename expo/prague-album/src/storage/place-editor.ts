import * as Crypto from 'expo-crypto';
import type { SQLiteDatabase } from 'expo-sqlite';
import type { Place } from '@/domain/place';
import { assetJSON, imageAsset, shouldDiscardOnMove, type PlaceImageAsset } from '@/domain/place-images';
import { parseOpeningHours } from '@/domain/opening-hours';

export interface PlaceDraft {
  id: string;
  title: string;
  note: string;
  sourceURL: string;
  category: string;
  author: string;
  address: string;
  lat: number | null;
  lng: number | null;
  franked: boolean;
  deferred: boolean;
  deleted: boolean;
  visited: boolean;
  day: number | null;
  dayOrder: number | null;
  image: PlaceImageAsset | null;
  gallery: Record<string, unknown>[] | null;
  openingHours: string | null;
  openingHoursOriginal?: string | null;
}

interface PlaceRow { id: string; title: string; note: string; source_url: string; category: string; author: string; image_json: string | null; address: string; lat: number | null; lng: number | null; franked: number; deferred: number; deleted: number; visited: number; day: number | null; day_order: number | null; approvals_json: string; passed_by_json: string; opening_hours: string | null; gallery_json: string | null; updated_at: number; }

function decodeJSON<T>(value: string | null, fallback: T): T { try { return value ? JSON.parse(value) as T : fallback; } catch { return fallback; } }
function asPlace(row: PlaceRow): Place {
  return { id: row.id, title: row.title, note: row.note, sourceURL: row.source_url, category: row.category, author: row.author, image: decodeJSON<Record<string, unknown> | null>(row.image_json, null), address: row.address, lat: row.lat ?? undefined, lng: row.lng ?? undefined, franked: Boolean(row.franked), deferred: Boolean(row.deferred), deleted: Boolean(row.deleted), visited: Boolean(row.visited), day: row.day, dayOrder: row.day_order, approvals: decodeJSON<string[]>(row.approvals_json, []), passedBy: decodeJSON<string[]>(row.passed_by_json, []), openingHours: row.opening_hours, gallery: decodeJSON<Record<string, unknown>[] | null>(row.gallery_json, null), updatedAt: row.updated_at };
}

export function newPlaceDraft(author: string): PlaceDraft { return { id: Crypto.randomUUID(), title: '', note: '', sourceURL: '', category: 'Idee', author: author || 'Ich', address: '', lat: null, lng: null, franked: false, deferred: false, deleted: false, visited: false, day: null, dayOrder: null, image: null, gallery: null, openingHours: null, openingHoursOriginal: null }; }
export async function readPlace(db: SQLiteDatabase, id: string): Promise<Place | null> { const row = await db.getFirstAsync<PlaceRow>('SELECT * FROM places WHERE id = ?', [id]); return row ? asPlace(row) : null; }
export async function readArchivedPlaces(db: SQLiteDatabase): Promise<Place[]> { const rows = await db.getAllAsync<PlaceRow>('SELECT * FROM places WHERE deleted = 1 ORDER BY updated_at DESC'); return rows.map(asPlace); }

export async function savePlaceDraft(db: SQLiteDatabase, draft: PlaceDraft): Promise<Place> {
  const title = draft.title.trim();
  if (!title) throw new Error('Bitte gib dem Ort einen Namen.');
  if (draft.sourceURL.trim()) {
    try { const url = new URL(draft.sourceURL.trim()); if (!['http:', 'https:'].includes(url.protocol) || !url.hostname) throw new Error(); }
    catch { throw new Error('Bitte gib einen gültigen http:// oder https:// Link ein.'); }
  }
  if ((draft.lat === null) !== (draft.lng === null)) throw new Error('Breiten- und Längengrad müssen gemeinsam gesetzt werden.');
  if (draft.lat !== null && (!Number.isFinite(draft.lat) || draft.lat < -90 || draft.lat > 90)) throw new Error('Der Breitengrad ist ungültig.');
  if (draft.lng !== null && (!Number.isFinite(draft.lng) || draft.lng < -180 || draft.lng > 180)) throw new Error('Der Längengrad ist ungültig.');
  if (draft.day !== null && (!Number.isInteger(draft.day) || draft.day < 4 || draft.day > 9)) throw new Error('Der Reisetag ist ungültig.');
  if (draft.dayOrder !== null && (!Number.isInteger(draft.dayOrder) || draft.dayOrder < 0)) throw new Error('Die Reihenfolge des Ortes ist ungültig.');
  const openingHours = draft.openingHours?.trim() || null;
  if (openingHours && !parseOpeningHours(openingHours) && openingHours !== (draft.openingHoursOriginal?.trim() || null)) throw new Error('Öffnungszeiten bitte im unterstützten Format eingeben, zum Beispiel „Mo-Fr 09:00-18:00“.');
  let saved: Place | null = null;
  await db.withExclusiveTransactionAsync(async (transaction) => {
    const existing = await transaction.getFirstAsync<PlaceRow>('SELECT * FROM places WHERE id = ?', [draft.id]);
    const updatedAt = Math.max(Date.now(), Number(existing?.updated_at ?? 0) + 1);
    const imageJSON = draft.image ? JSON.stringify(assetJSON(draft.image)) : null;
    const galleryJSON = draft.gallery ? JSON.stringify(draft.gallery) : null;
    const requestedOpeningHours = draft.openingHours?.trim() || null;
    const originalOpeningHours = draft.openingHoursOriginal?.trim() || null;
    const moved = existing && (existing.lat !== draft.lat || existing.lng !== draft.lng);
    const openingHours = existing && requestedOpeningHours === originalOpeningHours ? (moved ? null : existing.opening_hours) : requestedOpeningHours;
    if (existing) {
      await transaction.runAsync('UPDATE places SET title=?,note=?,source_url=?,category=?,author=?,image_json=?,address=?,lat=?,lng=?,franked=?,deferred=?,deleted=?,visited=?,day=?,day_order=?,opening_hours=?,gallery_json=?,updated_at=? WHERE id=?', [title, draft.note.trim(), draft.sourceURL.trim(), draft.category.trim() || 'Idee', draft.author.trim() || 'Ich', imageJSON, draft.address.trim(), draft.lat, draft.lng, existing.franked, existing.deferred, Number(draft.deleted), Number(draft.visited), draft.day, draft.dayOrder, openingHours, galleryJSON, updatedAt, draft.id]);
    } else {
      await transaction.runAsync("INSERT INTO places (id,title,note,source_url,category,author,image_json,address,lat,lng,franked,deferred,deleted,visited,day,day_order,approvals_json,passed_by_json,opening_hours,gallery_json,updated_at) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)", [draft.id, title, draft.note.trim(), draft.sourceURL.trim(), draft.category.trim() || 'Idee', draft.author.trim() || 'Ich', imageJSON, draft.address.trim(), draft.lat, draft.lng, Number(draft.franked), Number(draft.deferred), Number(draft.deleted), Number(draft.visited), draft.day, draft.dayOrder, '[]', '[]', openingHours, galleryJSON, updatedAt]);
    }
    const row = await transaction.getFirstAsync<PlaceRow>('SELECT * FROM places WHERE id = ?', [draft.id]);
    if (!row) throw new Error('Der Ort konnte nicht gespeichert werden.');
    saved = asPlace(row);
  });
  if (!saved) throw new Error('Der Ort konnte nicht gespeichert werden.');
  return saved;
}

export async function setPlaceDeleted(db: SQLiteDatabase, id: string, deleted: boolean): Promise<Place> {
  await db.runAsync('UPDATE places SET deleted = ?, updated_at = MAX(updated_at + 1, ?) WHERE id = ?', [Number(deleted), Date.now(), id]);
  const place = await readPlace(db, id);
  if (!place) throw new Error('Der Ort wurde nicht gefunden.');
  return place;
}

export function draftFromPlace(place: Place): PlaceDraft { return { ...place, address: place.address ?? '', lat: place.lat ?? null, lng: place.lng ?? null, image: imageAsset(place.image), openingHours: place.openingHours, openingHoursOriginal: place.openingHours }; }
export function selectPlaceLocation(draft: PlaceDraft, location: { title?: string; address?: string; latitude: number; longitude: number }): PlaceDraft {
  const moved = (typeof draft.lat === 'number' && typeof draft.lng === 'number') && (Math.abs(draft.lat - location.latitude) > 0.0001 || Math.abs(draft.lng - location.longitude) > 0.0001);
  const next = { ...draft, title: location.title?.trim() || draft.title, address: location.address?.trim() || '', lat: location.latitude, lng: location.longitude };
  if (moved) { next.openingHours = null; next.gallery = null; if (shouldDiscardOnMove(draft.image)) next.image = null; }
  return next;
}

export function staleEditorResult(generation: number, currentGeneration: number, draft: PlaceDraft, requested: PlaceDraft): boolean { return generation !== currentGeneration || draft.id !== requested.id || draft.title !== requested.title || draft.sourceURL !== requested.sourceURL || draft.lat !== requested.lat || draft.lng !== requested.lng; }
