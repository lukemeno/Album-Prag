import type { SQLiteDatabase } from 'expo-sqlite';
import type { Place } from '@/domain/place';
import { relevantDocumentExcerpt, utf8Bytes, type AssistantContext, type AssistantContextPlace } from '@/domain/assistant';
import { supabase } from '@/storage/supabase';
import { readPlaces } from '@/storage/place-store';

interface DocumentPayload { id: string; name?: string; extractedText?: string; text?: string; trip_id?: string; }
interface CollectionPayload { id: string; text?: string; caption?: string; displayTitle?: string; url?: string; canonicalURL?: string; }

function documentIsRelevant(text: string, name: string, message: string): boolean {
  const words = message.toLocaleLowerCase('de-DE').split(/[^\p{L}\p{N}]+/u).filter((word) => word.length > 3);
  const searchable = `${name} ${text}`.toLocaleLowerCase('de-DE');
  return words.some((word) => searchable.includes(word)) || /flug|hotel|unterlage|buchung|dokument|check.?in/u.test(message.toLocaleLowerCase('de-DE'));
}

async function remoteIDs(table: 'places' | 'documents' | 'collection_entries', tripID: string): Promise<Set<string>> {
  if (!supabase) return new Set();
  try {
    const result = await supabase.from(table).select('id').eq('trip_id', tripID);
    if (result.error || !result.data) return new Set();
    return new Set(result.data.map((row) => String(row.id)));
  } catch {
    return new Set();
  }
}

function readTrip(value: string | undefined): Record<string, unknown> {
  if (!value) return {};
  try {
    const parsed: unknown = JSON.parse(value);
    if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed)) return {};
    const bound = (item: unknown, depth: number, key = ''): unknown => {
      if (typeof item === 'string') {
        const lowered = key.toLocaleLowerCase('de-DE');
        const limit = lowered.includes('note') ? 2_000 : lowered.includes('flight') ? 150 : lowered.includes('hotel') || lowered.includes('outbound') || lowered.includes('arrival') || lowered.includes('route') ? 300 : 500;
        return item.slice(0, limit);
      }
      if (typeof item === 'number' || typeof item === 'boolean' || item === null) return item;
      if (depth <= 0) return String(item).slice(0, 500);
      if (Array.isArray(item)) return item.slice(0, 20).map((child) => bound(child, depth - 1, key));
      if (typeof item === 'object') return Object.fromEntries(Object.entries(item as Record<string, unknown>).slice(0, 30).map(([childKey, child]) => [childKey, bound(child, depth - 1, childKey)]));
      return String(item).slice(0, 500);
    };
    return bound(parsed, 3) as Record<string, unknown>;
  } catch {
    return {};
  }
}

export interface AssistantContextResult {
  context: AssistantContext;
  fingerprintPlaces: Place[];
  tripFingerprint: string;
  albumID: string;
  tripID: string;
}

export async function buildAssistantContext(db: SQLiteDatabase, message: string, tripID: string | null): Promise<AssistantContextResult> {
  const settings = await db.getAllAsync<{ key: string; value: string }>('SELECT key,value FROM album_settings WHERE key IN (\'trip\',\'tripID\',\'albumID\')');
  const settingMap = Object.fromEntries(settings.map((setting) => [setting.key, setting.value]));
  const freshPlaces = await readPlaces(db);
  const shared = Boolean(tripID);
  const [placeIDs, documentIDs, collectionIDs, documentRows, collectionRows] = await Promise.all([
    shared ? remoteIDs('places', tripID as string) : Promise.resolve<Set<string> | null>(null),
    shared ? remoteIDs('documents', tripID as string) : Promise.resolve<Set<string> | null>(null),
    shared ? remoteIDs('collection_entries', tripID as string) : Promise.resolve<Set<string> | null>(null),
    db.getAllAsync<{ id: string; payload_json: string }>('SELECT id,payload_json FROM trip_documents ORDER BY updated_at DESC'),
    db.getAllAsync<{ id: string; payload_json: string }>('SELECT id,payload_json FROM collection_entries WHERE deleted = 0 ORDER BY updated_at DESC'),
  ]);
  const activePlaces = freshPlaces.filter((place) => !place.deleted && (!shared || placeIDs?.has(place.id))).slice(0, 150);
  const contextPlaces: AssistantContextPlace[] = activePlaces.map((place) => ({
    id: place.id, title: place.title.slice(0, 180), note: place.note.slice(0, 500), category: place.category.slice(0, 100), address: (place.address ?? '').slice(0, 300),
    lat: typeof place.lat === 'number' ? place.lat : null, lng: typeof place.lng === 'number' ? place.lng : null,
    day: place.day, franked: place.franked, opening_hours: (place.openingHours ?? '').slice(0, 400),
  }));

  const documents = documentRows.flatMap((row) => {
    if (shared && !documentIDs?.has(row.id)) return [];
    try {
      const payload = JSON.parse(row.payload_json) as DocumentPayload;
      const text = typeof payload.extractedText === 'string' ? payload.extractedText : (typeof payload.text === 'string' ? payload.text : '');
      const name = typeof payload.name === 'string' ? payload.name : row.id;
      if (!documentIsRelevant(text, name, message)) return [];
      const excerpt = relevantDocumentExcerpt(text, message);
      return excerpt ? [{ id: row.id, name: name.slice(0, 500), text: excerpt.slice(0, 1_500) }] : [];
    } catch { return []; }
  }).slice(0, 5);
  const collection = collectionRows.flatMap((row) => {
    if (shared && !collectionIDs?.has(row.id)) return [];
    try {
      const payload = JSON.parse(row.payload_json) as CollectionPayload;
      const text = [payload.text, payload.caption, payload.displayTitle].find((value) => typeof value === 'string' && value.trim()) ?? '';
      if (!text) return [];
      const url = typeof payload.url === 'string' ? payload.url : (typeof payload.canonicalURL === 'string' ? payload.canonicalURL : null);
      return [{ id: row.id, text: text.slice(0, 700), url: url?.slice(0, 1_000) ?? null }];
    } catch { return []; }
  }).slice(0, 100);
  const trip = readTrip(settingMap.trip);
  let context: AssistantContext = { trip, places: contextPlaces, documents, collection };
  while (utf8Bytes(context) > 40_000) {
    if (context.documents.length) context = { ...context, documents: context.documents.slice(0, -1) };
    else if (context.collection.length) context = { ...context, collection: context.collection.slice(0, -1) };
    else if (context.places.length) context = { ...context, places: context.places.slice(0, -1) };
    else break;
  }
  const ids = new Set(context.places.map((place) => place.id));
  return { context, fingerprintPlaces: activePlaces.filter((place) => ids.has(place.id)), tripFingerprint: settingMap.trip ?? '', albumID: settingMap.albumID ?? '', tripID: settingMap.tripID ?? '' };
}
