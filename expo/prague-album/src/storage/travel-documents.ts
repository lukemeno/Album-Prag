import * as DocumentPicker from 'expo-document-picker';
import * as Crypto from 'expo-crypto';
import { Directory, File, Paths } from 'expo-file-system';
import * as Sharing from 'expo-sharing';
import type { SQLiteDatabase } from 'expo-sqlite';
import { supabase } from '@/storage/supabase';
import type { TravelDocument } from '@/domain/trip';

const MAX_PDF_BYTES = 25_000_000;
const DOCUMENT_DIR = new Directory(Paths.document, 'travel-documents');
const DOWNLOAD_TIMEOUT_MS = 20_000;
export interface DocumentSyncScope { albumID: string | null; tripID: string; }
interface DocumentRow { id: string; payload_json: string; updated_at: number; }
interface FileRow { document_id: string; local_path: string; original_available: number; size: number; updated_at: number; }
function safeID(value: string): boolean { return /^[A-Za-z0-9][A-Za-z0-9_-]{0,119}$/u.test(value); }
function safeStoragePath(value: string | null | undefined, tripID: string, documentID: string): value is string { return Boolean(value) && value === `${tripID}/${documentID}.pdf` && safeID(tripID) && safeID(documentID); }
function decode(value: string): Record<string, unknown> { try { const parsed = JSON.parse(value) as unknown; return parsed && typeof parsed === 'object' && !Array.isArray(parsed) ? parsed as Record<string, unknown> : {}; } catch { return {}; } }
function asDocument(row: DocumentRow, file?: FileRow): TravelDocument { const payload = decode(row.payload_json); return { id: row.id, name: typeof payload.name === 'string' ? payload.name : row.id, filename: typeof payload.filename === 'string' ? payload.filename : `${row.id}.pdf`, extractedText: typeof payload.extractedText === 'string' ? payload.extractedText.slice(0, 100_000) : '', storagePath: typeof payload.storagePath === 'string' ? payload.storagePath : null, originalAvailable: Boolean(file?.original_available) && Boolean(file?.local_path), updatedAt: row.updated_at }; }
export async function ensureDocumentSchema(db: SQLiteDatabase): Promise<void> { await db.execAsync('CREATE TABLE IF NOT EXISTS document_files (document_id TEXT PRIMARY KEY NOT NULL, local_path TEXT NOT NULL DEFAULT \'\', original_available INTEGER NOT NULL DEFAULT 0, size INTEGER NOT NULL DEFAULT 0, updated_at INTEGER NOT NULL DEFAULT 0)'); }
async function assertDocumentScope(db: Pick<SQLiteDatabase, 'getFirstAsync'>, scope: DocumentSyncScope): Promise<void> { const [album, trip] = await Promise.all([db.getFirstAsync<{ value: string }>("SELECT value FROM album_settings WHERE key='albumID'"), db.getFirstAsync<{ value: string }>("SELECT value FROM album_settings WHERE key='tripID'")]); if ((album?.value ?? null) !== scope.albumID || (trip?.value ?? null) !== scope.tripID) throw new Error('Die Reise wurde während des Unterlagen-Abgleichs gewechselt.'); }
export async function readTravelDocuments(db: SQLiteDatabase): Promise<TravelDocument[]> { await ensureDocumentSchema(db); const rows = await db.getAllAsync<DocumentRow>('SELECT id,payload_json,updated_at FROM trip_documents ORDER BY updated_at DESC'); const files = await db.getAllAsync<FileRow>('SELECT * FROM document_files'); const byID = new Map(files.map((file) => [file.document_id, file])); return rows.map((row) => asDocument(row, byID.get(row.id))); }
async function persistDocument(db: SQLiteDatabase, document: TravelDocument, localPath: string | null, size: number, timestamp = document.updatedAt, scope?: DocumentSyncScope): Promise<void> { await ensureDocumentSchema(db); await db.withExclusiveTransactionAsync(async (transaction) => { if (scope) await assertDocumentScope(transaction, scope); const now = timestamp; const payload = { id: document.id, name: document.name, filename: document.filename, extractedText: document.extractedText.slice(0, 100_000), storagePath: document.storagePath }; const existing = await transaction.getFirstAsync<FileRow>('SELECT * FROM document_files WHERE document_id=?', [document.id]); const retainedPath = localPath ?? (existing?.local_path || null); const retainedSize = size || existing?.size || 0; await transaction.runAsync('INSERT OR REPLACE INTO trip_documents(id,payload_json,updated_at) VALUES(?,?,?)', [document.id, JSON.stringify(payload), now]); await transaction.runAsync('INSERT OR REPLACE INTO document_files(document_id,local_path,original_available,size,updated_at) VALUES(?,?,?,?,?)', [document.id, retainedPath ?? '', Number(Boolean(retainedPath)), retainedSize, now]); }); }
export async function importPDF(db: SQLiteDatabase, extractedText = '', existingID?: string): Promise<TravelDocument | null> { const result = await DocumentPicker.getDocumentAsync({ type: 'application/pdf', copyToCacheDirectory: true }); if (result.canceled || !result.assets?.[0]) return null; const asset = result.assets[0]; const source = new File(asset.uri); const info = source.info(); const size = info.size ?? asset.size ?? 0; if (size <= 0 || size > MAX_PDF_BYTES) throw new Error('Bitte ein PDF zwischen 1 Byte und 25 MB auswählen.'); const signature = (await source.bytes()).slice(0, 5); if (new TextDecoder().decode(signature) !== '%PDF-') throw new Error('Die Datei ist kein gültiges PDF.'); if (!DOCUMENT_DIR.exists) DOCUMENT_DIR.create({ intermediates: true }); const id = existingID && safeID(existingID) ? existingID : `doc-${Crypto.randomUUID()}`; const old = existingID ? await db.getFirstAsync<DocumentRow>('SELECT * FROM trip_documents WHERE id=?', [id]) : null; const oldPayload = old ? decode(old.payload_json) : {}; const destination = new File(DOCUMENT_DIR, `${id}.pdf`); await source.copy(destination); const document: TravelDocument = { id, name: typeof oldPayload.name === 'string' ? oldPayload.name : asset.name.replace(/\.pdf$/iu, '') || 'Reisedokument', filename: `${id}.pdf`, extractedText: extractedText || (typeof oldPayload.extractedText === 'string' ? oldPayload.extractedText : ''), storagePath: typeof oldPayload.storagePath === 'string' ? oldPayload.storagePath : null, originalAvailable: true, updatedAt: Date.now() }; await persistDocument(db, document, destination.uri, size); return document; }
export async function getLocalDocumentFile(db: SQLiteDatabase, id: string): Promise<File | null> { await ensureDocumentSchema(db); const row = await db.getFirstAsync<FileRow>('SELECT * FROM document_files WHERE document_id=?', [id]); if (!row?.local_path || !row.original_available) return null; const file = new File(row.local_path); return file.exists ? file : null; }
export async function updateExtractedText(db: SQLiteDatabase, id: string, text: string): Promise<void> { const row = await db.getFirstAsync<DocumentRow>('SELECT * FROM trip_documents WHERE id=?', [id]); if (!row) throw new Error('Dokument nicht gefunden.'); const payload = decode(row.payload_json); payload.extractedText = text.slice(0, 100_000); await db.runAsync('UPDATE trip_documents SET payload_json=?,updated_at=? WHERE id=? AND updated_at=?', [JSON.stringify(payload), Math.max(Date.now(), row.updated_at + 1), id, row.updated_at]); }
export async function shareDocument(db: SQLiteDatabase, id: string): Promise<void> { const file = await getLocalDocumentFile(db, id); if (!file) throw new Error('Das Original ist auf diesem Gerät nicht verfügbar.'); if (!(await Sharing.isAvailableAsync())) throw new Error('Teilen ist auf diesem Gerät nicht verfügbar.'); await Sharing.shareAsync(file.uri, { mimeType: 'application/pdf', dialogTitle: 'PDF teilen' }); }
interface RemoteDocumentRow { id: string; name: string | null; filename: string | null; extracted_text: string | null; storage_path: string | null; updated_at: string; }

async function downloadRemoteOriginal(row: RemoteDocumentRow, tripID: string): Promise<{ stagingPath: string | null; size: number }> {
  const storagePath = safeStoragePath(row.storage_path, tripID, String(row.id)) ? row.storage_path : null;
  if (!storagePath) return { stagingPath: null, size: 0 };
  const signed = await supabase!.storage.from('trip-files').createSignedUrl(storagePath, 1_800);
  if (signed.error || !signed.data?.signedUrl) return { stagingPath: null, size: 0 };
  if (!DOCUMENT_DIR.exists) DOCUMENT_DIR.create({ intermediates: true });
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), DOWNLOAD_TIMEOUT_MS);
  try {
    const response = await fetch(signed.data.signedUrl, { signal: controller.signal });
    if (!response.ok) throw new Error('Das synchronisierte PDF konnte nicht geladen werden.');
    const contentLength = Number(response.headers.get('content-length') ?? 0);
    if (contentLength > MAX_PDF_BYTES) throw new Error('Das synchronisierte PDF ist größer als 25 MB.');
    const reader = response.body?.getReader();
    let bytes: Uint8Array;
    if (reader) {
      const chunks: Uint8Array[] = []; let total = 0;
      while (true) { const next = await reader.read(); if (next.done) break; total += next.value.byteLength; if (total > MAX_PDF_BYTES) { await reader.cancel(); throw new Error('Das synchronisierte PDF ist größer als 25 MB.'); } chunks.push(next.value); }
      bytes = new Uint8Array(total); let offset = 0; for (const chunk of chunks) { bytes.set(chunk, offset); offset += chunk.byteLength; }
    } else bytes = new Uint8Array(await response.arrayBuffer());
    if (bytes.byteLength === 0 || bytes.byteLength > MAX_PDF_BYTES || new TextDecoder().decode(bytes.slice(0, 5)) !== '%PDF-') throw new Error('Das synchronisierte Dokument ist kein gültiges PDF.');
    const staging = new File(DOCUMENT_DIR, `.staging-${String(row.id)}-${Crypto.randomUUID()}.pdf`);
    staging.write(bytes);
    return { stagingPath: staging.uri, size: bytes.byteLength };
  } finally { clearTimeout(timeout); }
}

export async function syncTravelDocuments(db: SQLiteDatabase, tripID: string, albumID?: string | null): Promise<boolean> {
  if (!supabase || !safeID(tripID)) return false;
  await ensureDocumentSchema(db);
  const localAlbum = await db.getFirstAsync<{ value: string }>("SELECT value FROM album_settings WHERE key='albumID'");
  const scope: DocumentSyncScope = { albumID: albumID ?? localAlbum?.value ?? null, tripID };
  await assertDocumentScope(db, scope);
  const local = await readTravelDocuments(db);
  const remoteResult = await supabase.from('documents').select('id,name,filename,extracted_text,storage_path,updated_at').eq('trip_id', tripID);
  if (remoteResult.error) throw remoteResult.error;
  await assertDocumentScope(db, scope);
  const remote = new Map((remoteResult.data ?? []).map((row) => [String(row.id), row as RemoteDocumentRow]));

  for (const document of local) {
    await assertDocumentScope(db, scope);
    const existing = remote.get(document.id);
    const remoteTime = existing ? Date.parse(existing.updated_at) : 0;
    if (existing && Number.isFinite(remoteTime) && remoteTime >= document.updatedAt) continue;
    const file = await getLocalDocumentFile(db, document.id);
    let storagePath = safeStoragePath(document.storagePath, tripID, document.id) ? document.storagePath : null;
    if (!storagePath && existing?.storage_path && safeStoragePath(existing.storage_path, tripID, document.id)) storagePath = existing.storage_path;
    if (!storagePath && file) {
      const info = file.info();
      const size = info.size ?? 0;
      if (size <= 0 || size > MAX_PDF_BYTES) throw new Error('Lokales PDF ist ungültig oder größer als 25 MB.');
      const bytes = await file.bytes();
      if (bytes.byteLength !== size || new TextDecoder().decode(bytes.slice(0, 5)) !== '%PDF-') throw new Error('Lokales PDF ist ungültig.');
      storagePath = `${tripID}/${document.id}.pdf`;
      const upload = await supabase.storage.from('trip-files').upload(storagePath, bytes, { contentType: 'application/pdf', upsert: true });
      if (upload.error) throw upload.error;
      await assertDocumentScope(db, scope);
    }
    if (!storagePath && !existing) continue;
    const row = { trip_id: tripID, id: document.id, name: document.name, filename: document.filename, extracted_text: document.extractedText, storage_path: storagePath ?? '', updated_at: new Date(document.updatedAt).toISOString() };
    await assertDocumentScope(db, scope);
    const result = existing
      ? await supabase.from('documents').update(row).eq('trip_id', tripID).eq('id', document.id).eq('updated_at', existing.updated_at).select('id')
      : await supabase.from('documents').insert(row).select('id');
    if (result.error) throw result.error;
    if (result.data?.length !== 1) throw new Error('Ein Unterlagendokument wurde während des Abgleichs geändert. Bitte erneut synchronisieren.');
    await assertDocumentScope(db, scope);
    if (storagePath !== document.storagePath) {
      const payload = { id: document.id, name: document.name, filename: document.filename, extractedText: document.extractedText, storagePath };
      await db.withExclusiveTransactionAsync(async (transaction) => { await assertDocumentScope(transaction, scope); const current = await transaction.getFirstAsync<DocumentRow>('SELECT * FROM trip_documents WHERE id=?', [document.id]); if (current && current.updated_at === document.updatedAt) await transaction.runAsync('UPDATE trip_documents SET payload_json=?,updated_at=? WHERE id=? AND updated_at=?', [JSON.stringify(payload), Math.max(Date.now(), document.updatedAt + 1), document.id, document.updatedAt]); });
    }
  }

  await assertDocumentScope(db, scope);
  const fresh = await supabase.from('documents').select('id,name,filename,extracted_text,storage_path,updated_at').eq('trip_id', tripID);
  if (fresh.error) throw fresh.error;
  await assertDocumentScope(db, scope);
  const currentDocuments = new Map((await readTravelDocuments(db)).map((item) => [item.id, item]));
  for (const raw of fresh.data ?? []) {
    await assertDocumentScope(db, scope);
    const row = raw as RemoteDocumentRow;
    if (!safeID(String(row.id))) continue;
    const remoteUpdated = Date.parse(row.updated_at);
    const current = currentDocuments.get(row.id);
    if (current && Number.isFinite(remoteUpdated) && current.updatedAt > remoteUpdated) continue;
    const remotePath = safeStoragePath(row.storage_path, tripID, String(row.id)) ? row.storage_path : null;
    let stagingPath: string | null = null;
    let size = 0;
    if (!(current?.originalAvailable && current.storagePath === remotePath)) {
      const original = await downloadRemoteOriginal(row, tripID);
      stagingPath = original.stagingPath;
      size = original.size;
    }
    await assertDocumentScope(db, scope);
    const latest = (await readTravelDocuments(db)).find((item) => item.id === row.id);
    if (latest && Number.isFinite(remoteUpdated) && latest.updatedAt > remoteUpdated) { if (stagingPath) new File(stagingPath).delete(); continue; }
    let committedPath: string | null = null;
    if (stagingPath) { const staging = new File(stagingPath); const destination = new File(DOCUMENT_DIR, `${row.id}.pdf`); if (destination.exists) destination.delete(); await staging.move(destination); committedPath = destination.uri; }
    const document: TravelDocument = { id: String(row.id), name: String(row.name ?? row.id), filename: String(row.filename ?? `${row.id}.pdf`), extractedText: String(row.extracted_text ?? '').slice(0, 100_000), storagePath: remotePath, originalAvailable: Boolean(committedPath) || Boolean(latest?.originalAvailable && latest.storagePath === remotePath), updatedAt: Number.isFinite(remoteUpdated) ? remoteUpdated : Date.now() };
    await persistDocument(db, document, committedPath, size, document.updatedAt, scope);
  }
  await assertDocumentScope(db, scope);
  return true;
}
