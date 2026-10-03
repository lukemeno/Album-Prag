import assert from 'node:assert/strict';
import { DatabaseSync } from 'node:sqlite';
import { registerHooks } from 'node:module';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

const root = new URL('../src/', import.meta.url);
const placeStoreStub = `export async function readPlaces(db) { const rows = await db.getAllAsync('SELECT * FROM places WHERE deleted = 0 ORDER BY title COLLATE NOCASE'); return rows.map((row) => ({ id: row.id, title: row.title, note: row.note ?? '', sourceURL: row.source_url ?? '', category: row.category ?? 'Idee', author: row.author ?? 'Wir', image: row.image_json ? JSON.parse(row.image_json) : null, address: row.address ?? '', lat: row.lat ?? undefined, lng: row.lng ?? undefined, franked: Boolean(row.franked), deferred: Boolean(row.deferred), deleted: Boolean(row.deleted), visited: Boolean(row.visited), day: row.day ?? null, dayOrder: row.day_order ?? null, approvals: [], passedBy: [], openingHours: row.opening_hours ?? null, gallery: null, updatedAt: row.updated_at ?? 0 })); }`;
registerHooks({
  resolve(specifier, context, next) {
    if (specifier === '@/storage/place-store') return { url: `data:text/javascript,${encodeURIComponent(placeStoreStub)}`, shortCircuit: true };
    if (specifier.startsWith('@/')) return { url: new URL(`${specifier.slice(2)}${specifier.endsWith('.json') ? '' : '.ts'}`, root).href, shortCircuit: true };
    return next(specifier, context);
  },
  load(url, context, next) {
    if (url.endsWith('.json')) return { format: 'module', source: `export default ${readFileSync(fileURLToPath(url), 'utf8')}`, shortCircuit: true };
    return next(url, context);
  },
});

const { migrateDatabase } = await import('../src/storage/database.ts');
const { planItinerary, dayWindows } = await import('../src/domain/itinerary.ts');
const { parseOpeningHours } = await import('../src/domain/opening-hours.ts');
const { applyItineraryPlan, undoItineraryPlan } = await import('../src/storage/itinerary-actions.ts');

function database() {
  const sqlite = new DatabaseSync(':memory:');
  const db = {
    execAsync: async (sql) => sqlite.exec(sql),
    getFirstAsync: async (sql, params = []) => sqlite.prepare(sql).get(...params) ?? null,
    getAllAsync: async (sql, params = []) => sqlite.prepare(sql).all(...params),
    runAsync: async (sql, params = []) => sqlite.prepare(sql).run(...params),
    withExclusiveTransactionAsync: async (operation) => {
      sqlite.exec('BEGIN IMMEDIATE');
      try { await operation(db); sqlite.exec('COMMIT'); } catch (error) { sqlite.exec('ROLLBACK'); throw error; }
    },
  };
  return { db, sqlite };
}

const { db, sqlite } = database();
await migrateDatabase(db);
await db.runAsync("INSERT INTO album_settings(key,value) VALUES ('albumID','itinerary-check'),('tripID','trip-check'),('trip',?)", [JSON.stringify({ id: 'trip-check', flights: [{ direction: 'outbound', arrival: '21:50' }, { direction: 'inbound', departure: '08:00' }] })]);
const places = [
  ['itinerary-a', 'Museum A', 'Sehenswert', 50.09, 14.42, 1, null, 0],
  ['itinerary-b', 'Cafe B', 'Essen & Trinken', 50.10, 14.43, 1, null, 0],
  ['itinerary-missing', 'Missing', 'Sehenswert', null, null, 1, null, 0],
];
for (const [id, title, category, lat, lng, franked, day, dayOrder] of places) {
  await db.runAsync('INSERT INTO places(id,title,category,lat,lng,franked,day,day_order,approvals_json,passed_by_json,updated_at) VALUES (?,?,?,?,?,?,?,? ,?, ?, ?)', [id, title, category, lat, lng, franked, day, dayOrder, '["Alex"]', '["Luke"]', 1000]);
}
const row = (id) => db.getFirstAsync('SELECT * FROM places WHERE id = ?', [id]);
const placeFor = (id) => { const source = places.find((item) => item[0] === id); return { id, title: source[1], note: '', sourceURL: '', category: source[2], author: 'Wir', image: null, address: '', lat: source[3] ?? undefined, lng: source[4] ?? undefined, franked: true, deferred: false, deleted: false, visited: false, day: source[6], dayOrder: source[7], approvals: ['Alex'], passedBy: ['Luke'], openingHours: null, gallery: null, updatedAt: 1000 }; };
const fingerprint = (item) => JSON.stringify({ id: item.id, title: item.title, category: item.category, address: item.address, lat: item.lat, lng: item.lng, franked: Boolean(item.franked), deleted: Boolean(item.deleted), day: item.day, dayOrder: item.day_order, openingHours: item.opening_hours, updatedAt: item.updated_at });
const snapshot = async () => {
  const rows = await db.getAllAsync('SELECT id,title,category,address,lat,lng,franked,deleted,day,day_order,opening_hours,updated_at FROM places WHERE deleted = 0 AND franked = 1');
  return { albumID: 'itinerary-check', tripID: 'trip-check', trip: (await db.getFirstAsync("SELECT value FROM album_settings WHERE key='trip'"))?.value ?? '', hotel: { latitude: 50.0875, longitude: 14.4213 }, flights: [], places: Object.fromEntries(rows.map((item) => [item.id, fingerprint(item)])) };
};
const proposal = (a = 4, b = 5) => ({ days: { 4: [{ place: placeFor('itinerary-a'), slot: 'vormittags', note: 'Öffnungszeiten unbekannt' }], 5: [{ place: placeFor('itinerary-b'), slot: 'vormittags', note: 'Öffnungszeiten unbekannt' }], 6: [], 7: [], 8: [], 9: [] }, windows: dayWindows([]), leftOver: [{ place: placeFor('itinerary-missing'), reason: 'missing_coordinates' }], hotel: { latitude: 50.0875, longitude: 14.4213 } });
const preview = async () => ({ proposal: proposal(), snapshot: await snapshot() });

// Pure algorithm checks: finite coordinates, overnight hours, unknown timeline, and clamped flight windows.
assert.equal(parseOpeningHours('Mo 22:00-02:00')?.isOpenAt(0, 23 * 60), true);
assert.equal(parseOpeningHours('this is not hours'), null);
const extreme = dayWindows([{ direction: 'outbound', arrival: '23:59' }, { direction: 'inbound', departure: '07:00' }]);
assert.equal(extreme[4].minutes, 0);
assert.equal(extreme[9].minutes, 0);
const algorithmPlaces = [placeFor('itinerary-a'), placeFor('itinerary-b'), placeFor('itinerary-missing')];
const algorithm = planItinerary(algorithmPlaces, { latitude: 50.0875, longitude: 14.4213 }, [], false);
assert.equal(algorithm.leftOver.some((item) => item.reason === 'missing_coordinates'), true);
assert.equal(Object.keys(algorithm.days).length, 6);

// Atomic rollback on invalid plans and duplicate place assignment.
const beforeA = await row('itinerary-a');
await assert.rejects(applyItineraryPlan(db, { ...(await preview()), proposal: { ...proposal(), days: { ...proposal().days, 4: [{ place: placeFor('itinerary-a'), slot: '', note: null }, { place: placeFor('itinerary-a'), slot: '', note: null }] } } }), /nicht mehr gültigen Ort/);
assert.equal((await row('itinerary-a')).day, beforeA.day);
assert.equal((await row('itinerary-a')).updated_at, beforeA.updated_at);
for (const invalidDay of [3, 4.5, 10]) {
  const invalid = await preview();
  invalid.proposal = { ...invalid.proposal, days: { ...invalid.proposal.days, [invalidDay]: [{ place: placeFor('itinerary-a'), slot: '', note: null }] } };
  await assert.rejects(applyItineraryPlan(db, invalid), /ungültigen Reisetag/);
  assert.equal((await row('itinerary-a')).day, beforeA.day);
}

// Apply preserves vote fields and makes a fresh no-op without bumping timestamps.
const applied = await applyItineraryPlan(db, await preview());
assert.deepEqual(applied.assignments.map((item) => item.id), ['itinerary-a', 'itinerary-b']);
assert.deepEqual(JSON.parse((await row('itinerary-a')).approvals_json), ['Alex']);
assert.deepEqual(JSON.parse((await row('itinerary-a')).passed_by_json), ['Luke']);
const noOpPreview = await preview();
const noOpUpdatedAt = (await row('itinerary-a')).updated_at;
const noOp = await applyItineraryPlan(db, noOpPreview);
assert.equal(noOp.assignments.length, 0);
assert.equal((await row('itinerary-a')).updated_at, noOpUpdatedAt);

// Roll back all changes when undo sees a conflicting stop.
await db.runAsync('UPDATE places SET day = 6, updated_at = updated_at + 1 WHERE id = ?', ['itinerary-a']);
await assert.rejects(undoItineraryPlan(db, applied), /geändert/);
assert.equal((await row('itinerary-b')).day, 5, 'conflicting undo must roll back the whole transaction');

// Stale edits, changed scope, and newly approved active IDs all reject before mutation.
const stale = await preview();
await db.runAsync('UPDATE places SET title = ?, updated_at = updated_at + 1 WHERE id = ?', ['Edited', 'itinerary-b']);
await assert.rejects(applyItineraryPlan(db, stale), /geändert/);
await db.runAsync('UPDATE places SET title = ?, updated_at = updated_at + 1 WHERE id = ?', ['Cafe B', 'itinerary-b']);
const scoped = await preview();
await db.runAsync("UPDATE album_settings SET value='different-trip' WHERE key='tripID'");
await assert.rejects(applyItineraryPlan(db, scoped), /Reise wurde geändert/);
await db.runAsync("UPDATE album_settings SET value='trip-check' WHERE key='tripID'");
const newlyApproved = await preview();
await db.runAsync("INSERT INTO places(id,title,category,lat,lng,franked,updated_at) VALUES ('itinerary-new','New','Sehenswert',50.11,14.44,1,1000)");
await assert.rejects(applyItineraryPlan(db, newlyApproved), /bestätigten Orte/);
await db.runAsync('DELETE FROM places WHERE id = ?', ['itinerary-new']);

// Undo scope conflict is also rejected.
const freshApplied = await applyItineraryPlan(db, await preview());
await db.runAsync("UPDATE album_settings SET value='other-album' WHERE key='albumID'");
await assert.rejects(undoItineraryPlan(db, freshApplied), /Reise wurde geändert/);
await db.runAsync("UPDATE album_settings SET value='itinerary-check' WHERE key='albumID'");

sqlite.close();
console.log('Itinerary checks passed: algorithm rules, overnight hours, clamped windows, atomic rollback, duplicate/invalid plans, stale edits, new approvals, scope conflicts, undo conflicts, vote preservation, and no-op timestamps.');
