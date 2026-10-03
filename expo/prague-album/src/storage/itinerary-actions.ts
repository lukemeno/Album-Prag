import type { SQLiteDatabase } from 'expo-sqlite';
import type { Place } from '@/domain/place';
import { coordinateFor, planItinerary, type Coordinate, type DayPlanProposal, type FlightLike } from '@/domain/itinerary';
import { readPlaces } from '@/storage/place-store';

export interface ItinerarySnapshot {
  albumID: string;
  tripID: string;
  trip: string;
  places: Record<string, string>;
  hotel: Coordinate;
  flights: FlightLike[];
}

export interface ItineraryPreview {
  proposal: DayPlanProposal;
  snapshot: ItinerarySnapshot;
}

export interface ItineraryUndoRecord {
  albumID: string;
  tripID: string;
  trip: string;
  assignments: { id: string; day: number | null; dayOrder: number | null }[];
  applied: Record<string, string>;
}

export class ItineraryActionError extends Error {
  constructor(message: string) { super(message); this.name = 'ItineraryActionError'; }
}

interface PlaceActionRow {
  id: string;
  title: string;
  category: string;
  address: string;
  lat: number | null;
  lng: number | null;
  franked: number;
  deleted: number;
  day: number | null;
  day_order: number | null;
  opening_hours: string | null;
  updated_at: number;
}

function fingerprint(place: Pick<PlaceActionRow, 'id' | 'title' | 'category' | 'address' | 'lat' | 'lng' | 'franked' | 'deleted' | 'day' | 'day_order' | 'opening_hours' | 'updated_at'>): string {
  return JSON.stringify({ id: place.id, title: place.title, category: place.category, address: place.address, lat: place.lat, lng: place.lng, franked: Boolean(place.franked), deleted: Boolean(place.deleted), day: place.day, dayOrder: place.day_order, openingHours: place.opening_hours, updatedAt: place.updated_at });
}

function rowFromPlace(place: Place): PlaceActionRow {
  return { id: place.id, title: place.title, category: place.category, address: place.address ?? '', lat: typeof place.lat === 'number' ? place.lat : null, lng: typeof place.lng === 'number' ? place.lng : null, franked: Number(place.franked), deleted: Number(place.deleted), day: place.day, day_order: place.dayOrder, opening_hours: place.openingHours, updated_at: place.updatedAt };
}

function decodeObject(value: string | undefined): Record<string, unknown> {
  if (!value) return {};
  try { const parsed: unknown = JSON.parse(value); return parsed && typeof parsed === 'object' && !Array.isArray(parsed) ? parsed as Record<string, unknown> : {}; } catch { return {}; }
}

function flightsFromTrip(trip: Record<string, unknown>): FlightLike[] {
  const value = trip.flights;
  if (!Array.isArray(value)) return [];
  return value.flatMap((item) => {
    if (!item || typeof item !== 'object' || Array.isArray(item)) return [];
    const record = item as Record<string, unknown>;
    return [{ direction: typeof record.direction === 'string' ? record.direction : undefined, departure: typeof record.departure === 'string' ? record.departure : undefined, arrival: typeof record.arrival === 'string' ? record.arrival : undefined }];
  });
}

function hotelFromPlaces(places: readonly Place[]): Coordinate {
  const hotel = places.find((place) => place.franked && place.category === 'Unterkunft' && coordinateFor(place) !== null);
  return (hotel ? coordinateFor(hotel) : null) ?? { latitude: 50.0875, longitude: 14.4213 };
}

async function settings(db: SQLiteDatabase): Promise<Record<string, string>> {
  const rows = await db.getAllAsync<{ key: string; value: string }>("SELECT key,value FROM album_settings WHERE key IN ('trip','albumID','tripID')");
  return Object.fromEntries(rows.map((row) => [row.key, row.value]));
}

export async function readItineraryPreview(db: SQLiteDatabase, keepAssigned = true): Promise<ItineraryPreview> {
  const [settingValues, places] = await Promise.all([settings(db), readPlaces(db)]);
  const trip = settingValues.trip ?? '';
  const tripObject = decodeObject(trip);
  const flights = flightsFromTrip(tripObject);
  const hotel = hotelFromPlaces(places);
  const relevant = places.filter((place) => place.franked);
  const snapshot: ItinerarySnapshot = { albumID: settingValues.albumID ?? '', tripID: settingValues.tripID ?? '', trip, places: Object.fromEntries(relevant.map((place) => { const row = rowFromPlace(place); return [row.id, fingerprint(row)]; })), hotel, flights };
  return { proposal: planItinerary(places, hotel, flights, keepAssigned), snapshot };
}

function idsForSnapshot(snapshot: ItinerarySnapshot): string[] {
  const ids = Object.keys(snapshot.places);
  if (!ids.length) throw new ItineraryActionError('Für diese Reise gibt es keine bestätigten Orte.');
  return ids;
}

async function verifyScope(transaction: SQLiteDatabase, expected: Pick<ItinerarySnapshot, 'albumID' | 'tripID' | 'trip'>): Promise<void> {
  const rows = await transaction.getAllAsync<{ key: string; value: string }>("SELECT key,value FROM album_settings WHERE key IN ('trip','albumID','tripID')");
  const values = Object.fromEntries(rows.map((row) => [row.key, row.value]));
  if ((values.trip ?? '') !== expected.trip || (values.albumID ?? '') !== expected.albumID || (values.tripID ?? '') !== expected.tripID) throw new ItineraryActionError('Die Reise wurde geändert, seit diese Vorschau erstellt wurde.');
}

function validateProposal(proposal: DayPlanProposal, rows: readonly PlaceActionRow[], expected: ItinerarySnapshot): { id: string; day: number; order: number }[] {
  const byID = new Map(rows.map((row) => [row.id, row]));
  const seen = new Set<string>();
  const assignments: { id: string; day: number; order: number }[] = [];
  for (const [dayText, stops] of Object.entries(proposal.days)) {
    const day = Number(dayText);
    if (!Number.isInteger(day) || day < 4 || day > 9 || !Array.isArray(stops)) throw new ItineraryActionError('Die Vorschau enthält einen ungültigen Reisetag.');
    for (const [order, stop] of stops.entries()) {
      const id = stop?.place?.id;
      const row = typeof id === 'string' ? byID.get(id) : undefined;
      if (!row || seen.has(id) || expected.places[id] === undefined || row.deleted || !row.franked || row.category === 'Unterkunft' || !coordinateFor({ lat: row.lat ?? undefined, lng: row.lng ?? undefined })) throw new ItineraryActionError('Die Vorschau enthält einen nicht mehr gültigen Ort.');
      seen.add(id);
      assignments.push({ id, day, order });
    }
  }
  if (!assignments.length && !proposal.leftOver.length) throw new ItineraryActionError('Die Vorschau enthält keine Orte.');
  return assignments;
}

export async function applyItineraryPlan(db: SQLiteDatabase, preview: ItineraryPreview): Promise<ItineraryUndoRecord> {
  let result: ItineraryUndoRecord | undefined;
  await db.withExclusiveTransactionAsync(async (transaction) => {
    await verifyScope(transaction, preview.snapshot);
    const ids = idsForSnapshot(preview.snapshot);
    const approvedRows = await transaction.getAllAsync<{ id: string }>('SELECT id FROM places WHERE deleted = 0 AND franked = 1');
    const expectedIDs = new Set(ids);
    if (approvedRows.length !== expectedIDs.size || approvedRows.some((row) => !expectedIDs.has(row.id))) throw new ItineraryActionError('Die bestätigten Orte wurden geändert, seit diese Vorschau erstellt wurde.');
    const placeholders = ids.map(() => '?').join(',');
    const rows = await transaction.getAllAsync<PlaceActionRow>(`SELECT id,title,category,address,lat,lng,franked,deleted,day,day_order,opening_hours,updated_at FROM places WHERE id IN (${placeholders})`, ids);
    if (rows.length !== ids.length || rows.some((row) => fingerprint(row) !== preview.snapshot.places[row.id])) throw new ItineraryActionError('Die Reise oder ein Ort wurde geändert, seit diese Vorschau erstellt wurde.');
    const assignments = validateProposal(preview.proposal, rows, preview.snapshot);
    const before = new Map(rows.map((row) => [row.id, row]));
    const changed = assignments.filter((assignment) => {
      const row = before.get(assignment.id);
      return row && (row.day !== assignment.day || row.day_order !== assignment.order);
    });
    const now = Date.now();
    for (const assignment of changed) {
      const row = before.get(assignment.id)!;
      await transaction.runAsync('UPDATE places SET day = ?, day_order = ?, updated_at = ? WHERE id = ?', [assignment.day, assignment.order, Math.max(now, row.updated_at + 1), assignment.id]);
    }
    const changedRows = changed.length ? await transaction.getAllAsync<PlaceActionRow>(`SELECT id,title,category,address,lat,lng,franked,deleted,day,day_order,opening_hours,updated_at FROM places WHERE id IN (${changed.map(() => '?').join(',')})`, changed.map((item) => item.id)) : [];
    result = { albumID: preview.snapshot.albumID, tripID: preview.snapshot.tripID, trip: preview.snapshot.trip, assignments: changed.map((assignment) => { const row = before.get(assignment.id)!; return { id: assignment.id, day: row.day, dayOrder: row.day_order }; }), applied: Object.fromEntries(changedRows.map((row) => [row.id, fingerprint(row)])) };
  });
  if (!result) throw new ItineraryActionError('Der Tagesplan konnte nicht gespeichert werden.');
  return result;
}

export async function undoItineraryPlan(db: SQLiteDatabase, record: ItineraryUndoRecord): Promise<void> {
  await db.withExclusiveTransactionAsync(async (transaction) => {
    await verifyScope(transaction, record);
    const ids = Object.keys(record.applied);
    if (!ids.length) throw new ItineraryActionError('Diese Vorschau hatte keine Änderungen.');
    const placeholders = ids.map(() => '?').join(',');
    const rows = await transaction.getAllAsync<PlaceActionRow>(`SELECT id,title,category,address,lat,lng,franked,deleted,day,day_order,opening_hours,updated_at FROM places WHERE id IN (${placeholders})`, ids);
    if (rows.length !== ids.length || rows.some((row) => fingerprint(row) !== record.applied[row.id])) throw new ItineraryActionError('Die betroffenen Orte wurden seit dem Anwenden geändert.');
    const byID = new Map(rows.map((row) => [row.id, row]));
    const now = Date.now();
    for (const assignment of record.assignments) {
      const row = byID.get(assignment.id);
      if (!row) throw new ItineraryActionError('Ein Ort der Rücknahme fehlt.');
      await transaction.runAsync('UPDATE places SET day = ?, day_order = ?, updated_at = ? WHERE id = ?', [assignment.day, assignment.dayOrder, Math.max(now, row.updated_at + 1), assignment.id]);
    }
  });
}
