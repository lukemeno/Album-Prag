import assert from 'node:assert/strict';
import { createHash, randomUUID } from 'node:crypto';
import { registerHooks } from 'node:module';
import { DatabaseSync } from 'node:sqlite';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

const root = new URL('../src/', import.meta.url);
const cryptoShim = `export const CryptoDigestAlgorithm={SHA256:'sha256'};export const randomUUID=()=>globalThis.__crypto.randomUUID();export const digestStringAsync=async(_algorithm,value)=>globalThis.__crypto.digest(value);`;
globalThis.__crypto = { randomUUID, digest: (value) => createHash('sha256').update(value).digest('hex') };
registerHooks({
  resolve(specifier, _context, next) {
    if (specifier === 'expo-crypto') return { url: `data:text/javascript,${encodeURIComponent(cryptoShim)}`, shortCircuit: true };
    if (specifier.startsWith('@/')) return { url: new URL(`${specifier.slice(2)}${specifier.endsWith('.json') ? '' : '.ts'}`, root).href, shortCircuit: true };
    return next(specifier);
  },
  load(url, context, next) {
    if (url.endsWith('.json')) return { format: 'module', source: `export default ${readFileSync(fileURLToPath(url), 'utf8')}`, shortCircuit: true };
    return next(url, context);
  },
});

const { migrateDatabase } = await import(new URL('storage/database.ts', root));
const store = await import(new URL('storage/collection-store.ts', root));
const { canonicalPostID } = await import(new URL('domain/collection.ts', root));
const sqlite = new DatabaseSync(':memory:');
const db = {
  execAsync: async (sql) => sqlite.exec(sql),
  getFirstAsync: async (sql, params = []) => sqlite.prepare(sql).get(...params) ?? null,
  getAllAsync: async (sql, params = []) => sqlite.prepare(sql).all(...params),
  runAsync: async (sql, params = []) => sqlite.prepare(sql).run(...params),
  withExclusiveTransactionAsync: async (operation) => {
    sqlite.exec('BEGIN');
    try { await operation(db); sqlite.exec('COMMIT'); } catch (error) { sqlite.exec('ROLLBACK'); throw error; }
  },
};
await migrateDatabase(db);

const authorA = await store.participantID(db);
assert.equal(await store.participantID(db), authorA, 'participant identity remains stable');
const authorB = await store.participantID(db, randomUUID());
const first = await store.addCollectionPost(db, { authorID: authorA, authorName: 'Alex', url: 'HTTPS://WWW.TikTok.com/@creator/video/123/?utm_source=share#fragment', note: 'Samstag?' });
const sameLink = await store.addCollectionPost(db, { authorID: authorB, authorName: 'Sam', url: 'https://tiktok.com/@creator/video/123', note: 'Gute Idee' });
assert.equal(first.id, sameLink.id, 'same TikTok clip canonicalizes to one post');
assert.equal((await store.readCollectionEntries(db)).filter((entry) => entry.kind === 'post').length, 1);
assert.equal((await store.readCollectionEntries(db)).filter((entry) => entry.kind === 'comment').length, 2, 'independent notes remain comments');
assert.equal(await canonicalPostID('https://www.tiktok.com/video/123'), first.id);
await assert.rejects(store.addCollectionPost(db, { authorID: authorA, authorName: 'Alex', url: 'javascript:alert(1)' }), /http/);

await store.addCollectionComment(db, { postID: first.id, authorID: authorA, authorName: 'Alex', text: 'Noch ein Kommentar' });
let entries = await store.readCollectionEntries(db);
assert.equal(entries.filter((entry) => entry.kind === 'comment').length, 3, 'comments persist in SQLite');

await store.toggleCollectionHeart(db, first.id, authorA, 'Alex');
await store.toggleCollectionHeart(db, first.id, authorB, 'Sam');
entries = await store.readCollectionEntries(db);
assert.equal(entries.filter((entry) => entry.kind === 'reaction' && entry.active).length, 2, 'separate stable identities can react');
const heartAID = entries.find((entry) => entry.kind === 'reaction' && entry.authorID === authorA).id;
await store.toggleCollectionHeart(db, first.id, authorA, 'Alex');
const inactiveA = (await store.readCollectionEntries(db, true)).find((entry) => entry.id === heartAID);
assert.equal(inactiveA.active, false, 'unlike persists as an active=false tombstone');
assert.equal(inactiveA.deleted, false);

await db.runAsync("INSERT INTO places (id,title,updated_at) VALUES ('place-1','Prager Burg',0)");
const link = await store.linkCollectionPlace(db, { postID: first.id, placeID: 'place-1', authorID: authorA, authorName: 'Alex' });
assert.equal(link.placeID, 'place-1');
assert.equal((await store.readCollectionEntries(db)).filter((entry) => entry.kind === 'placeLink').length, 1);
await store.unlinkCollectionPlace(db, first.id, 'place-1');
assert.equal((await store.readCollectionEntries(db)).filter((entry) => entry.kind === 'placeLink').length, 0, 'unlink is hidden locally');
assert.equal((await store.readCollectionEntries(db, true)).find((entry) => entry.kind === 'placeLink').deleted, true, 'unlink leaves a syncable tombstone');

await store.tombstoneCollectionEntry(db, first.id);
assert.equal((await store.readCollectionEntries(db)).some((entry) => entry.id === first.id), false, 'deleted post leaves visible reads');
assert.equal((await store.readCollectionEntries(db, true)).find((entry) => entry.id === first.id).deleted, true, 'post deletion leaves a syncable tombstone');
sqlite.close();
console.log('Collection checks passed: production store URL dedupe, offline persistence, stable participants, comment/heart actions, place-link tombstones, and post deletion.');
