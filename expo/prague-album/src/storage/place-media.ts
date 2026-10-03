import * as ImageManipulator from 'expo-image-manipulator';
import { SaveFormat } from 'expo-image-manipulator';
import { Directory, File, Paths } from 'expo-file-system';
import type { SQLiteDatabase } from 'expo-sqlite';
import type { Place } from '@/domain/place';
import { assetJSON, imageAsset, type ExternalPlaceImage, type PlaceImageAsset, type UploadedPlaceImage } from '@/domain/place-images';
import { createUUID } from '@/domain/assistant';
import { supabase } from '@/storage/supabase';

type PlacePhotoLocation = { title: string; category: string; address?: string | null; lat?: number | null; lng?: number | null };

const MAX_BYTES = 5_000_000;
const folder = () => new Directory(Paths.document, 'place-images');

function safePathSegment(value: string): boolean { return /^[A-Za-z0-9_-]{1,128}$/.test(value) && value !== '..' && value !== '.'; }
function safeStoragePath(value: string): boolean {
  const parts = value.split('/');
  if (parts.length < 3 || !parts.slice(0, -1).every((part) => safePathSegment(part))) return false;
  return /^[A-Za-z0-9_-]{1,128}\.jpg$/iu.test(parts[parts.length - 1]);
}
function localFile(id: string): File { if (!safePathSegment(id)) throw new Error('Ungültige Bild-ID.'); return new File(folder(), `${id}.jpg`); }

async function fetchBytesBounded(url: string): Promise<Uint8Array> {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 12_000);
  try {
    const response = await fetch(url, { signal: controller.signal });
    if (!response.ok) throw new Error('Bild konnte nicht geladen werden.');
    const length = Number(response.headers.get('content-length') ?? '');
    if (Number.isFinite(length) && length > MAX_BYTES) throw new Error('Das Bild ist zu groß.');
    const reader = response.body?.getReader();
    if (!reader) {
      const bytes = new Uint8Array(await response.arrayBuffer());
      if (bytes.byteLength > MAX_BYTES) throw new Error('Das Bild ist zu groß.');
      return bytes;
    }
    const chunks: Uint8Array[] = [];
    let total = 0;
    while (true) {
      const next = await reader.read();
      if (next.done) break;
      total += next.value.byteLength;
      if (total > MAX_BYTES) { await reader.cancel(); throw new Error('Das Bild ist zu groß.'); }
      chunks.push(next.value);
    }
    const bytes = new Uint8Array(total);
    let offset = 0;
    for (const chunk of chunks) { bytes.set(chunk, offset); offset += chunk.byteLength; }
    return bytes;
  } finally { clearTimeout(timeout); }
}

export async function savePickedPhoto(db: SQLiteDatabase, placeID: string, sourceURI: string): Promise<UploadedPlaceImage> {
  const original = await ImageManipulator.ImageManipulator.manipulate(sourceURI).renderAsync();
  const scale = Math.min(1, 1600 / Math.max(original.width, original.height));
  const context = ImageManipulator.ImageManipulator.manipulate(sourceURI);
  if (scale < 1) context.resize({ width: Math.max(1, Math.round(original.width * scale)), height: Math.max(1, Math.round(original.height * scale)) });
  const result = await (scale < 1 ? await context.renderAsync() : original).saveAsync({ format: SaveFormat.JPEG, compress: 0.8 });
  const source = new File(result.uri);
  const bytes = await source.bytes();
  if (bytes.byteLength > MAX_BYTES) throw new Error('Das Foto ist zu groß. Bitte wähle ein kleineres Bild.');
  const imageID = createUUID();
  const directory = folder();
  if (!directory.exists) directory.create({ intermediates: true });
  const destination = localFile(imageID);
  destination.create({ overwrite: true });
  destination.write(bytes);
  try {
    await db.runAsync('INSERT OR REPLACE INTO local_media (image_id,place_id,path,storage_path,updated_at) VALUES (?,?,?,?,?)', [imageID, placeID, destination.uri, null, Date.now()]);
  } catch (error) { destination.delete(); throw error; }
  return { id: imageID, storagePath: null, pixelWidth: result.width, pixelHeight: result.height };
}

export async function localImageURI(db: SQLiteDatabase, imageID: string): Promise<string | null> {
  const row = await db.getFirstAsync<{ path: string }>('SELECT path FROM local_media WHERE image_id = ?', [imageID]);
  if (!row || !safePathSegment(imageID)) return null;
  const file = new File(row.path);
  return file.exists ? file.uri : null;
}

export async function removeLocalImage(db: SQLiteDatabase, imageID: string): Promise<void> {
  const row = await db.getFirstAsync<{ path: string }>('SELECT path FROM local_media WHERE image_id = ?', [imageID]);
  if (row && safePathSegment(imageID)) { const file = new File(row.path); if (file.exists) file.delete(); }
  await db.runAsync('DELETE FROM local_media WHERE image_id = ?', [imageID]);
}

/** Uploads before a caller publishes the corresponding place JSON reference. */
export async function syncPlaceMedia(db: SQLiteDatabase, tripID: string): Promise<void> {
  const readScope = async (database: SQLiteDatabase) => {
    const settings = await database.getAllAsync<{ key: string; value: string }>("SELECT key,value FROM album_settings WHERE key IN ('tripID','albumID')");
    return Object.fromEntries(settings.map((setting) => [setting.key, setting.value]));
  };
  const initialScope = await readScope(db);
  const assertScope = async (database: SQLiteDatabase) => {
    const currentScope = await readScope(database);
    if (currentScope.tripID !== tripID || (currentScope.albumID ?? '') !== (initialScope.albumID ?? '')) throw new Error('Die Reise wurde während des Fotoabgleichs geändert. Bitte erneut synchronisieren.');
  };
  await assertScope(db);
  const rows = await db.getAllAsync<{ image_id: string; place_id: string; path: string; storage_path: string | null }>('SELECT image_id,place_id,path,storage_path FROM local_media');
  const placeRows = await db.getAllAsync<{ id: string; image_json: string | null }>('SELECT id,image_json FROM places WHERE deleted = 0');
  const referenced = new Map<string, { placeID: string; image: Record<string, unknown> }>();
  for (const row of placeRows) {
    try {
      const image = row.image_json ? JSON.parse(row.image_json) as Record<string, unknown> : null;
      const parsed = imageAsset(image);
      if (image && parsed && 'uploaded' in parsed && parsed.uploaded.id) referenced.set(parsed.uploaded.id, { placeID: row.id, image });
    } catch { /* malformed old media is ignored safely */ }
  }
  const localByID = new Map(rows.map((row) => [row.image_id, row]));
  for (const [imageID, reference] of referenced) {
    const parsed = imageAsset(reference.image);
    if (!parsed || !('uploaded' in parsed)) continue;
    if (!localByID.has(imageID) && !parsed.uploaded.storagePath) throw new Error('Ein eigenes Foto fehlt lokal und konnte nicht synchronisiert werden.');
  }
  if (!supabase) return;
  for (const row of rows) {
    await assertScope(db);
    const reference = referenced.get(row.image_id);
    if (!reference) continue;
    const referenceAsset = imageAsset(reference.image);
    if (!referenceAsset || !('uploaded' in referenceAsset)) continue;
    if (!safePathSegment(row.image_id) || row.place_id !== reference.placeID) throw new Error('Das Foto gehört nicht eindeutig zu diesem Ort.');
    const currentStoragePath = referenceAsset.uploaded.storagePath ?? null;
    const storagePath = row.storage_path || currentStoragePath || `${tripID}/${row.place_id}/${row.image_id}.jpg`;
    if (!safeStoragePath(storagePath) || !storagePath.startsWith(`${tripID}/${reference.placeID}/`)) throw new Error('Das Foto gehört zu einer anderen Reise.');
    const needsUpload = !row.storage_path && !currentStoragePath;
    const file = new File(row.path);
    if (needsUpload) {
      if (!file.exists) throw new Error('Ein eigenes Foto fehlt lokal und konnte nicht synchronisiert werden.');
      const upload = await supabase.storage.from('trip-images').upload(storagePath, await file.bytes(), { contentType: 'image/jpeg', upsert: true });
      if (upload.error) throw upload.error;
    }
    const needsPatch = !row.storage_path || currentStoragePath !== storagePath;
    if (needsPatch) {
      await db.withExclusiveTransactionAsync(async (transaction) => {
        await assertScope(transaction);
        const now = Date.now();
        await transaction.runAsync('UPDATE local_media SET storage_path = ?, updated_at = ? WHERE image_id = ?', [storagePath, now, row.image_id]);
        const current = await transaction.getFirstAsync<{ image_json: string | null; updated_at: number }>('SELECT image_json,updated_at FROM places WHERE id = ?', [reference.placeID]);
        let currentAsset: PlaceImageAsset | null = null;
        try { currentAsset = current?.image_json ? imageAsset(JSON.parse(current.image_json) as Record<string, unknown>) : null; } catch { currentAsset = null; }
        if (current && currentAsset && 'uploaded' in currentAsset && currentAsset.uploaded.id === row.image_id && currentAsset.uploaded.storagePath !== storagePath) {
          const placeUpdatedAt = Math.max(now, Number(current.updated_at) + 1);
          const nextImage = assetJSON({ uploaded: { ...currentAsset.uploaded, storagePath } });
          await transaction.runAsync('UPDATE places SET image_json = ?, updated_at = ? WHERE id = ?', [JSON.stringify(nextImage), placeUpdatedAt, reference.placeID]);
        }
      });
    }
  }
}

export async function cacheRemotePlaceImage(db: SQLiteDatabase, imageID: string, placeID: string, storagePath: string): Promise<string | null> {
  if (!supabase || !safePathSegment(imageID) || !safeStoragePath(storagePath)) return null;
  const signed = await supabase.storage.from('trip-images').createSignedUrl(storagePath, 1_800);
  if (signed.error || !signed.data?.signedUrl || !/^https?:\/\//iu.test(signed.data.signedUrl)) return null;
  let bytes: Uint8Array;
  try { bytes = await fetchBytesBounded(signed.data.signedUrl); } catch { return null; }
  const directory = folder();
  if (!directory.exists) directory.create({ intermediates: true });
  const destination = localFile(imageID);
  destination.create({ overwrite: true });
  destination.write(bytes);
  await db.runAsync('INSERT OR REPLACE INTO local_media (image_id,place_id,path,storage_path,updated_at) VALUES (?,?,?,?,?)', [imageID, placeID, destination.uri, storagePath, Date.now()]);
  return destination.uri;
}

export function uploadedImageFromPlace(place: Place): UploadedPlaceImage | null { const asset = imageAsset(place.image); return asset && 'uploaded' in asset ? asset.uploaded : null; }
export function imagePayload(asset: PlaceImageAsset | null): Record<string, unknown> | null { return assetJSON(asset); }
export function externalImagePayload(image: ExternalPlaceImage): Record<string, unknown> { return assetJSON({ external: image }) ?? {}; }

export interface PlacePhotoCandidate { image_url: string; source_url: string; credit: string; provider?: 'sourcePreview' | 'wikimedia' | 'tripadvisor' | 'legacy'; license_name?: string; license_url?: string; provider_place_id?: string; confidence?: 'verified' | 'suggested'; caption?: string; }
export interface PlacePhotoSearchResult { image: PlacePhotoCandidate | null; candidates: PlacePhotoCandidate[]; selection_version: number; }

export async function searchPlacePhotos(place: PlacePhotoLocation, signal?: AbortSignal): Promise<PlacePhotoSearchResult> {
  if (typeof place.lat !== 'number' || typeof place.lng !== 'number' || !Number.isFinite(place.lat) || !Number.isFinite(place.lng) || Math.abs(place.lat) > 90 || Math.abs(place.lng) > 180) throw new Error('Bitte zuerst einen Ort mit Koordinaten auswählen.');
  if (!supabase) throw new Error('Die Bildsuche ist offline nicht eingerichtet.');
  const { data: session } = await supabase.auth.getSession();
  if (!session.session) { const signedIn = await supabase.auth.signInAnonymously(); if (signedIn.error) throw new Error('Die Bildsuche konnte nicht angemeldet werden.'); }
  if (signal?.aborted) throw new Error('Bildsuche abgebrochen.');
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 20_000);
  const abort = () => controller.abort();
  signal?.addEventListener('abort', abort, { once: true });
  let result;
  try { result = await supabase.functions.invoke('place-photo', { signal: controller.signal, body: { selection_version: 3, title: place.title.slice(0, 180), latitude: place.lat, longitude: place.lng, category: place.category.slice(0, 100), address: (place.address ?? '').slice(0, 300) } }); }
  finally { clearTimeout(timeout); signal?.removeEventListener('abort', abort); }
  if (signal?.aborted) throw new Error('Bildsuche abgebrochen.');
  if (result.error) throw new Error('Die Bildsuche ist gerade nicht verfügbar.');
  const payload = result.data as Partial<PlacePhotoSearchResult>;
  const candidates = Array.isArray(payload.candidates) ? payload.candidates.filter((item): item is PlacePhotoCandidate => Boolean(item && typeof item.image_url === 'string' && typeof item.source_url === 'string')) : [];
  const image = payload.image && typeof payload.image.image_url === 'string' && typeof payload.image.source_url === 'string' ? payload.image as PlacePhotoCandidate : null;
  return { image, candidates, selection_version: typeof payload.selection_version === 'number' ? payload.selection_version : 0 };
}

export function candidateAsset(candidate: PlacePhotoCandidate, place: PlacePhotoLocation): PlaceImageAsset {
  return { external: { imageURL: candidate.image_url, sourceURL: candidate.source_url, credit: candidate.credit || 'Bildquelle', provider: candidate.provider ?? 'legacy', ranking: 3, licenseName: candidate.license_name, licenseURL: candidate.license_url, providerPlaceID: candidate.provider_place_id, userSelected: true, resolvedFor: typeof place.lat === 'number' && typeof place.lng === 'number' ? { title: place.title, latitude: place.lat, longitude: place.lng, category: place.category, address: place.address ?? '' } : undefined } };
}
