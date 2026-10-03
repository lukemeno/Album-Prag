import { readVoteEvents, writeVoteEvents } from '@/storage/vote-store';
import { legacyVoteEvents } from '@/domain/vote-events';
import type { SQLiteDatabase } from 'expo-sqlite';
import type { AssistantDay, AssistantSuggestion } from '@/domain/assistant';
import { createUUID, isHTTPURL, placeFingerprint } from '@/domain/assistant';

export interface AssistantRequestFingerprint {
  trip: string;
  albumID: string;
  tripID: string;
  places: Record<string, string>;
}

export interface AssistantUndoRecord {
  assignments: { id: string; day: number | null; day_order: number | null }[];
  applied: Record<string, string>;
  albumID: string;
  tripID: string;
}

export class AssistantActionError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'AssistantActionError';
  }
}

interface PlaceActionRow {
  id: string;
  title: string;
  address: string;
  lat: number | null;
  lng: number | null;
  franked: number;
  deleted: number;
  day: number | null;
  day_order: number | null;
  updated_at: number;
}

function rowFingerprint(row: PlaceActionRow): string {
  return placeFingerprint({ id: row.id, title: row.title, address: row.address, lat: row.lat ?? undefined, lng: row.lng ?? undefined, franked: Boolean(row.franked), deleted: Boolean(row.deleted), day: row.day, dayOrder: row.day_order, updatedAt: row.updated_at });
}

function normalized(value: string): string {
  return value.normalize('NFKD').replace(/[\u0300-\u036f]/gu, '').toLocaleLowerCase('de-DE').replace(/[^\p{L}\p{N}]+/gu, ' ').trim();
}

export async function saveAssistantSuggestion(db: SQLiteDatabase, suggestion: AssistantSuggestion, author: string): Promise<'added' | 'reused' | 'existing'> {
  const title = suggestion.title.trim();
  if (!title) throw new AssistantActionError('Der vorgeschlagene Ort hat keinen Namen.');
  const sourceURL = isHTTPURL(suggestion.source_url) ? suggestion.source_url : '';
  const rows = await db.getAllAsync<{ id: string; title: string; address: string; deleted: number }>('SELECT id,title,address,deleted FROM places');
  if (suggestion.existing_id) {
    const existing = rows.find((row) => row.id === suggestion.existing_id);
    if (existing) {
      if (existing.deleted) {
        const oldVotes = await db.getFirstAsync<{ approvals_json: string; passed_by_json: string; updated_at: number }>('SELECT approvals_json,passed_by_json,updated_at FROM places WHERE id = ?', [existing.id]);
        await db.runAsync("UPDATE places SET deleted = 0, franked = 0, deferred = 0, visited = 0, day = NULL, day_order = NULL, approvals_json = '[]', passed_by_json = '[]', updated_at = ? WHERE id = ?", [Date.now(), existing.id]);
        const voteRow = oldVotes;
        const events = legacyVoteEvents(voteRow ? JSON.parse(voteRow.approvals_json) : [], voteRow ? JSON.parse(voteRow.passed_by_json) : [], voteRow?.updated_at ?? 0, await readVoteEvents(db, existing.id));
        const at = Math.max(Date.now(), ...Object.values(events).map((event) => event.at + 1));
        await writeVoteEvents(db, existing.id, Object.fromEntries(Object.keys(events).map((name) => [name, { choice: 'open' as const, at }])));
        return 'reused';
      }
      return 'existing';
    }
  }
  const key = `${normalized(title)}|${normalized(suggestion.address)}`;
  const duplicate = rows.find((row) => !row.deleted && `${normalized(row.title)}|${normalized(row.address)}` === key);
  if (duplicate) return 'existing';
  const id = createUUID();
  const now = Date.now();
  await db.runAsync(
    `INSERT INTO places (id,title,note,source_url,category,author,address,franked,deferred,deleted,visited,approvals_json,passed_by_json,updated_at)
     VALUES (?,?,?,?,?,?,?,0,0,0,0,'[]','[]',?)`,
    [id, title, suggestion.query.trim(), sourceURL, 'Assistent', author.trim() || 'Ich', suggestion.address.trim(), now],
  );
  return 'added';
}

function validatePlan(plan: AssistantDay[], rows: PlaceActionRow[]): string[] {
  const active = new Map(rows.filter((row) => !row.deleted && row.franked).map((row) => [row.id, row]));
  const ids: string[] = [];
  const days = new Set<number>();
  for (const day of plan) {
    if (!Number.isInteger(day.day) || day.day < 4 || day.day > 9 || days.has(day.day)) throw new AssistantActionError('Der Plan enthält einen ungültigen oder doppelten Reisetag.');
    days.add(day.day);
    for (const id of day.place_ids) {
      if (ids.includes(id)) throw new AssistantActionError('Ein Ort ist im Plan doppelt eingeplant.');
      const place = active.get(id);
      if (!place) throw new AssistantActionError('Der Plan enthält einen nicht mehr aktiven oder nicht abgestimmten Ort.');
      if (place.lat === null || place.lng === null) throw new AssistantActionError('Der Plan enthält einen Ort ohne Kartenposition.');
      if ((place.lat !== null && (!Number.isFinite(place.lat) || place.lat < -90 || place.lat > 90)) || (place.lng !== null && (!Number.isFinite(place.lng) || place.lng < -180 || place.lng > 180))) throw new AssistantActionError('Der Plan enthält einen Ort mit ungültigen Koordinaten.');
      ids.push(id);
    }
  }
  if (!ids.length) throw new AssistantActionError('Der Plan enthält keine Orte.');
  return ids;
}

export async function applyAssistantPlan(db: SQLiteDatabase, plan: AssistantDay[], expected: AssistantRequestFingerprint): Promise<AssistantUndoRecord> {
  let result: AssistantUndoRecord | undefined;
  await db.withExclusiveTransactionAsync(async (transaction) => {
    const settings = await transaction.getAllAsync<{ key: string; value: string }>("SELECT key,value FROM album_settings WHERE key IN ('trip','albumID','tripID')");
    const values = Object.fromEntries(settings.map((row) => [row.key, row.value]));
    if ((values.trip ?? '') !== expected.trip || (values.albumID ?? '') !== expected.albumID || (values.tripID ?? '') !== expected.tripID) throw new AssistantActionError('Die Reise wurde geändert, seit diese Antwort angefragt wurde.');
    const ids = Object.keys(expected.places);
    if (!ids.length) throw new AssistantActionError('Für diese Antwort gibt es keinen überprüfbaren Ortskontext.');
    const rows = await transaction.getAllAsync<PlaceActionRow>('SELECT id,title,address,lat,lng,franked,deleted,day,day_order,updated_at FROM places WHERE id IN (' + ids.map(() => '?').join(',') + ')', ids);
    if (rows.length !== ids.length || rows.some((row) => rowFingerprint(row) !== expected.places[row.id])) throw new AssistantActionError('Die Reise wurde geändert, seit diese Antwort angefragt wurde.');
    const idsInPlan = validatePlan(plan, rows);
    const assignments = idsInPlan.map((id) => {
      const row = rows.find((item) => item.id === id);
      if (!row) throw new AssistantActionError('Der Plan enthält einen unbekannten Ort.');
      return { id, day: row.day, day_order: row.day_order };
    }).filter((assignment) => {
      const day = plan.find((item) => item.place_ids.includes(assignment.id));
      const index = day?.place_ids.indexOf(assignment.id) ?? -1;
      return assignment.day !== day?.day || assignment.day_order !== index;
    });
    const now = Date.now();
    for (const assignment of assignments) {
      const day = plan.find((item) => item.place_ids.includes(assignment.id));
      const index = day?.place_ids.indexOf(assignment.id) ?? 0;
      await transaction.runAsync('UPDATE places SET day = ?, day_order = ?, updated_at = ? WHERE id = ?', [day?.day ?? null, index, now + index, assignment.id]);
    }
    const changed = assignments.length ? await transaction.getAllAsync<PlaceActionRow>('SELECT id,title,address,lat,lng,franked,deleted,day,day_order,updated_at FROM places WHERE id IN (' + assignments.map(() => '?').join(',') + ')', assignments.map((item) => item.id)) : [];
    result = { assignments, applied: Object.fromEntries(changed.map((row) => [row.id, rowFingerprint(row)])), albumID: values.albumID ?? '', tripID: values.tripID ?? '' };
  });
  if (!result) throw new AssistantActionError('Der Tagesplan konnte nicht gespeichert werden.');
  return result;
}

export async function undoAssistantPlan(db: SQLiteDatabase, record: AssistantUndoRecord): Promise<void> {
  await db.withExclusiveTransactionAsync(async (transaction) => {
    const ids = Object.keys(record.applied);
    if (!ids.length) throw new AssistantActionError('Für diese Antwort gibt es keine Rücknahme.');
    const settings = await transaction.getAllAsync<{ key: string; value: string }>("SELECT key,value FROM album_settings WHERE key IN ('albumID','tripID')");
    const values = Object.fromEntries(settings.map((row) => [row.key, row.value]));
    if ((values.albumID ?? '') !== record.albumID || (values.tripID ?? '') !== record.tripID) throw new AssistantActionError('Die Reise wurde geändert, seit der Plan angewendet wurde.');
    const rows = await transaction.getAllAsync<PlaceActionRow>('SELECT id,title,address,lat,lng,franked,deleted,day,day_order,updated_at FROM places WHERE id IN (' + ids.map(() => '?').join(',') + ')', ids);
    if (rows.length !== ids.length || rows.some((row) => rowFingerprint(row) !== record.applied[row.id])) throw new AssistantActionError('Die betroffenen Orte wurden seit dem Anwenden geändert.');
    const now = Date.now();
    for (const assignment of record.assignments) await transaction.runAsync('UPDATE places SET day = ?, day_order = ?, updated_at = ? WHERE id = ?', [assignment.day, assignment.day_order, now, assignment.id]);
  });
}
