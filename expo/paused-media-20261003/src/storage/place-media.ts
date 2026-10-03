import * as ImageManipulator from 'expo-image-manipulator';
import { SaveFormat } from 'expo-image-manipulator';
import { Directory, File, Paths } from 'expo-file-system';
import type { SQLiteDatabase } from 'expo-sqlite';
import type { Place } from '@/domain/place';
import { assetJSON, imageAsset, type ExternalPlaceImage, type PlaceImageAsset, type UploadedPlaceImage } from '@/domain/place-images';
import { createUUID } from '@/domain/assistant';
import { supabase } from '@/storage/supabase';

const MAX_BYTES = 5_000_000;
const folder = () => new Directory(Paths.document, 'place-images');

function localFile(id: string): File { return new File(folder(), `${id}.jpg`); }

export async function savePickedPhoto(db: SQLiteDatabase, placeID: string, sourceURI: string): Promise<UploadedPlaceImage> {
  const rendered = await ImageManipulator.ImageManipulator.manipulate(sourceURI).resize({ width: 1600 }).renderAsync();
  const result = await rendered.saveAsync({ format: SaveFormat.JPEG, compress: 0.8 });
  const source = new File(result.uri);
  const bytes = await source.bytes();
  if (bytes.byteLength > MAX_BYTES) throw new Error('Das Foto ist zu groß. Bitte wähle ein kleineres Bild.');
  const imageID = createUUID();
  const directory = folder();
  if (!directory.exists) directory.create({ intermediates: true });
  const destination = localFile(imageID);
  destination.create({ overwrite: true });
  destination.write(bytes);
  await db.runAsync('INSERT OR REPLACE INTO local_media (image_id,place_id,path,storage_path,updated_at) VALUES (?,?,?,?,?)', [imageID, placeID, destination.uri, null, Date.now()]);
  return { id: imageID, storagePath: null, pixelWidth: result.width, pixelHeight: result.height };
}

export async function localImageURI(db: SQLiteDatabase, imageID: string): Promise<string | null> {
  const row = await db.getFirstAsync<{ path: string }>('SELECT path FROM local_media WHERE image_id = ?', [imageID]);
  if (!row) return null;
  const file = new File(row.path);
  return file.exists ? file.uri : null;
}

export async function removeLocalImage(db: SQLiteDatabase, imageID: string): Promise<void> {
  const row = await db.getFirstAsync<{ path: string }>('SELECT path FROM local_media WHERE image_id = ?', [imageID]);
  if (row) { const file = new File(row.path); if (file.exists) file.delete(); }
  await db.runAsync('DELETE FROM local_media WHERE image_id = ?', [imageID]);
}

/** Uploads before a caller publishes the corresponding place JSON reference. */
export async function syncPlaceMedia(db: SQLiteDatabase, tripID: string): Promise<void> {
  if (!supabase) return;
  const rows = await db.getAllAsync<{ image_id: string; place_id: string; path: string; storage_path: string | null }>('SELECT image_id,place_id,path,storage_path FROM local_media');
  for (const row of rows) {
    const file = new File(row.path);
    if (!file.exists) continue;
    const storagePath = row.storage_path || `${tripID}/${row.place_id}/${row.image_id}.jpg`;
    if (!row.storage_path) {
      const upload = await supabase.storage.from('trip-images').upload(storagePath, await file.bytes(), { contentType: 'image/jpeg', upsert: true });
      if (upload.error) throw upload.error;
      await db.runAsync('UPDATE local_media SET storage_path = ?, updated_at = ? WHERE image_id = ?', [storagePath, Date.now(), row.image_id]);
    }
  }
}

export async function cacheRemotePlaceImage(db: SQLiteDatabase, imageID: string, placeID: string, storagePath: string): Promise<string | null> {
  if (!supabase) return null;
  const signed = await supabase.storage.from('trip-images').createSignedUrl(storagePath, 1_800);
  if (signed.error || !signed.data?.signedUrl) return null;
  const response = await fetch(signed.data.signedUrl);
  if (!response.ok) return null;
  const bytes = new Uint8Array(await response.arrayBuffer());
  if (bytes.byteLength > MAX_BYTES) return null;
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
export function externalImagePayload(image: ExternalPlaceImage): Record<string, unknown> { return { external: image }; }
