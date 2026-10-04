import type { SQLiteDatabase } from 'expo-sqlite';
import type { Place } from '@/domain/place';

interface AlbumTransfer {
  format: 'prague-album';
  version: 1;
  exportedAt: string;
  album: {
    albumID?: string;
    places: Record<string, unknown>[];
    trip?: Record<string, unknown>;
    collaboration?: { tripID?: string; inviteToken?: string | null } | null;
    collectionEntries?: Record<string, unknown>[];
    documents?: Record<string, unknown>[];
  };
}

function placePayload(place: Place): Record<string, unknown> {
  return {
    id: place.id, title: place.title, note: place.note, sourceURL: place.sourceURL,
    category: place.category, author: place.author, image: place.image,
    address: place.address, lat: place.lat, lng: place.lng, franked: place.franked,
    deferred: place.deferred, deleted: place.deleted, visited: place.visited,
    day: place.day, dayOrder: place.dayOrder, approvals: place.approvals,
    passedBy: place.passedBy, openingHours: place.openingHours, gallery: place.gallery,
    updatedAt: (place.updatedAt - 978307200000) / 1000,
  };
}

export async function exportAlbum(db: SQLiteDatabase): Promise<AlbumTransfer> {
  const rows = await db.getAllAsync<Record<string, unknown>>('SELECT * FROM places ORDER BY title COLLATE NOCASE');
  const places: Place[] = rows.map((row) => ({
    id: String(row.id), title: String(row.title), note: String(row.note ?? ''), sourceURL: String(row.source_url ?? ''),
    category: String(row.category ?? 'Idee'), author: String(row.author ?? ''), image: row.image_json ? JSON.parse(String(row.image_json)) as Record<string, unknown> : null,
    address: String(row.address ?? ''), lat: typeof row.lat === 'number' ? row.lat : undefined, lng: typeof row.lng === 'number' ? row.lng : undefined,
    franked: Boolean(row.franked), deferred: Boolean(row.deferred), deleted: Boolean(row.deleted), visited: Boolean(row.visited), day: typeof row.day === 'number' ? row.day : null, dayOrder: typeof row.day_order === 'number' ? row.day_order : null,
    approvals: JSON.parse(String(row.approvals_json ?? '[]')) as string[], passedBy: JSON.parse(String(row.passed_by_json ?? '[]')) as string[], openingHours: typeof row.opening_hours === 'string' ? row.opening_hours : null,
    gallery: row.gallery_json ? JSON.parse(String(row.gallery_json)) as Record<string, unknown>[] : null, updatedAt: Number(row.updated_at),
  }));
  const settings = await db.getAllAsync<{ key: string; value: string }>('SELECT key,value FROM album_settings');
  const values = Object.fromEntries(settings.map(({ key, value }) => [key, value]));
  const collectionEntries = await db.getAllAsync<{ payload_json: string }>('SELECT payload_json FROM collection_entries WHERE deleted = 0');
  const documents = await db.getAllAsync<{ payload_json: string }>('SELECT payload_json FROM trip_documents');
  return {
    format: 'prague-album', version: 1, exportedAt: new Date().toISOString(),
    album: {
      albumID: values.albumID ?? 'expo-album', places: places.map(placePayload),
      trip: values.trip ? JSON.parse(values.trip) as Record<string, unknown> : undefined,
      collaboration: values.tripID ? { tripID: values.tripID, inviteToken: values.inviteToken ?? null } : null,
      collectionEntries: collectionEntries.map((entry) => JSON.parse(entry.payload_json) as Record<string, unknown>),
      documents: documents.map((entry) => JSON.parse(entry.payload_json) as Record<string, unknown>),
    },
  };
}

export async function importAlbum(db: SQLiteDatabase, input: unknown): Promise<number> {
  const transfer = input as AlbumTransfer;
  const album = transfer?.format === 'prague-album' && transfer.version === 1 ? transfer.album : input as AlbumTransfer['album'];
  if (!album || !Array.isArray(album.places)) throw new Error('Die Datei enthält keine gültige Album-Ideenliste.');
  let imported = 0;
  await db.withExclusiveTransactionAsync(async (transaction) => {
    for (const value of album.places) {
      if (!value || typeof value.title !== 'string') continue;
      const id = typeof value.id === 'string' ? value.id : `import-${Date.now()}-${imported}`;
      const updated = typeof value.updatedAt === 'number' ? Math.round(value.updatedAt * 1000 + 978307200000) : Date.now();
      const existing = await transaction.getFirstAsync<{ updated_at: number }>('SELECT updated_at FROM places WHERE id = ?', [id]);
      if (existing && existing.updated_at > updated) continue;
      await transaction.runAsync(
        `INSERT OR REPLACE INTO places (id,title,note,source_url,category,author,image_json,address,lat,lng,franked,deferred,deleted,visited,day,day_order,approvals_json,passed_by_json,opening_hours,gallery_json,updated_at)
         VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)`,
        [id, value.title, String(value.note ?? ''), String(value.sourceURL ?? ''), String(value.category ?? 'Idee'), String(value.author ?? ''), value.image ? JSON.stringify(value.image) : null, String(value.address ?? ''), typeof value.lat === 'number' ? value.lat : null, typeof value.lng === 'number' ? value.lng : null, Number(Boolean(value.franked)), Number(Boolean(value.deferred)), Number(Boolean(value.deleted)), Number(Boolean(value.visited)), typeof value.day === 'number' ? value.day : null, typeof value.dayOrder === 'number' ? value.dayOrder : null, JSON.stringify(value.approvals ?? []), JSON.stringify(value.passedBy ?? []), typeof value.openingHours === 'string' ? value.openingHours : null, value.gallery ? JSON.stringify(value.gallery) : null, updated],
      );
      imported += 1;
    }
    for (const entry of album.collectionEntries ?? []) {
      if (typeof entry.id !== 'string') continue;
      const updated = typeof entry.updatedAt === 'number' ? Math.round(entry.updatedAt * 1000 + 978307200000) : Date.now();
      await transaction.runAsync('INSERT OR REPLACE INTO collection_entries (id,payload_json,version,deleted,updated_at) VALUES (?,?,1,?,?)', [entry.id, JSON.stringify(entry), Number(Boolean(entry.deleted)), updated]);
    }
    for (const document of album.documents ?? []) {
      if (typeof document.id !== 'string') continue;
      const updated = typeof document.updatedAt === 'number' ? Math.round(document.updatedAt * 1000 + 978307200000) : Date.now();
      await transaction.runAsync('INSERT OR REPLACE INTO trip_documents (id,payload_json,updated_at) VALUES (?,?,?)', [document.id, JSON.stringify(document), updated]);
    }
    if (album.collaboration?.tripID) await transaction.runAsync("INSERT OR REPLACE INTO album_settings (key,value) VALUES ('tripID',?)", [album.collaboration.tripID]);
    if (album.collaboration?.inviteToken) await transaction.runAsync("INSERT OR REPLACE INTO album_settings (key,value) VALUES ('inviteToken',?)", [album.collaboration.inviteToken]);
    if (album.trip) await transaction.runAsync("INSERT OR REPLACE INTO album_settings (key,value) VALUES ('trip',?)", [JSON.stringify(album.trip)]);
    if (album.albumID) await transaction.runAsync("INSERT OR REPLACE INTO album_settings (key,value) VALUES ('albumID',?)", [album.albumID]);
  });
  return imported;
}
