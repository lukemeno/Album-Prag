import assert from 'node:assert/strict';
import { DatabaseSync } from 'node:sqlite';
import { registerHooks } from 'node:module';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

const root = new URL('../src/', import.meta.url);
registerHooks({
  resolve(specifier, context, next) {
    if (specifier.startsWith('@/')) return { url: new URL(`${specifier.slice(2)}${specifier.endsWith('.json') ? '' : '.ts'}`, root).href, shortCircuit: true };
    return next(specifier, context);
  },
  load(url, context, next) {
    if (url.endsWith('.json')) return { format: 'module', source: `export default ${readFileSync(fileURLToPath(url), 'utf8')}`, shortCircuit: true };
    return next(url, context);
  },
});
const { migrateDatabase } = await import('../src/storage/database.ts');
const { googleWalkingURL, routeSegments, validCoordinate, sortNearby, OLD_TOWN } = await import('../src/domain/map-route.ts');
const { applyMapPlan, mapSnapshotMatchesPlaces, readMapPlaces, readMapSnapshot, setPlaceCoordinates } = await import('../src/storage/map-actions.ts');

function database() {
  const sqlite = new DatabaseSync(':memory:');
  const db = {
    execAsync: async (sql) => sqlite.exec(sql),
    getFirstAsync: async (sql, params = []) => sqlite.prepare(sql).get(...params) ?? null,
    getAllAsync: async (sql, params = []) => sqlite.prepare(sql).all(...params),
    runAsync: async (sql, params = []) => sqlite.prepare(sql).run(...params),
    withExclusiveTransactionAsync: async (operation) => { sqlite.exec('BEGIN IMMEDIATE'); try { await operation(db); sqlite.exec('COMMIT'); } catch (error) { sqlite.exec('ROLLBACK'); throw error; } },
  };
  return { db, sqlite };
}
const { db, sqlite } = database();
await migrateDatabase(db);
await db.runAsync("INSERT INTO album_settings(key,value) VALUES ('albumID','map-check'),('tripID','trip-check'),('trip','{}')");
for (let index = 0; index < 6; index += 1) {
  await db.runAsync('INSERT INTO places(id,title,category,address,lat,lng,franked,day,day_order,visited,approvals_json,passed_by_json,updated_at) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)', [`map-${index}`, `Stop ${index}`, 'Sehenswert', `Address ${index}`, 50.08 + index / 100, 14.42 + index / 100, 1, index < 3 ? 4 : 5, index < 3 ? index : index - 3, index === 0 ? 1 : 0, '["Alex"]', '["Luke"]', 1000]);
}
const row = (id) => db.getFirstAsync('SELECT * FROM places WHERE id=?', [id]);
assert.equal(validCoordinate({ lat: 50, lng: 14 })?.latitude, 50);
assert.equal(validCoordinate({ lat: Number.NaN, lng: 14 }), null);
assert.equal(validCoordinate({ latitude: 91, longitude: 14 }), null);
const routePlaces = Array.from({ length: 8 }, (_, index) => ({ id: `r-${index}`, title: `R${index}`, lat: 50 + index / 100, lng: 14 + index / 100 }));
const segments = routeSegments(routePlaces, OLD_TOWN);
assert.equal(segments.every((segment) => segment.length <= 5), true);
assert.deepEqual(segments.flatMap((segment) => segment).filter((point) => point.placeID).map((point) => point.placeID).filter((id, index, all) => all.indexOf(id) === index), routePlaces.map((place) => place.id));
assert.equal(segments.every((segment) => (new URL(googleWalkingURL(segment)).searchParams.get('waypoints')?.split('|').length ?? 0) <= 3), true);
const nearby = sortNearby([{ lat: 50.1, lng: 14.4, id: 'far' }, { lat: 50.0875, lng: 14.4213, id: 'near' }], OLD_TOWN);
assert.equal(nearby[0].id, 'near');

const snapshot = await readMapSnapshot(db);
assert.equal(mapSnapshotMatchesPlaces(snapshot, await readMapPlaces(db)), true);
const assignments = ['map-0', 'map-1', 'map-2', 'map-3', 'map-4', 'map-5'].map((id, index) => ({ id, day: index < 2 ? 4 : index < 5 ? 5 : null, dayOrder: index < 2 ? index : index < 5 ? index - 2 : null }));
assert.equal(await applyMapPlan(db, snapshot, assignments), 4);
assert.equal((await row('map-0')).visited, 1);
assert.deepEqual(JSON.parse((await row('map-0')).approvals_json), ['Alex']);
assert.deepEqual(JSON.parse((await row('map-0')).passed_by_json), ['Luke']);
const noOpSnapshot = await readMapSnapshot(db);
assert.equal(await applyMapPlan(db, noOpSnapshot, assignments), 0);
const beforeInvalid = await row('map-0');
await assert.rejects(applyMapPlan(db, noOpSnapshot, assignments.map((item) => item.id === 'map-1' ? { ...item, dayOrder: 3 } : item)), /lückenlos/);
assert.equal((await row('map-0')).updated_at, beforeInvalid.updated_at);
const stale = await readMapSnapshot(db);
await db.runAsync('UPDATE places SET title=?,updated_at=updated_at+1 WHERE id=?', ['Changed', 'map-0']);
await assert.rejects(applyMapPlan(db, stale, assignments), /geändert/);
await db.runAsync('UPDATE places SET title=?,updated_at=updated_at+1 WHERE id=?', ['Stop 0', 'map-0']);
const scoped = await readMapSnapshot(db);
await db.runAsync("UPDATE album_settings SET value='different' WHERE key='tripID'");
await assert.rejects(applyMapPlan(db, scoped, assignments), /Reise wurde geändert/);
await db.runAsync("UPDATE album_settings SET value='trip-check' WHERE key='tripID'");
const coordinateSnapshot = await readMapSnapshot(db);
await assert.rejects(setPlaceCoordinates(db, coordinateSnapshot, 'map-0', { latitude: 100, longitude: 14 }), /ungültig/);
await setPlaceCoordinates(db, coordinateSnapshot, 'map-0', { latitude: 50.081, longitude: 14.421 });
assert.equal((await row('map-0')).lat, 50.081);
await db.runAsync('UPDATE places SET image_json=?,gallery_json=?,opening_hours=?,updated_at=updated_at+1 WHERE id=?', [JSON.stringify({ external: { _0: { imageURL: 'https://example.org/auto.jpg', sourceURL: 'https://example.org', credit: 'auto', provider: 'legacy', userSelected: false } } }), '[{"auto":true}]', 'Mo-Fr 09:00-18:00', 'map-0']);
const autoImageSnapshot = await readMapSnapshot(db);
await setPlaceCoordinates(db, autoImageSnapshot, 'map-0', { latitude: 50.082, longitude: 14.422 });
assert.equal((await row('map-0')).image_json, null);
assert.equal((await row('map-0')).gallery_json, null);
assert.equal((await row('map-0')).opening_hours, null);
await db.runAsync('UPDATE places SET image_json=?,gallery_json=?,opening_hours=?,updated_at=updated_at+1 WHERE id=?', [JSON.stringify({ external: { _0: { imageURL: 'https://example.org/user.jpg', sourceURL: 'https://example.org', credit: 'user', provider: 'legacy', userSelected: true } } }), '[{"auto":true}]', '24/7', 'map-0']);
const userImageSnapshot = await readMapSnapshot(db);
await setPlaceCoordinates(db, userImageSnapshot, 'map-0', { latitude: 50.083, longitude: 14.423 });
assert.notEqual((await row('map-0')).image_json, null);
assert.equal((await row('map-0')).gallery_json, null);
assert.equal((await row('map-0')).opening_hours, null);
const newApproved = await readMapSnapshot(db);
await db.runAsync("INSERT INTO places(id,title,category,lat,lng,franked,updated_at) VALUES ('map-new','New','Sehenswert',50,14,1,1000)");
await assert.rejects(applyMapPlan(db, newApproved, assignments), /geändert|vollständig/);
assert.equal((await row('map-1')).day, 4);
sqlite.close();
console.log('Map checks passed: coordinate guards, complete route stages, Google Maps waypoint limits, nearby sorting, atomic order/remove/reassign, vote preservation, no-op, stale/scope/rollback checks.');
