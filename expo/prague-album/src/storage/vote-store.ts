import type { SQLiteDatabase } from 'expo-sqlite';
import { legacyVoteEvents, parseVoteEvents, voteLists, type VoteEvents } from '@/domain/vote-events';

export async function readVoteEvents(db: SQLiteDatabase, placeID: string): Promise<VoteEvents> {
  const row = await db.getFirstAsync<{ value: string }>('SELECT value FROM album_settings WHERE key = ?', [`votes:${placeID}`]);
  if (!row) return {};
  try { return parseVoteEvents(JSON.parse(row.value)); } catch { return {}; }
}

export async function writeVoteEvents(db: SQLiteDatabase, placeID: string, events: VoteEvents): Promise<void> {
  await db.runAsync('INSERT OR REPLACE INTO album_settings (key,value) VALUES (?,?)', [`votes:${placeID}`, JSON.stringify(events)]);
}

export async function recordVote(db: SQLiteDatabase, placeID: string, memberName: string, approve: boolean | null): Promise<void> {
  const voter = memberName.trim();
  if (!voter) throw new Error('Für die Abstimmung fehlt dein Name.');
  await db.withExclusiveTransactionAsync(async (transaction) => {
    const row = await transaction.getFirstAsync<{ approvals_json: string; passed_by_json: string; updated_at: number }>('SELECT approvals_json,passed_by_json,updated_at FROM places WHERE id = ? AND deleted = 0', [placeID]);
    if (!row) return;
    const events = legacyVoteEvents(JSON.parse(row.approvals_json), JSON.parse(row.passed_by_json), row.updated_at, await readVoteEvents(transaction, placeID));
    const at = Math.max(Date.now(), row.updated_at + 1, ...Object.values(events).map((event) => event.at + 1));
    events[voter] = { choice: approve === null ? 'open' : approve ? 'approved' : 'later', at };
    const { approvals, passedBy } = voteLists(events);
    await transaction.runAsync('UPDATE places SET approvals_json=?,passed_by_json=?,franked=?,deferred=?,updated_at=? WHERE id=?', [JSON.stringify(approvals),JSON.stringify(passedBy),Number(approvals.length > 0),Number(!approvals.length && passedBy.length > 0),at,placeID]);
    await writeVoteEvents(transaction, placeID, events);
  });
}
