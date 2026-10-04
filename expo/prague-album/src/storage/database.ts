import type { SQLiteDatabase } from 'expo-sqlite';
import type { PlaceSeed } from '@/domain/place';
import pragueIdeas from '@/data/prague-ideas.json';

const seeds = pragueIdeas as PlaceSeed[];

export async function migrateDatabase(db: SQLiteDatabase): Promise<void> {
  await db.execAsync('PRAGMA journal_mode = WAL; PRAGMA foreign_keys = ON;');
  const version = await db.getFirstAsync<{ user_version: number }>('PRAGMA user_version');

  if ((version?.user_version ?? 0) < 1) {
    await db.withExclusiveTransactionAsync(async (transaction) => {
      await transaction.execAsync(`
        CREATE TABLE IF NOT EXISTS places (
          id TEXT PRIMARY KEY NOT NULL,
          title TEXT NOT NULL,
          note TEXT NOT NULL DEFAULT '',
          source_url TEXT NOT NULL DEFAULT '',
          category TEXT NOT NULL DEFAULT 'Idee',
          author TEXT NOT NULL DEFAULT 'Wir',
          image_json TEXT,
          address TEXT NOT NULL DEFAULT '',
          lat REAL,
          lng REAL,
          franked INTEGER NOT NULL DEFAULT 0,
          deferred INTEGER NOT NULL DEFAULT 0,
          deleted INTEGER NOT NULL DEFAULT 0,
          visited INTEGER NOT NULL DEFAULT 0,
          day INTEGER,
          day_order INTEGER,
          approvals_json TEXT NOT NULL DEFAULT '[]',
          passed_by_json TEXT NOT NULL DEFAULT '[]',
          opening_hours TEXT,
          gallery_json TEXT,
          updated_at INTEGER NOT NULL
        );
        CREATE INDEX IF NOT EXISTS places_status_idx ON places(deleted, franked, category, title);
        CREATE TABLE IF NOT EXISTS album_settings (
          key TEXT PRIMARY KEY NOT NULL,
          value TEXT NOT NULL
        );
        PRAGMA user_version = 1;
      `);
    });
  }

  if ((version?.user_version ?? 0) < 2) {
    await db.withExclusiveTransactionAsync(async (transaction) => {
      await transaction.execAsync(`
        CREATE TABLE IF NOT EXISTS collection_entries (
          id TEXT PRIMARY KEY NOT NULL,
          payload_json TEXT NOT NULL,
          version INTEGER NOT NULL DEFAULT 1,
          deleted INTEGER NOT NULL DEFAULT 0,
          updated_at INTEGER NOT NULL DEFAULT 0
        );
        CREATE TABLE IF NOT EXISTS trip_documents (
          id TEXT PRIMARY KEY NOT NULL,
          payload_json TEXT NOT NULL,
          updated_at INTEGER NOT NULL DEFAULT 0
        );
        PRAGMA user_version = 2;
      `);
    });
  }

  await db.withExclusiveTransactionAsync(async (transaction) => {
    for (const place of seeds) {
      await transaction.runAsync(
        `INSERT OR IGNORE INTO places (id, title, note, source_url, category, author, address, lat, lng, approvals_json, passed_by_json, updated_at)
         VALUES (?, ?, ?, ?, ?, 'Wir', ?, ?, ?, '[]', '[]', 0)`,
        [place.id, place.title, place.note, place.sourceURL, place.category, place.address ?? '', place.lat ?? null, place.lng ?? null],
      );
    }

    // Refresh only the untouched built-in ideas; preserve any traveler edits.
    for (const id of ['prague-planetum-program', 'prague-ghost-legends-tour']) {
      const place = seeds.find((seed) => seed.id === id);
      if (!place) continue;
      await transaction.runAsync(
        `UPDATE places SET title = ?, note = ?, source_url = ?, category = ?, address = ?, updated_at = ?
         WHERE id = ? AND updated_at = 0`,
        [place.title, place.note, place.sourceURL, place.category, place.address ?? '', Date.now(), id],
      );
    }
  });
}
