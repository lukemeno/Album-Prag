import * as Crypto from 'expo-crypto';
import type { SQLiteDatabase } from 'expo-sqlite';
import {
  canonicalPostID,
  canonicalizeCollectionURL,
  decodeCollectionEntry,
  neutralCollectionTitle,
  newUUID,
  nowSeconds,
  placeLinkID,
  reactionID,
  type CollectionEntry,
  type CollectionMetadataState,
  type CollectionSyncMetadata,
} from '@/domain/collection';

interface CollectionRow { id: string; payload_json: string; version: number; deleted: number; updated_at: number; }
const participantKey = 'collection:participantID';
const syncKey = (id: string) => `collection:sync:${id}`;
const dirtyKey = (id: string) => `dirty:collection:${id}`;

function parseRow(row: CollectionRow): CollectionEntry | null {
  try { return decodeCollectionEntry(JSON.parse(row.payload_json)); } catch { return null; }
}

function encode(entry: CollectionEntry): string { return JSON.stringify(entry); }

export async function participantID(db: SQLiteDatabase, override?: string): Promise<string> {
  if (override?.trim()) return override.trim();
  const saved = await db.getFirstAsync<{ value: string }>('SELECT value FROM album_settings WHERE key=?', [participantKey]);
  if (saved?.value && /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/iu.test(saved.value)) return saved.value;
  const created = newUUID();
  await db.runAsync('INSERT OR REPLACE INTO album_settings (key,value) VALUES (?,?)', [participantKey, created]);
  return created;
}

export async function readCollectionEntries(db: SQLiteDatabase, includeDeleted = false): Promise<CollectionEntry[]> {
  const rows = await db.getAllAsync<CollectionRow>(includeDeleted ? 'SELECT * FROM collection_entries ORDER BY updated_at DESC' : 'SELECT * FROM collection_entries WHERE deleted=0 ORDER BY updated_at DESC');
  return rows.flatMap((row) => { const entry = parseRow(row); return entry ? [entry] : []; });
}

export async function readCollectionSync(db: SQLiteDatabase, id: string): Promise<CollectionSyncMetadata | null> {
  const row = await db.getFirstAsync<{ value: string }>('SELECT value FROM album_settings WHERE key=?', [syncKey(id)]);
  if (!row) return null;
  try {
    const parsed = JSON.parse(row.value) as Partial<CollectionSyncMetadata>;
    return typeof parsed.mutationToken === 'string' ? { serverVersion: typeof parsed.serverVersion === 'number' ? parsed.serverVersion : null, mutationToken: parsed.mutationToken, lastErrorCode: typeof parsed.lastErrorCode === 'string' ? parsed.lastErrorCode : undefined } : null;
  } catch { return null; }
}

async function writeLocalEntry(db: SQLiteDatabase, entry: CollectionEntry, options: { expectedUpdatedAt?: number; serverVersion?: number | null } = {}): Promise<CollectionEntry> {
  const mutationToken = newUUID();
  const saved = { ...entry, updatedAt: nowSeconds() };
  await db.withExclusiveTransactionAsync(async (transaction) => {
    const current = await transaction.getFirstAsync<CollectionRow>('SELECT * FROM collection_entries WHERE id=?', [saved.id]);
    if (options.expectedUpdatedAt !== undefined && (!current || current.updated_at !== options.expectedUpdatedAt)) throw new Error('Dieser Sammlungseintrag wurde inzwischen geändert.');
    const updatedAt = Math.max(Date.now(), (current?.updated_at ?? 0) + 1);
    const version = current?.version ?? 1;
    await transaction.runAsync('INSERT OR REPLACE INTO collection_entries (id,payload_json,version,deleted,updated_at) VALUES (?,?,?,?,?)', [saved.id, encode(saved), version, Number(saved.deleted), updatedAt]);
    await transaction.runAsync('INSERT OR REPLACE INTO album_settings (key,value) VALUES (?,?)', [syncKey(saved.id), JSON.stringify({ serverVersion: options.serverVersion ?? current?.version ?? null, mutationToken })]);
    await transaction.runAsync('INSERT OR REPLACE INTO album_settings (key,value) VALUES (?,?)', [dirtyKey(saved.id), mutationToken]);
    // Keep updated_at monotonic even when two mutations share a millisecond.
    await transaction.runAsync('UPDATE collection_entries SET updated_at=? WHERE id=?', [updatedAt, saved.id]);
  });
  return saved;
}

export async function addCollectionPost(db: SQLiteDatabase, input: { authorID: string; authorName: string; text?: string; url?: string; note?: string; deterministicID?: string }): Promise<CollectionEntry> {
  const text = input.text?.trim() ?? '';
  const note = input.note?.trim() ?? '';
  const rawURL = input.url?.trim() || (/^https?:\/\//iu.test(text) ? text : '');
  const canonical = rawURL ? canonicalizeCollectionURL(rawURL) : null;
  if (rawURL && !canonical) throw new Error('Der Link muss mit http:// oder https:// beginnen.');
  if (!text && !canonical) throw new Error('Bitte eine Nachricht oder einen Link eingeben.');
  const id = canonical ? await canonicalPostID(canonical) : `post-text-${input.deterministicID ?? newUUID()}`;
  const existing = (await readCollectionEntries(db, true)).find((entry) => entry.id === id);
  if (existing && !existing.deleted) {
    if (note) await addCollectionComment(db, { postID: id, authorID: input.authorID, authorName: input.authorName, text: note });
    return existing;
  }
  const createdAt = nowSeconds();
  const post: CollectionEntry = { id, kind: 'post', authorID: input.authorID, authorName: input.authorName, createdAt, updatedAt: createdAt, text: canonical ? undefined : text, url: canonical ?? undefined, canonicalURL: canonical ?? undefined, displayTitle: canonical ? neutralCollectionTitle(canonical) : undefined, metadataState: canonical ? 'pending' : undefined, deleted: false };
  await writeLocalEntry(db, post);
  if (note) await addCollectionComment(db, { postID: id, authorID: input.authorID, authorName: input.authorName, text: note });
  return post;
}

export async function addCollectionComment(db: SQLiteDatabase, input: { postID: string; authorID: string; authorName: string; text: string; deterministicID?: string }): Promise<CollectionEntry> {
  const text = input.text.trim();
  if (!text) throw new Error('Bitte einen Kommentar eingeben.');
  const post = (await readCollectionEntries(db)).find((entry) => entry.id === input.postID && entry.kind === 'post');
  if (!post) throw new Error('Dieser Beitrag ist nicht mehr verfügbar.');
  const createdAt = nowSeconds();
  const comment: CollectionEntry = { id: input.deterministicID ?? newUUID(), kind: 'comment', postID: input.postID, authorID: input.authorID, authorName: input.authorName, createdAt, updatedAt: createdAt, text, deleted: false };
  await writeLocalEntry(db, comment);
  return comment;
}

export async function toggleCollectionHeart(db: SQLiteDatabase, postID: string, authorID: string, authorName: string): Promise<CollectionEntry> {
  const post = (await readCollectionEntries(db)).find((entry) => entry.id === postID && entry.kind === 'post');
  if (!post) throw new Error('Dieser Beitrag ist nicht mehr verfügbar.');
  const id = await reactionID(postID, authorID);
  const current = (await readCollectionEntries(db, true)).find((entry) => entry.id === id);
  const createdAt = current?.createdAt ?? nowSeconds();
  const reaction: CollectionEntry = { id, kind: 'reaction', postID, authorID, authorName, createdAt, updatedAt: nowSeconds(), active: current?.active !== true, deleted: false };
  await writeLocalEntry(db, reaction);
  return reaction;
}

export async function linkCollectionPlace(db: SQLiteDatabase, input: { postID: string; placeID: string; authorID: string; authorName: string }): Promise<CollectionEntry> {
  const entries = await readCollectionEntries(db, true);
  if (!entries.some((entry) => entry.id === input.postID && entry.kind === 'post' && !entry.deleted)) throw new Error('Dieser Beitrag ist nicht mehr verfügbar.');
  const id = await placeLinkID(input.postID, input.placeID);
  const current = entries.find((entry) => entry.id === id);
  if (current && !current.deleted && current.active !== false) return current;
  const entry: CollectionEntry = { id, kind: 'placeLink', postID: input.postID, placeID: input.placeID, authorID: input.authorID, authorName: input.authorName, createdAt: current?.createdAt ?? nowSeconds(), updatedAt: nowSeconds(), active: true, deleted: false };
  await writeLocalEntry(db, entry);
  return entry;
}

export async function unlinkCollectionPlace(db: SQLiteDatabase, postID: string, placeID: string): Promise<void> {
  const id = await placeLinkID(postID, placeID);
  const current = (await readCollectionEntries(db, true)).find((entry) => entry.id === id);
  if (!current) return;
  await writeLocalEntry(db, { ...current, active: false, deleted: true, updatedAt: nowSeconds() });
}

export async function tombstoneCollectionEntry(db: SQLiteDatabase, id: string): Promise<void> {
  const current = (await readCollectionEntries(db, true)).find((entry) => entry.id === id);
  if (!current) return;
  await writeLocalEntry(db, { ...current, deleted: true, active: false, updatedAt: nowSeconds() });
}

export async function updateCollectionMetadata(db: SQLiteDatabase, id: string, patch: { displayTitle?: string; caption?: string; thumbnailURL?: string; state?: CollectionMetadataState }, expectedMutationToken?: string): Promise<boolean> {
  const current = (await readCollectionEntries(db, true)).find((entry) => entry.id === id && entry.kind === 'post' && !entry.deleted);
  if (!current) return false;
  if (expectedMutationToken) {
    const sync = await readCollectionSync(db, id);
    if (sync?.mutationToken !== expectedMutationToken) return false;
  }
  const next = { ...current, displayTitle: patch.displayTitle?.trim() || current.displayTitle, caption: patch.caption?.trim() || current.caption, thumbnailURL: patch.thumbnailURL?.trim() || current.thumbnailURL, metadataState: patch.state ?? current.metadataState };
  await writeLocalEntry(db, next);
  return true;
}

export async function collectionParticipantDigest(value: string): Promise<string> { return Crypto.digestStringAsync(Crypto.CryptoDigestAlgorithm.SHA256, value); }
