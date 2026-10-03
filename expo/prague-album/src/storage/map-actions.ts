import type { SQLiteDatabase } from 'expo-sqlite';
import type { Place } from '@/domain/place';
import { TRIP_DAYS, validCoordinate } from '@/domain/map-route';
import { shouldDiscardOnMove } from '@/domain/place-images';

interface MapPlaceRow {
  id: string; title: string; category: string; address: string; lat: number | null; lng: number | null;
  franked: number; deleted: number; visited: number; day: number | null; day_order: number | null;
  approvals_json: string; passed_by_json: string; updated_at: number;
  image_json: string | null; gallery_json: string | null; opening_hours: string | null;
}
export interface MapSnapshot { albumID: string; tripID: string; trip: string; places: Record<string, string>; }
export interface MapAssignment { id: string; day: number | null; dayOrder: number | null; }
export interface CoordinateChoice { latitude: number; longitude: number; }
export class MapActionError extends Error { constructor(message: string) { super(message); this.name = 'MapActionError'; } }

function fingerprint(row: MapPlaceRow): string {
  return JSON.stringify({ id: row.id, title: row.title, category: row.category, address: row.address, lat: row.lat, lng: row.lng, franked: Boolean(row.franked), deleted: Boolean(row.deleted), visited: Boolean(row.visited), day: row.day, dayOrder: row.day_order, updatedAt: row.updated_at });
}
function placeFingerprint(place: Pick<Place, 'id' | 'title' | 'category' | 'address' | 'lat' | 'lng' | 'franked' | 'deleted' | 'visited' | 'day' | 'dayOrder' | 'updatedAt'>): string {
  return JSON.stringify({ id: place.id, title: place.title, category: place.category, address: place.address, lat: place.lat ?? null, lng: place.lng ?? null, franked: Boolean(place.franked), deleted: Boolean(place.deleted), visited: Boolean(place.visited), day: place.day, dayOrder: place.dayOrder, updatedAt: place.updatedAt });
}
export function mapSnapshotMatchesPlaces(snapshot: MapSnapshot, places: readonly Place[]): boolean {
  const approved = places.filter((place) => !place.deleted && place.franked);
  if (approved.length !== Object.keys(snapshot.places).length) return false;
  return approved.every((place) => snapshot.places[place.id] === placeFingerprint(place));
}
function fromRow(row: MapPlaceRow): Place {
  return { id: row.id, title: row.title, note: '', sourceURL: '', category: row.category, author: '', image: null, address: row.address, lat: row.lat ?? undefined, lng: row.lng ?? undefined, franked: Boolean(row.franked), deferred: false, deleted: Boolean(row.deleted), visited: Boolean(row.visited), day: row.day, dayOrder: row.day_order, approvals: parseList(row.approvals_json), passedBy: parseList(row.passed_by_json), openingHours: null, gallery: null, updatedAt: row.updated_at };
}
function parseList(value: string): string[] { try { const parsed: unknown = JSON.parse(value); return Array.isArray(parsed) ? parsed.filter((item): item is string => typeof item === 'string') : []; } catch { return []; } }
async function scope(db: SQLiteDatabase): Promise<{ albumID: string; tripID: string; trip: string }> {
  const rows = await db.getAllAsync<{ key: string; value: string }>("SELECT key,value FROM album_settings WHERE key IN ('albumID','tripID','trip')");
  const values = Object.fromEntries(rows.map((row) => [row.key, row.value]));
  return { albumID: values.albumID ?? '', tripID: values.tripID ?? '', trip: values.trip ?? '' };
}
async function currentRows(db: SQLiteDatabase): Promise<MapPlaceRow[]> {
  return db.getAllAsync<MapPlaceRow>('SELECT id,title,category,address,lat,lng,franked,deleted,visited,day,day_order,approvals_json,passed_by_json,updated_at,image_json,gallery_json,opening_hours FROM places WHERE deleted = 0 AND franked = 1');
}
export async function readMapPlaces(db: SQLiteDatabase): Promise<Place[]> { return (await currentRows(db)).map(fromRow); }
export async function readMapSnapshot(db: SQLiteDatabase): Promise<MapSnapshot> {
  const [currentScope, rows] = await Promise.all([scope(db), currentRows(db)]);
  return { ...currentScope, places: Object.fromEntries(rows.map((row) => [row.id, fingerprint(row)])) };
}
async function verifySnapshot(transaction: SQLiteDatabase, snapshot: MapSnapshot): Promise<MapPlaceRow[]> {
  const currentScope = await scope(transaction);
  if (currentScope.albumID !== snapshot.albumID || currentScope.tripID !== snapshot.tripID || currentScope.trip !== snapshot.trip) throw new MapActionError('Die Reise wurde geändert. Bitte die Karte neu laden.');
  const rows = await currentRows(transaction);
  const expected = Object.keys(snapshot.places);
  if (rows.length !== expected.length || rows.some((row) => snapshot.places[row.id] !== fingerprint(row))) throw new MapActionError('Die Orte wurden geändert. Bitte die Karte neu laden.');
  return rows;
}
function validateAssignments(assignments: readonly MapAssignment[], rows: readonly MapPlaceRow[]): void {
  const expected = new Set(rows.map((row) => row.id));
  if (assignments.length !== expected.size || new Set(assignments.map((item) => item.id)).size !== assignments.length || assignments.some((item) => !expected.has(item.id))) throw new MapActionError('Die Tagesliste ist nicht mehr vollständig.');
  const byDay = new Map<number, number[]>();
  for (const assignment of assignments) {
    if (assignment.day !== null && (!Number.isInteger(assignment.day) || !TRIP_DAYS.includes(assignment.day as typeof TRIP_DAYS[number]))) throw new MapActionError('Der Reisetag ist ungültig.');
    if (assignment.day === null && assignment.dayOrder !== null) throw new MapActionError('Eine entfernte Zuweisung darf keine Reihenfolge haben.');
    if (assignment.day !== null && (!Number.isInteger(assignment.dayOrder) || (assignment.dayOrder ?? -1) < 0)) throw new MapActionError('Die Reihenfolge ist ungültig.');
    if (assignment.day !== null) byDay.set(assignment.day, [...(byDay.get(assignment.day) ?? []), assignment.dayOrder!]);
  }
  for (const orders of byDay.values()) {
    const sorted = [...orders].sort((a, b) => a - b);
    if (sorted.some((order, index) => order !== index)) throw new MapActionError('Die Tagesliste muss lückenlos sortiert sein.');
  }
}
export async function applyMapPlan(db: SQLiteDatabase, snapshot: MapSnapshot, assignments: readonly MapAssignment[], visited?: Readonly<Record<string, boolean>>): Promise<number> {
  let changed = 0;
  await db.withExclusiveTransactionAsync(async (transaction) => {
    const rows = await verifySnapshot(transaction, snapshot);
    validateAssignments(assignments, rows);
    const byID = new Map(assignments.map((item) => [item.id, item]));
    for (const row of rows) {
      const assignment = byID.get(row.id)!;
      const nextVisited = visited?.[row.id] ?? Boolean(row.visited);
      if (row.day === assignment.day && row.day_order === assignment.dayOrder && Boolean(row.visited) === nextVisited) continue;
      await transaction.runAsync('UPDATE places SET day = ?, day_order = ?, visited = ?, updated_at = MAX(updated_at + 1, ?) WHERE id = ?', [assignment.day, assignment.dayOrder, Number(nextVisited), Date.now(), row.id]);
      changed += 1;
    }
  });
  return changed;
}
export async function setPlaceCoordinates(db: SQLiteDatabase, snapshot: MapSnapshot, id: string, coordinate: CoordinateChoice): Promise<void> {
  if (!validCoordinate(coordinate)) throw new MapActionError('Die Kartenposition ist ungültig.');
  await db.withExclusiveTransactionAsync(async (transaction) => {
    const rows = await verifySnapshot(transaction, snapshot);
    const expected = snapshot.places[id];
    const row = rows.find((item) => item.id === id);
    if (!row || expected === undefined || fingerprint(row) !== expected) throw new MapActionError('Der Ort wurde geändert. Bitte die Karte neu laden.');
    const moved = row.lat === null || row.lng === null || Math.abs(row.lat - coordinate.latitude) > 0.0001 || Math.abs(row.lng - coordinate.longitude) > 0.0001;
    const image = row.image_json ? (() => { try { return JSON.parse(row.image_json) as Record<string, unknown>; } catch { return null; } })() : null;
    const nextImage = moved && shouldDiscardOnMove(image) ? null : row.image_json;
    await transaction.runAsync('UPDATE places SET lat = ?, lng = ?, image_json = ?, gallery_json = ?, opening_hours = ?, updated_at = MAX(updated_at + 1, ?) WHERE id = ?', [coordinate.latitude, coordinate.longitude, nextImage, moved ? null : row.gallery_json, moved ? null : row.opening_hours, Date.now(), id]);
  });
}
