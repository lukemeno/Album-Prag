import type { SQLiteDatabase } from 'expo-sqlite';
import { emptyTrip, type TripInfo } from '@/domain/trip';
const APPLE_EPOCH_MS = 978_307_200_000;
function parse(value: string | undefined): TripInfo { if (!value) return emptyTrip(); try { const raw = JSON.parse(value) as Partial<TripInfo>; const timestamp = typeof raw.updatedAt === 'number' ? (raw.updatedAt > 10_000_000_000 ? (raw.updatedAt - APPLE_EPOCH_MS) / 1000 : raw.updatedAt) : 0; return { ...emptyTrip(), ...raw, updatedAt: timestamp }; } catch { return emptyTrip(); } }
export interface TripInfoSnapshot { albumID: string | null; tripID: string | null; raw: string | null; trip: TripInfo; }
function appleNow(): number { return (Date.now() - APPLE_EPOCH_MS) / 1000; }
export async function readTripInfo(db: SQLiteDatabase): Promise<TripInfo> { const row = await db.getFirstAsync<{ value: string }>("SELECT value FROM album_settings WHERE key='trip'"); return parse(row?.value); }
export async function readTripInfoSnapshot(db: SQLiteDatabase): Promise<TripInfoSnapshot> { const rows = await db.getAllAsync<{ key: string; value: string }>("SELECT key,value FROM album_settings WHERE key IN ('albumID','tripID','trip')"); const values = new Map(rows.map((row) => [row.key, row.value])); return { albumID: values.get('albumID') ?? null, tripID: values.get('tripID') ?? null, raw: values.get('trip') ?? null, trip: parse(values.get('trip')) }; }
export async function saveTripInfo(db: SQLiteDatabase, trip: TripInfo, expected?: TripInfoSnapshot): Promise<TripInfo> {
  let saved: TripInfo;
  await db.withExclusiveTransactionAsync(async (transaction) => {
    const current = await readTripInfoSnapshot(transaction);
    if (expected && (current.albumID !== expected.albumID || current.tripID !== expected.tripID || current.raw !== expected.raw)) throw new Error('Die Reiseinformationen wurden inzwischen geändert. Bitte erneut prüfen.');
    const merged = { ...current.trip, ...trip };
    const next = { ...merged, updatedAt: Math.max(appleNow(), current.trip.updatedAt + 0.001) };
    const encoded = JSON.stringify(next);
    if (current.raw === null) await transaction.runAsync("INSERT INTO album_settings(key,value) VALUES ('trip',?)", [encoded]);
    else { const changed = await transaction.runAsync("UPDATE album_settings SET value=? WHERE key='trip' AND value=?", [encoded, current.raw]); if (changed.changes !== 1) throw new Error('Die Reiseinformationen wurden inzwischen geändert. Bitte erneut prüfen.'); }
    saved = next;
  });
  return saved!;
}
export function parseTripJSON(value: string | null | undefined): TripInfo { return parse(value ?? undefined); }
