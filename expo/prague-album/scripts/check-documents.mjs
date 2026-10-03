import assert from 'node:assert/strict';
import { DatabaseSync } from 'node:sqlite';
import { registerHooks } from 'node:module';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

const root = new URL('../src/', import.meta.url);
registerHooks({ resolve(specifier, context, next) { if (specifier.startsWith('@/')) return { url: new URL(`${specifier.slice(2)}${specifier.endsWith('.json') ? '' : '.ts'}`, root).href, shortCircuit: true }; return next(specifier, context); }, load(url, context, next) { if (url.endsWith('.json')) return { format: 'module', source: `export default ${readFileSync(fileURLToPath(url), 'utf8')}`, shortCircuit: true }; return next(url, context); } });
const { normalizeTripText, parseTripDocument } = await import('../src/domain/trip-document-parser.ts');
const { emptyTrip, applyTripFields } = await import('../src/domain/trip.ts');
const sqlite = new DatabaseSync(':memory:');
const db = { execAsync: async (sql) => sqlite.exec(sql), getFirstAsync: async (sql, params = []) => sqlite.prepare(sql).get(...params) ?? null, getAllAsync: async (sql, params = []) => sqlite.prepare(sql).all(...params), runAsync: async (sql, params = []) => sqlite.prepare(sql).run(...params), withExclusiveTransactionAsync: async (operation) => { sqlite.exec('BEGIN IMMEDIATE'); try { await operation(db); sqlite.exec('COMMIT'); } catch (error) { sqlite.exec('ROLLBACK'); throw error; } } };

assert.equal(normalizeTripText('04/10/2026 - 15:5 5'), '04/10/2026 - 15:55');
const parsed = parseTripDocument(`Herr MUSTERMANN Max\nEW 1234\n04/10/2026 - 15:55\n04/10/2026 - 17:05\nHotel Urban Crème\nCheck-in: 15:00\nTourismusabgabe 2 EUR`);
assert.equal(parsed.flights[0]?.number, 'EW1234');
assert.equal(parsed.flights[0]?.departure, '15:55');
assert.equal(parsed.hotelDetails.name, 'Hotel Urban Crème');
assert.equal(parsed.hotelDetails.checkIn, '15:00');
assert.ok(parsed.notes.length > 0);
const nextTrip = applyTripFields(emptyTrip(), { bookingNumber: 'ABC123' });
assert.equal(nextTrip.bookingNumber, 'ABC123');
assert.ok(nextTrip.updatedAt > 0);

await db.execAsync(`CREATE TABLE trip_documents(id TEXT PRIMARY KEY NOT NULL,payload_json TEXT NOT NULL,updated_at INTEGER NOT NULL DEFAULT 0); CREATE TABLE document_files(document_id TEXT PRIMARY KEY NOT NULL,local_path TEXT NOT NULL DEFAULT '',original_available INTEGER NOT NULL DEFAULT 0,size INTEGER NOT NULL DEFAULT 0,updated_at INTEGER NOT NULL DEFAULT 0);`);
await db.runAsync('INSERT INTO trip_documents VALUES (?,?,?)', ['legacy', JSON.stringify({ id: 'legacy', name: 'Alte Buchung', extractedText: 'Nur Text vorhanden' }), 100]);
const legacy = await db.getFirstAsync('SELECT * FROM trip_documents WHERE id=?', ['legacy']);
assert.equal(JSON.parse(legacy.payload_json).extractedText, 'Nur Text vorhanden');
assert.equal((await db.getFirstAsync('SELECT * FROM document_files WHERE document_id=?', ['legacy'])), null, 'legacy metadata must not pretend an original exists');

// Compare-and-swap protects text edits from overwriting a newer local import.
await db.runAsync('UPDATE trip_documents SET payload_json=?,updated_at=? WHERE id=? AND updated_at=?', [JSON.stringify({ id: 'legacy', extractedText: 'neu' }), 200, 'legacy', 100]);
const lost = await db.runAsync('UPDATE trip_documents SET payload_json=?,updated_at=? WHERE id=? AND updated_at=?', [JSON.stringify({ id: 'legacy', extractedText: 'veraltet' }), 201, 'legacy', 100]);
assert.equal(lost.changes, 0);
assert.equal(JSON.parse((await db.getFirstAsync('SELECT payload_json FROM trip_documents WHERE id=?', ['legacy'])).payload_json).extractedText, 'neu');
sqlite.close();
console.log('Document checks passed: native-style parser normalization, flight/hotel extraction, metadata-only legacy records, and SQLite compare-and-swap protection.');
