import { createContext, useCallback, useContext, useEffect, useMemo, useRef, useState, type PropsWithChildren } from 'react';
import { Alert } from 'react-native';
import { syncPlaceMedia } from '@/storage/place-media';
import { invitationToken} from '@/domain/invitation';
import { useSQLiteContext, type SQLiteDatabase } from 'expo-sqlite';
import { supabase } from '@/storage/supabase';
import { usePlaceStore } from '@/storage/place-store';
import { legacyVoteEvents, mergeVoteEvents, parseVoteEvents, voteLists } from '@/domain/vote-events';
import { readVoteEvents, writeVoteEvents } from '@/storage/vote-store';
import { syncTravelDocuments } from '@/storage/travel-documents';
import type { Place } from '@/domain/place';

interface TripSyncValue {
  tripID: string | null;
  inviteToken: string | null;
  status: string;
  createTrip: () => Promise<string | null>;
  joinTrip: (token: string) => Promise<void>;
  syncNow: () => Promise<boolean>;
  revision: number;
  setMemberName: (name: string) => Promise<void>;
  reloadTripInfo: () => Promise<void>;
}

interface SyncRow {
  id: string;
  payload: Record<string, unknown>;
  updated_at: string;
  deleted: boolean;
}

interface CollectionSyncRow {
  id: string;
  payload: Record<string, unknown>;
  version: number;
  deleted: boolean;
  updated_at: string;
}

interface SyncScope { albumID: string | null; tripID: string | null; }
async function readSyncScope(db: SQLiteDatabase): Promise<SyncScope> { const rows = await db.getAllAsync<{ key: string; value: string }>("SELECT key,value FROM album_settings WHERE key IN ('albumID','tripID')"); const values = new Map(rows.map((row) => [row.key, row.value])); return { albumID: values.get('albumID') ?? null, tripID: values.get('tripID') ?? null }; }
async function assertSyncScope(db: SQLiteDatabase, expected: SyncScope): Promise<void> { const current = await readSyncScope(db); if (current.albumID !== expected.albumID || current.tripID !== expected.tripID) throw new Error('Die Reise wurde während des Abgleichs gewechselt.'); }

type RefreshFunction = (activeTripID: string, token: string | null) => Promise<boolean>;

const TripSyncContext = createContext<TripSyncValue | null>(null);

function nativeDate(date: number): number {
  return (date - 978307200000) / 1000;
}

export function TripSyncProvider({ children }: PropsWithChildren) {
  const db = useSQLiteContext();
  const { memberName, reload } = usePlaceStore();
  const [tripID, setTripID] = useState<string | null>(null);
  const [inviteToken, setInviteToken] = useState<string | null>(null);
  const [status, setStatus] = useState(supabase ? 'Offline bereit' : 'Offline · Supabase nicht konfiguriert');
  const running = useRef<{ tripID: string; task: Promise<boolean> } | null>(null);
  const refreshRef = useRef<RefreshFunction>(async () => false);
  const [revision, setRevision] = useState(0);

  useEffect(() => {
    let active = true;
    Promise.all([
      db.getFirstAsync<{ value: string }>("SELECT value FROM album_settings WHERE key = 'tripID'"),
      db.getFirstAsync<{ value: string }>("SELECT value FROM album_settings WHERE key = 'inviteToken'"),
    ]).then(([trip, invite]) => {
      if (!active) return;
      setTripID(trip?.value ?? null);
      setInviteToken(invite?.value ?? null);
    });
    return () => { active = false; };
  }, [db]);

  const saveSetting = useCallback(async (key: string, value: string) => {
    await db.runAsync('INSERT OR REPLACE INTO album_settings (key, value) VALUES (?, ?)', [key, value]);
  }, [db]);

  const reloadTripInfo = useCallback(async () => {
    const [trip, invite] = await Promise.all([
      db.getFirstAsync<{ value: string }>("SELECT value FROM album_settings WHERE key = 'tripID'"),
      db.getFirstAsync<{ value: string }>("SELECT value FROM album_settings WHERE key = 'inviteToken'"),
    ]);
    setTripID(trip?.value ?? null);
    setInviteToken(invite?.value ?? null);
  }, [db]);

  const ensureSession = useCallback(async () => {
    if (!supabase) throw new Error('Supabase ist in dieser Expo-Installation nicht eingerichtet.');
    const { data: { session }, error } = await supabase.auth.getSession();
    if (error) throw error;
    if (session) return;
    const result = await supabase.auth.signInAnonymously();
    if (result.error) throw result.error;
  }, []);

  const writePlace = useCallback(async (activeTripID: string, place: Place, expectedRemote: string | null) => {
    if (!supabase) return;
    const currentTrip = await db.getFirstAsync<{ value: string }>("SELECT value FROM album_settings WHERE key='tripID'");
    if (currentTrip?.value !== activeTripID) throw new Error('Die Reise wurde während des Abgleichs geändert.');
    const publishedAt = Math.max(place.updatedAt, expectedRemote ? Date.parse(expectedRemote) + 1 : place.updatedAt);
    const payload = {
      id: place.id, title: place.title, note: place.note, sourceURL: place.sourceURL,
      category: place.category, author: place.author, image: place.image,
      address: place.address, lat: place.lat, lng: place.lng,
      franked: place.franked, deferred: place.deferred, deleted: place.deleted,
      visited: place.visited, day: place.day, dayOrder: place.dayOrder,
      approvals: place.approvals, passedBy: place.passedBy,
      openingHours: place.openingHours, gallery: place.gallery,
      voteEvents: await readVoteEvents(db, place.id),
      updatedAt: nativeDate(publishedAt),
    };
    const row = { trip_id: activeTripID, id: place.id, payload, updated_at: new Date(publishedAt).toISOString(), deleted: place.deleted };
    const result = expectedRemote === null
      ? await supabase.from('places').insert(row).select('id')
      : await supabase.from('places').update(row).eq('trip_id', activeTripID).eq('id', place.id).eq('updated_at', expectedRemote).select('id');
    if (result.error) throw result.error;
    if (result.data?.length !== 1) throw new Error('Ein Ort wurde während des Abgleichs geändert. Die lokale Änderung bleibt gespeichert; bitte erneut synchronisieren.');
    if (publishedAt !== place.updatedAt) await db.runAsync('UPDATE places SET updated_at=? WHERE id=? AND updated_at=?', [publishedAt, place.id, place.updatedAt]);
  }, [db]);

  const refresh = useCallback<RefreshFunction>((activeTripID, token) => {
    if (!supabase) return Promise.resolve(false);
    if (running.current) {
      if (running.current.tripID === activeTripID) return running.current.task;
      return running.current.task.catch(() => false).then(() => refreshRef.current(activeTripID, token));
    }
    setStatus('Synchronisiere …');
    const task = (async () => {
    try {
      await ensureSession();
      const scope = await readSyncScope(db);
      if (scope.tripID !== activeTripID) throw new Error('Die lokale Reise gehört inzwischen zu einem anderen Abgleich.');
      const { data: memberRows, error: memberError } = await supabase.from('trip_members').select('user_id').eq('trip_id', activeTripID).limit(1);
      if (memberError) throw memberError;
      if (memberRows.length === 0) {
        if (!token) throw new Error('Einladung fehlt. Bitte die Reise noch einmal über den Einladungslink beitreten.');
        const joined = await supabase.functions.invoke('join-trip', { body: { invite_token: token } });
        if (joined.error || joined.data?.trip_id !== activeTripID) throw joined.error ?? new Error('Die Einladung gehört zu einer anderen Reise.');
      }

      const { data: remoteTrip, error: tripError } = await supabase!.from('trips').select('payload,updated_at').eq('id', activeTripID).single();
      if (tripError) throw tripError;
      await assertSyncScope(db, scope);
      const tripSetting = await db.getFirstAsync<{ value: string }>("SELECT value FROM album_settings WHERE key = 'trip'");
      const localTrip = tripSetting ? JSON.parse(tripSetting.value) as Record<string, unknown> : null;
      const localTripTime = typeof localTrip?.updatedAt === 'number' ? localTrip.updatedAt * 1000 + 978307200000 : 0;
      if (localTrip && localTripTime > Date.parse(remoteTrip.updated_at)) {
        const { data, error } = await supabase!.from('trips').update({ payload: localTrip, updated_at: new Date(localTripTime).toISOString() }).eq('id', activeTripID).eq('updated_at', remoteTrip.updated_at).select('id');
        if (error) throw error;
        if (data?.length !== 1) throw new Error('Die Reiseinformationen wurden inzwischen geändert. Bitte erneut synchronisieren.');
      } else if (remoteTrip?.payload) {
        await assertSyncScope(db, scope);
        const changed = await db.runAsync("UPDATE album_settings SET value=? WHERE key='trip' AND value=?", [JSON.stringify(remoteTrip.payload), tripSetting?.value ?? '']);
        if (tripSetting && changed.changes !== 1) throw new Error('Die lokalen Reiseinformationen wurden inzwischen geändert.');
        if (!tripSetting) await db.runAsync("INSERT INTO album_settings(key,value) VALUES ('trip',?)", [JSON.stringify(remoteTrip.payload)]);
      }

      await syncPlaceMedia(db, activeTripID);
      await assertSyncScope(db, scope);
      await syncTravelDocuments(db, activeTripID, scope.albumID);
      await assertSyncScope(db, scope);
      const { data: remoteRows, error: readError } = await supabase.from('places').select('id,payload,updated_at,deleted').eq('trip_id', activeTripID);
      if (readError) throw readError;
      const remote = (remoteRows ?? []) as SyncRow[];

      for (const row of remote) {
        await db.withExclusiveTransactionAsync(async (transaction) => {
        const currentTrip = await transaction.getFirstAsync<{ value: string }>("SELECT value FROM album_settings WHERE key='tripID'");
        if (currentTrip?.value !== activeTripID) throw new Error('Die Reise wurde während des Abgleichs geändert.');
        const local = await transaction.getFirstAsync<Record<string, unknown>>('SELECT * FROM places WHERE id = ?', [row.id]);
        const remoteMillis = Date.parse(row.updated_at);
        const remotePayload = row.payload as Record<string, unknown>;
        const localApprovals = local ? JSON.parse(String(local.approvals_json ?? '[]')) as string[] : [];
        const localPassedBy = local ? JSON.parse(String(local.passed_by_json ?? '[]')) as string[] : [];
        const remoteApprovals = Array.isArray(remotePayload.approvals) ? remotePayload.approvals.filter((name): name is string => typeof name === 'string') : [];
        const remotePassedBy = Array.isArray(remotePayload.passedBy) ? remotePayload.passedBy.filter((name): name is string => typeof name === 'string') : [];
        const localEvents = legacyVoteEvents(localApprovals, localPassedBy, Number(local?.updated_at ?? 0), await readVoteEvents(transaction, row.id));
        const remoteEvents = legacyVoteEvents(remoteApprovals, remotePassedBy, remoteMillis, parseVoteEvents(remotePayload.voteEvents));
        const events = mergeVoteEvents(localEvents, remoteEvents);
        await writeVoteEvents(transaction, row.id, events);
        const { approvals, passedBy } = voteLists(events);
        const votesChanged = Object.keys(events).length !== Object.keys(remoteEvents).length || Object.entries(events).some(([name, event]) => event.at !== remoteEvents[name]?.at || event.choice !== remoteEvents[name]?.choice);
        const voteTime = Math.max(remoteMillis, ...Object.values(events).map((event) => event.at));
        const timestamp = Math.max(voteTime, remoteMillis + Number(votesChanged), Number(local?.updated_at ?? 0));
        if (local && Number(local.updated_at) > remoteMillis) {
          await transaction.runAsync('UPDATE places SET approvals_json=?,passed_by_json=?,franked=?,deferred=?,updated_at=? WHERE id=?', [JSON.stringify(approvals),JSON.stringify(passedBy),Number(approvals.length > 0 || (!Object.keys(events).length && Boolean(local.franked))),Number(!approvals.length && (passedBy.length > 0 || (!Object.keys(events).length && Boolean(local.deferred)))),timestamp,row.id]);
          return;
        }
        const p: Record<string, unknown> = { ...remotePayload, approvals, passedBy, franked: approvals.length > 0 || (!Object.keys(events).length && Boolean(remotePayload.franked)), deferred: !approvals.length && (passedBy.length > 0 || (!Object.keys(events).length && Boolean(remotePayload.deferred))) };
        await transaction.runAsync(
          `INSERT OR REPLACE INTO places (id,title,note,source_url,category,author,image_json,address,lat,lng,franked,deferred,deleted,visited,day,day_order,approvals_json,passed_by_json,opening_hours,gallery_json,updated_at)
           VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)`,
          [row.id, String(p.title ?? row.id), String(p.note ?? ''), String(p.sourceURL ?? ''), String(p.category ?? 'Idee'), String(p.author ?? ''), p.image ? JSON.stringify(p.image) : null, String(p.address ?? ''), typeof p.lat === 'number' ? p.lat : null, typeof p.lng === 'number' ? p.lng : null, Number(Boolean(p.franked)), Number(Boolean(p.deferred)), Number(row.deleted), Number(Boolean(p.visited)), typeof p.day === 'number' ? p.day : null, typeof p.dayOrder === 'number' ? p.dayOrder : null, JSON.stringify(approvals), JSON.stringify(passedBy), typeof p.openingHours === 'string' ? p.openingHours : null, p.gallery ? JSON.stringify(p.gallery) : null, timestamp],
        );
        });
      }

      const updatedRows = await db.getAllAsync<Record<string, unknown>>('SELECT * FROM places');
      const remoteIDs = new Set(remote.map((row) => row.id));
      for (const row of updatedRows) {
        const place: Place = {
          id: String(row.id), title: String(row.title), note: String(row.note ?? ''), sourceURL: String(row.source_url ?? ''), category: String(row.category ?? 'Idee'), author: String(row.author ?? ''), image: row.image_json ? JSON.parse(String(row.image_json)) as Record<string, unknown> : null,
          address: String(row.address ?? ''), lat: typeof row.lat === 'number' ? row.lat : undefined, lng: typeof row.lng === 'number' ? row.lng : undefined,
          franked: Boolean(row.franked), deferred: Boolean(row.deferred), deleted: Boolean(row.deleted), visited: Boolean(row.visited), day: typeof row.day === 'number' ? row.day : null, dayOrder: typeof row.day_order === 'number' ? row.day_order : null,
          approvals: JSON.parse(String(row.approvals_json ?? '[]')) as string[], passedBy: JSON.parse(String(row.passed_by_json ?? '[]')) as string[], openingHours: typeof row.opening_hours === 'string' ? row.opening_hours : null, gallery: row.gallery_json ? JSON.parse(String(row.gallery_json)) as Record<string, unknown>[] : null, updatedAt: Number(row.updated_at),
        };
        if (!remoteIDs.has(place.id) || Number(row.updated_at) > Date.parse(remote.find((item) => item.id === place.id)?.updated_at ?? '')) await writePlace(activeTripID, place, remote.find((item) => item.id === place.id)?.updated_at ?? null);
      }

      const { data: remoteCollectionRows, error: collectionReadError } = await supabase.from('collection_entries').select('id,payload,version,deleted,updated_at').eq('trip_id', activeTripID);
      if (collectionReadError) throw collectionReadError;
      const remoteCollection = (remoteCollectionRows ?? []) as CollectionSyncRow[];
      const localCollection = await db.getAllAsync<{ id: string; payload_json: string; version: number; deleted: number; updated_at: number }>('SELECT * FROM collection_entries');
      const localCollectionByID = new Map(localCollection.map((row) => [row.id, row]));
      for (const row of remoteCollection) {
        const local = localCollectionByID.get(row.id);
        const dirty = await db.getFirstAsync<{ value: string }>('SELECT value FROM album_settings WHERE key=?', [`dirty:collection:${row.id}`]);
        if (dirty || (local && local.updated_at > Date.parse(row.updated_at))) continue;
        await db.withExclusiveTransactionAsync(async (transaction) => {
          const currentScope = await transaction.getFirstAsync<{ value: string }>("SELECT value FROM album_settings WHERE key='tripID'");
          if (currentScope?.value !== activeTripID) throw new Error('Die Reise wurde während des Abgleichs geändert.');
          const currentDirty = await transaction.getFirstAsync<{ value: string }>('SELECT value FROM album_settings WHERE key=?', [`dirty:collection:${row.id}`]);
          if (currentDirty) return;
          await transaction.runAsync('INSERT OR REPLACE INTO collection_entries (id,payload_json,version,deleted,updated_at) VALUES (?,?,?,?,?)', [row.id, JSON.stringify(row.payload), row.version, Number(row.deleted), Date.parse(row.updated_at)]);
        });
      }
      const remoteCollectionByID = new Map(remoteCollection.map((row) => [row.id, row]));
      for (const row of localCollection) {
        const remoteRow = remoteCollectionByID.get(row.id);
        const dirtyKey = `dirty:collection:${row.id}`;
        const dirtySnapshot = await db.getFirstAsync<{ value: string }>('SELECT value FROM album_settings WHERE key=?', [dirtyKey]);
        if (!dirtySnapshot && remoteRow && row.updated_at <= Date.parse(remoteRow.updated_at)) continue;
        const currentTrip = await db.getFirstAsync<{ value: string }>("SELECT value FROM album_settings WHERE key='tripID'");
        if (currentTrip?.value !== activeTripID) throw new Error('Die Reise wurde während des Abgleichs geändert.');
        const expectedVersion = remoteRow?.version ?? 0;
        const values = { trip_id: activeTripID, id: row.id, payload: JSON.parse(row.payload_json) as Record<string, unknown>, version: expectedVersion + 1, deleted: Boolean(row.deleted) };
        const result = remoteRow
          ? await supabase.from('collection_entries').update({ payload: values.payload, version: values.version, deleted: values.deleted }).eq('trip_id', activeTripID).eq('id', row.id).eq('version', expectedVersion).select('version,updated_at').maybeSingle()
          : await supabase.from('collection_entries').insert(values).select('version,updated_at').maybeSingle();
        if (result.error) {
          // Concurrent canonical inserts are resolved by the next pull; preserve local dirty state.
          if (!remoteRow && result.error.code === '23505') continue;
          throw result.error;
        }
        if (!result.data) continue;
        const ackVersion = Number(result.data.version);
        const ackTime = Date.parse(String(result.data.updated_at));
        await db.withExclusiveTransactionAsync(async (transaction) => {
          const currentScope = await transaction.getFirstAsync<{ value: string }>("SELECT value FROM album_settings WHERE key='tripID'");
          if (currentScope?.value !== activeTripID) throw new Error('Die Reise wurde während des Abgleichs geändert.');
          const current = await transaction.getFirstAsync<{ updated_at: number }>('SELECT updated_at FROM collection_entries WHERE id=?', [row.id]);
          if (!current) return;
          await transaction.runAsync('UPDATE collection_entries SET version=?, updated_at=CASE WHEN updated_at=? THEN ? ELSE updated_at END WHERE id=?', [ackVersion, row.updated_at, ackTime, row.id]);
          const currentDirty = await transaction.getFirstAsync<{ value: string }>('SELECT value FROM album_settings WHERE key=?', [dirtyKey]);
          if (dirtySnapshot && currentDirty?.value === dirtySnapshot.value && current.updated_at === row.updated_at) await transaction.runAsync('DELETE FROM album_settings WHERE key=?', [dirtyKey]);
        });
      }
      await assertSyncScope(db, scope);
      await reload();
      setRevision((current) => current + 1);
      setStatus(`Gemeinsam synchronisiert · ${new Date().toLocaleTimeString('de-DE', { hour: '2-digit', minute: '2-digit' })}`);
      return true;
    } catch (error) {
      setStatus(error instanceof Error ? error.message : 'Synchronisierung fehlgeschlagen');
      return false;
    }
    })();
    running.current = { tripID: activeTripID, task };
    void task.finally(() => { if (running.current?.task === task) running.current = null; });
    return task;
  }, [db, ensureSession, writePlace, reload]);
  useEffect(() => { refreshRef.current = refresh; }, [refresh]);

  const syncNow = useCallback(async () => {
    if (!tripID) return false;
    return refresh(tripID, inviteToken);
  }, [tripID, inviteToken, refresh]);

  useEffect(() => {
    if (!tripID) return;
    const initial = setTimeout(() => void refresh(tripID, inviteToken), 0);
    const timer = setInterval(() => void refresh(tripID, inviteToken), 30000);
    return () => { clearTimeout(initial); clearInterval(timer); };
  }, [tripID, inviteToken, refresh]);

  useEffect(() => {
    if (!supabase || !tripID) return;
    const client = supabase;
    const channel = client.channel(`expo-trip-${tripID}`)
      .on('postgres_changes', { event: '*', schema: 'public', table: 'places', filter: `trip_id=eq.${tripID}` }, () => {
        void refresh(tripID, inviteToken);
      })
      .on('postgres_changes', { event: '*', schema: 'public', table: 'collection_entries', filter: `trip_id=eq.${tripID}` }, () => {
        void refresh(tripID, inviteToken);
      })
      .on('postgres_changes', { event: '*', schema: 'public', table: 'trips', filter: `id=eq.${tripID}` }, () => {
        void refresh(tripID, inviteToken);
      })
      .on('postgres_changes', { event: '*', schema: 'public', table: 'documents', filter: `trip_id=eq.${tripID}` }, () => {
        void refresh(tripID, inviteToken);
      })
      .subscribe();
    return () => { void client.removeChannel(channel); };
  }, [tripID, inviteToken, refresh]);

  const createTrip = useCallback(async () => {
    if (!supabase) throw new Error('Supabase-Konfiguration fehlt.');
    await ensureSession();
    const { data, error } = await supabase.functions.invoke('create-trip');
    if (error) throw error;
    const createdID = String(data.trip_id);
    const createdToken = String(data.invite_token);
    await saveSetting('tripID', createdID);
    await saveSetting('inviteToken', createdToken);
    await saveSetting('memberName', memberName);
    setTripID(createdID);
    setInviteToken(createdToken);
    const synced = await refresh(createdID, createdToken);
    if (!synced) throw new Error('Die Reise wurde erstellt; eure lokalen Daten bleiben erhalten. Bitte synchronisiere noch einmal.');
    return createdToken;
  }, [ensureSession, memberName, saveSetting, refresh]);

  const joinTrip = useCallback(async (rawToken: string) => {
    if (!supabase) throw new Error('Supabase-Konfiguration fehlt.');
    const token = invitationToken(rawToken);
    await ensureSession();
    const { data, error } = await supabase.functions.invoke('join-trip', { body: { invite_token: token } });
    if (error) throw error;
    const joinedID = String(data.trip_id);
    await saveSetting('tripID', joinedID);
    await saveSetting('inviteToken', token);
    setTripID(joinedID);
    setInviteToken(token);
    await refresh(joinedID, token);
  }, [ensureSession, refresh, saveSetting]);

  const setName = useCallback(async (name: string) => {
    const cleaned = name.trim();
    if (!cleaned) return;
    await saveSetting('memberName', cleaned);
  }, [saveSetting]);

  const value = useMemo(() => ({ tripID, inviteToken, status, revision, createTrip, joinTrip, syncNow, setMemberName: setName, reloadTripInfo }), [tripID, inviteToken, status, revision, createTrip, joinTrip, syncNow, setName, reloadTripInfo]);
  return <TripSyncContext.Provider value={value}>{children}</TripSyncContext.Provider>;
}

export function useTripSync(): TripSyncValue {
  const value = useContext(TripSyncContext);
  if (!value) throw new Error('useTripSync requires TripSyncProvider');
  return value;
}

export function showSyncError(error: unknown) {
  Alert.alert('Das hat nicht geklappt', error instanceof Error ? error.message : 'Bitte versuche es noch einmal.');
}
