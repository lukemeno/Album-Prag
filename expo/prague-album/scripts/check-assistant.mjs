import assert from 'node:assert/strict';
import { DatabaseSync } from 'node:sqlite';
import { registerHooks } from 'node:module';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

const root = new URL('../src/', import.meta.url);
registerHooks({
  resolve(specifier, context, next) {
    if (specifier === 'expo-crypto') return { url: 'data:text/javascript,export%20%7BrandomUUID%7D%20from%20%22node%3Acrypto%22', shortCircuit: true };
    if (specifier.startsWith('@/')) return { url: new URL(`${specifier.slice(2)}${specifier.endsWith('.json') ? '' : '.ts'}`, root).href, shortCircuit: true };
    return next(specifier, context);
  },
  load(url, context, next) {
    if (url.endsWith('.json')) return { format: 'module', source: `export default ${readFileSync(fileURLToPath(url), 'utf8')}`, shortCircuit: true };
    return next(url, context);
  },
});
const { migrateDatabase } = await import('../src/storage/database.ts');
const { applyAssistantPlan, undoAssistantPlan, saveAssistantSuggestion } = await import('../src/storage/assistant-actions.ts');
const { placeFingerprint, parseAssistantReply } = await import('../src/domain/assistant.ts');

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
assert.equal((await db.getAllAsync('SELECT id FROM places')).length, 78);
await migrateDatabase(db);
assert.equal((await db.getAllAsync('SELECT id FROM places')).length, 78);
await db.runAsync("INSERT INTO album_settings VALUES ('albumID','verification')");
for (const [id, lat, lng, approved] of [['test-a',50.1,14.4,1],['test-b',50.11,14.41,1],['test-c',null,null,1],['test-d',50.12,14.42,0]]) {
  await db.runAsync('INSERT INTO places(id,title,lat,lng,franked,updated_at) VALUES (?,?,?,?,?,?)', [id,id,lat,lng,approved,1000]);
}
const row = (id) => db.getFirstAsync('SELECT * FROM places WHERE id=?', [id]);
const snapshot = async () => {
  const rows = await db.getAllAsync("SELECT * FROM places WHERE id LIKE 'test-%'");
  return { albumID:'verification',tripID:'',trip:'',places:Object.fromEntries(rows.map(r=>[r.id,placeFingerprint({id:r.id,title:r.title,address:r.address,lat:r.lat,lng:r.lng,franked:!!r.franked,deleted:!!r.deleted,day:r.day,dayOrder:r.day_order,updatedAt:r.updated_at})])) };
};
const plan = [{day:4,place_ids:['test-a','test-b'],note:''}];
const undo = await applyAssistantPlan(db,plan,await snapshot());
assert.deepEqual(undo.assignments.map(a=>a.id),['test-a','test-b']);
assert.equal((await row('test-b')).day_order,1);
const unchanged = (await row('test-a')).updated_at;
assert.equal((await applyAssistantPlan(db,plan,await snapshot())).assignments.length,0);
assert.equal((await row('test-a')).updated_at,unchanged);
await undoAssistantPlan(db,undo);
assert.equal((await row('test-a')).day,null);
for (const invalid of [
  [{day:4.5,place_ids:['test-a'],note:''}],
  [{day:3,place_ids:['test-a'],note:''}],
  [{day:4,place_ids:['test-a'],note:''},{day:4,place_ids:['test-b'],note:''}],
  [{day:4,place_ids:['test-a','test-a'],note:''}],
  [{day:4,place_ids:['test-a','test-c'],note:''}],
  [{day:4,place_ids:['test-d'],note:''}],
  [{day:4,place_ids:['missing'],note:''}],
]) {
  await assert.rejects(applyAssistantPlan(db,invalid,await snapshot()));
  assert.equal((await row('test-a')).day,null,'Failed plan must leave all assignments unchanged');
}
const stale = await snapshot();
await db.runAsync('UPDATE places SET title=?,updated_at=? WHERE id=?',['New title',2000,'test-a']);
await assert.rejects(applyAssistantPlan(db,plan,stale),/geändert/);
const applied = await applyAssistantPlan(db,plan,await snapshot());
await db.runAsync('UPDATE places SET day=5,updated_at=updated_at+1 WHERE id=?',['test-a']);
await assert.rejects(undoAssistantPlan(db,applied),/geändert/);
assert.equal((await row('test-b')).day,4,'Undo conflicts must roll back every stop');
await db.runAsync("UPDATE album_settings SET value='different' WHERE key='albumID'");
await assert.rejects(undoAssistantPlan(db,applied),/Reise wurde geändert/);
await db.runAsync("UPDATE album_settings SET value='verification' WHERE key='albumID'");
const suggestion={existing_id:null,title:'Café Test',address:'Prag 1',query:'synthetic',source_url:'https://example.org/test'};
assert.equal(await saveAssistantSuggestion(db,suggestion,'Test'),'added');
assert.equal(await saveAssistantSuggestion(db,{...suggestion,title:'Cafe Test'},'Test'),'existing');
const saved=await db.getFirstAsync('SELECT * FROM places WHERE title=?',['Café Test']);
assert.equal(saved.source_url,suggestion.source_url);
await db.runAsync("UPDATE places SET deleted=1,franked=1,visited=1,day=4,day_order=1,approvals_json='[\"Test\"]',passed_by_json='[\"Other\"]' WHERE id=?",[saved.id]);
assert.equal(await saveAssistantSuggestion(db,{...suggestion,existing_id:saved.id},'Test'),'reused');
const restored=await row(saved.id);
assert.equal(restored.franked,0);assert.equal(restored.visited,0);assert.equal(restored.day,null);
assert.equal(restored.approvals_json,'[]');assert.equal(restored.passed_by_json,'[]');
const reply=parseAssistantReply({answer:'Synthetic',sources:[{title:'Unsafe',url:'javascript:alert(1)',document_id:null,quote:null}],places:[],plan:[],preferences:[]});
assert.equal(reply.sources[0].url,null);
assert.throws(()=>parseAssistantReply({answer:'Incomplete'}));
const { invitationToken } = await import('../src/domain/invitation.ts');
const invite='synthetic_invitation_token_0123456789';
assert.equal(invitationToken(`  ${invite}  `),invite);
assert.equal(invitationToken(`album://join/${invite}`),invite);
assert.equal(invitationToken(`praguealbum://join/${invite}`),invite);
assert.throws(()=>invitationToken(`https://untrusted.example/${invite}`));
assert.throws(()=>invitationToken('invalid'));
const { recordVote, readVoteEvents } = await import('../src/storage/vote-store.ts');
await recordVote(db,'test-a','Alex',true);
await recordVote(db,'test-a','Luke',true);
assert.deepEqual(JSON.parse((await row('test-a')).approvals_json),['Alex','Luke']);
await recordVote(db,'test-a','Alex',null);
assert.deepEqual(JSON.parse((await row('test-a')).approvals_json),['Luke']);
assert.equal((await readVoteEvents(db,'test-a')).Alex.choice,'open');
await recordVote(db,'test-a','Luke',false);
assert.equal((await row('test-a')).franked,0);
assert.deepEqual(JSON.parse((await row('test-a')).passed_by_json),['Luke']);
const { legacyVoteEvents, mergeVoteEvents, voteLists } = await import('../src/domain/vote-events.ts');
const a={Alex:{choice:'approved',at:100}};
const b={Luke:{choice:'approved',at:101}};
const merged=mergeVoteEvents(a,b);
assert.deepEqual(voteLists(merged).approvals,['Alex','Luke']);
const withdrawn=mergeVoteEvents(merged,{Alex:{choice:'open',at:102}});
assert.deepEqual(voteLists(withdrawn).approvals,['Luke']);
assert.equal(mergeVoteEvents(withdrawn,a).Alex.choice,'open','Older approvals cannot restore a withdrawn vote');
const deferred=mergeVoteEvents(withdrawn,{Luke:{choice:'later',at:103}});
assert.deepEqual(voteLists(deferred),{approvals:[],passedBy:['Luke']});
assert.deepEqual(legacyVoteEvents(['Alex'],[],999,withdrawn),withdrawn,'Legacy arrays cannot overwrite explicit tombstones');
assert.deepEqual(mergeVoteEvents(a,b),mergeVoteEvents(b,a));
const tieA={Alex:{choice:'open',at:100}};
assert.deepEqual(mergeVoteEvents(a,tieA),mergeVoteEvents(tieA,a));
const { importAlbum, exportAlbum } = await import('../src/storage/album-transfer.ts');
const nativeTime = (ms) => (ms - 978307200000) / 1000;
const archive = { places: [], collectionEntries: [{id:'transfer-post',text:'original',updatedAt:nativeTime(5000)}],documents:[{id:'transfer-doc',name:'original',updatedAt:nativeTime(5000)}],trip:{hotel:'original',updatedAt:nativeTime(5000)} };
await importAlbum(db,archive);
await db.runAsync('UPDATE collection_entries SET payload_json=?,updated_at=6000 WHERE id=?',[JSON.stringify({...archive.collectionEntries[0],text:'newer'}),'transfer-post']);
await db.runAsync('UPDATE trip_documents SET payload_json=?,updated_at=6000 WHERE id=?',[JSON.stringify({...archive.documents[0],name:'newer'}),'transfer-doc']);
await db.runAsync("UPDATE album_settings SET value=? WHERE key='trip'",[JSON.stringify({hotel:'newer',updatedAt:nativeTime(6000)})]);
await importAlbum(db,archive);
assert.equal(JSON.parse((await db.getFirstAsync('SELECT payload_json FROM collection_entries WHERE id=?',['transfer-post'])).payload_json).text,'newer');
assert.equal(JSON.parse((await db.getFirstAsync('SELECT payload_json FROM trip_documents WHERE id=?',['transfer-doc'])).payload_json).name,'newer');
assert.equal(JSON.parse((await db.getFirstAsync("SELECT value FROM album_settings WHERE key='trip'")).value).hotel,'newer');
const exported=await exportAlbum(db);
assert.equal(exported.album.documents.length,1);
assert.equal(exported.album.collectionEntries.length,1);
const untouchedSeed = 'prague-planetum-program';
await db.runAsync('UPDATE places SET updated_at=0 WHERE id=?', [untouchedSeed]);
const legacySeed = {id: untouchedSeed, title:'Native legacy seed', note:'Original import', updatedAt:nativeTime(-5000)};
await importAlbum(db, {places:[legacySeed]});
assert.equal((await db.getFirstAsync('SELECT title FROM places WHERE id=?',[untouchedSeed])).title, legacySeed.title, 'Untouched seed must not block a legacy native date');
await db.runAsync('UPDATE places SET title=?,updated_at=7000 WHERE id=?', ['New local edit', untouchedSeed]);
await importAlbum(db, {places:[legacySeed]});
assert.equal((await db.getFirstAsync('SELECT title FROM places WHERE id=?',[untouchedSeed])).title,'New local edit');
await importAlbum(db, {places:[],collectionEntries:[{id:'transfer-deleted',text:'Archived',deleted:true,updatedAt:nativeTime(8000)}]});
assert.ok((await exportAlbum(db)).album.collectionEntries.some((entry) => entry.id==='transfer-deleted' && entry.deleted), 'Backups must retain collection tombstones');
sqlite.close();
console.log('Assistant checks passed: seed persistence, atomic plans, no-op, invalid/stale data, conflict-safe undo, suggestion dedupe/restore and reply validation.');
