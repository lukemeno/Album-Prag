import { createContext, useCallback, useContext, useEffect, useMemo, useRef, useState, type PropsWithChildren } from 'react';
import { Alert } from 'react-native';
import { useSQLiteContext } from 'expo-sqlite';
import { supabase } from '@/storage/supabase';
import { usePlaceStore } from '@/storage/place-store';
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

const TripSyncContext = createContext<TripSyncValue | null>(null);

function nativeDate(date: number): number {
  return (date - 978307200000) / 1000;
}

export function TripSyncProvider({ children }: PropsWithChildren) {
  const db = useSQLiteContext();
  const { places, memberName, reload } = usePlaceStore();
  const [tripID, setTripID] = useState<string | null>(null);
  const [inviteToken, setInviteToken] = useState<string | null>(null);
  const [status, setStatus] = useState(supabase ? 'Offline bereit' : 'Offline · Supabase nicht konfiguriert');
  const running = useRef<Promise<boolean> | null>(null);
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

  const writePlace = useCallback(async (activeTripID: string, place: Place) => {
    if (!supabase) return;
    const payload = {
      id: place.id, title: place.title, note: place.note, sourceURL: place.sourceURL,
      category: place.category, author: place.author, image: place.image,
      address: place.address, lat: place.lat, lng: place.lng,
      franked: place.franked, deferred: place.deferred, deleted: place.deleted,
      visited: place.visited, day: place.day, dayOrder: place.dayOrder,
      approvals: place.approvals, passedBy: place.passedBy,
      openingHours: place.openingHours, gallery: place.gallery,
      updatedAt: nativeDate(place.updatedAt),
    };
    const { error } = await supabase.from('places').upsert({
      trip_id: activeTripID,
      id: place.id,
      payload,
      updated_at: new Date(place.updatedAt).toISOString(),
      deleted: place.deleted,
    }, { onConflict: 'trip_id,id' });
    if (error) throw error;
  }, []);

  const refresh = useCallback((activeTripID: string, token: string | null): Promise<boolean> => {
    if (!supabase) return Promise.resolve(false);
    if (running.current) return running.current;
    setStatus('Synchronisiere …');
    const task = (async () => {
    try {
      await ensureSession();
      const { data: memberRows, error: memberError } = await supabase.from('trip_members').select('user_id').eq('trip_id', activeTripID).limit(1);
      if (memberError) throw memberError;
      if (memberRows.length === 0) {
        if (!token) throw new Error('Einladung fehlt. Bitte die Reise noch einmal über den Einladungslink beitreten.');
        const joined = await supabase.functions.invoke('join-trip', { body: { invite_token: token } });
        if (joined.error || joined.data?.trip_id !== activeTripID) throw joined.error ?? new Error('Die Einladung gehört zu einer anderen Reise.');
      }

      const { data: remoteTrip, error: tripError } = await supabase!.from('trips').select('payload,updated_at').eq('id', activeTripID).single();
      if (tripError) throw tripError;
      const tripSetting = await db.getFirstAsync<{ value: string }>("SELECT value FROM album_settings WHERE key = 'trip'");
      const localTrip = tripSetting ? JSON.parse(tripSetting.value) as Record<string, unknown> : null;
      const localTripTime = typeof localTrip?.updatedAt === 'number' ? localTrip.updatedAt * 1000 + 978307200000 : 0;
      if (localTrip && localTripTime > Date.parse(remoteTrip.updated_at)) {
        const { error } = await supabase!.from('trips').update({ payload: localTrip, updated_at: new Date(localTripTime).toISOString() }).eq('id', activeTripID);
        if (error) throw error;
      } else if (remoteTrip?.payload) await saveSetting('trip', JSON.stringify(remoteTrip.payload));

      const { data: remoteRows, error: readError } = await supabase.from('places').select('id,payload,updated_at,deleted').eq('trip_id', activeTripID);
      if (readError) throw readError;
      const remote = (remoteRows ?? []) as SyncRow[];
      const localRows = await db.getAllAsync<Record<string, unknown>>('SELECT * FROM places');
      const localByID = new Map(localRows.map((row) => [String(row.id), row]));

      for (const row of remote) {
        const local = localByID.get(row.id);
        const remoteMillis = Date.parse(row.updated_at);
        if (local && Number(local.updated_at) > remoteMillis) continue;
        const remotePayload = row.payload as Record<string, unknown>;
        const localApprovals = local ? JSON.parse(String(local.approvals_json ?? '[]')) as string[] : [];
        const localPassedBy = local ? JSON.parse(String(local.passed_by_json ?? '[]')) as string[] : [];
        const approvals = [...new Set([...localApprovals, ...(Array.isArray(remotePayload.approvals) ? remotePayload.approvals.filter((name): name is string => typeof name === 'string') : [])])];
        const passedBy = [...new Set([...localPassedBy, ...(Array.isArray(remotePayload.passedBy) ? remotePayload.passedBy.filter((name): name is string => typeof name === 'string') : [])])];
        const votesChanged = approvals.length !== (Array.isArray(remotePayload.approvals) ? remotePayload.approvals.length : 0)
          || passedBy.length !== (Array.isArray(remotePayload.passedBy) ? remotePayload.passedBy.length : 0);
        const p: Record<string, unknown> = { ...remotePayload, approvals, passedBy, franked: approvals.length > 0 || Boolean(remotePayload.franked) };
        await db.runAsync(
          `INSERT OR REPLACE INTO places (id,title,note,source_url,category,author,image_json,address,lat,lng,franked,deferred,deleted,visited,day,day_order,approvals_json,passed_by_json,opening_hours,gallery_json,updated_at)
           VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)`,
          [row.id, String(p.title ?? row.id), String(p.note ?? ''), String(p.sourceURL ?? ''), String(p.category ?? 'Idee'), String(p.author ?? ''), p.image ? JSON.stringify(p.image) : null, String(p.address ?? ''), typeof p.lat === 'number' ? p.lat : null, typeof p.lng === 'number' ? p.lng : null, Number(Boolean(p.franked)), Number(Boolean(p.deferred)), Number(row.deleted), Number(Boolean(p.visited)), typeof p.day === 'number' ? p.day : null, typeof p.dayOrder === 'number' ? p.dayOrder : null, JSON.stringify(approvals), JSON.stringify(passedBy), typeof p.openingHours === 'string' ? p.openingHours : null, p.gallery ? JSON.stringify(p.gallery) : null, remoteMillis + Number(votesChanged)],
        );
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
        if (!remoteIDs.has(place.id) || Number(row.updated_at) > Date.parse(remote.find((item) => item.id === place.id)?.updated_at ?? '')) await writePlace(activeTripID, place);
      }

      const { data: remoteCollectionRows, error: collectionReadError } = await supabase.from('collection_entries').select('id,payload,version,deleted,updated_at').eq('trip_id', activeTripID);
      if (collectionReadError) throw collectionReadError;
      const remoteCollection = (remoteCollectionRows ?? []) as CollectionSyncRow[];
      const localCollection = await db.getAllAsync<{ id: string; payload_json: string; version: number; deleted: number; updated_at: number }>('SELECT * FROM collection_entries');
      const localCollectionByID = new Map(localCollection.map((row) => [row.id, row]));
      for (const row of remoteCollection) {
        const local = localCollectionByID.get(row.id);
        if (local && local.updated_at > Date.parse(row.updated_at)) continue;
        await db.runAsync('INSERT OR REPLACE INTO collection_entries (id,payload_json,version,deleted,updated_at) VALUES (?,?,?,?,?)', [row.id, JSON.stringify(row.payload), row.version, Number(row.deleted), Date.parse(row.updated_at)]);
      }
      const remoteCollectionByID = new Map(remoteCollection.map((row) => [row.id, row]));
      for (const row of localCollection) {
        const remoteRow = remoteCollectionByID.get(row.id);
        if (remoteRow && row.updated_at <= Date.parse(remoteRow.updated_at)) continue;
        const nextVersion = Math.max(row.version, remoteRow?.version ?? 0) + 1;
        const { error } = await supabase.from('collection_entries').upsert({
          trip_id: activeTripID, id: row.id, payload: JSON.parse(row.payload_json) as Record<string, unknown>,
          version: nextVersion, deleted: Boolean(row.deleted),
        }, { onConflict: 'trip_id,id' });
        if (error) throw error;
        await db.runAsync('UPDATE collection_entries SET version = ? WHERE id = ?', [nextVersion, row.id]);
      }
      await reload();
      setRevision((current) => current + 1);
      setStatus(`Gemeinsam synchronisiert · ${new Date().toLocaleTimeString('de-DE', { hour: '2-digit', minute: '2-digit' })}`);
      return true;
    } catch (error) {
      setStatus(error instanceof Error ? error.message : 'Synchronisierung fehlgeschlagen');
      return false;
    }
    })();
    running.current = task;
    void task.finally(() => { if (running.current === task) running.current = null; });
    return task;
  }, [db, ensureSession, writePlace, reload, saveSetting]);

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
    for (const place of places) await writePlace(createdID, place);
    setStatus('Reise erstellt · Ideen werden geteilt');
    return createdToken;
  }, [ensureSession, memberName, places, saveSetting, writePlace]);

  const joinTrip = useCallback(async (rawToken: string) => {
    if (!supabase) throw new Error('Supabase-Konfiguration fehlt.');
    const token = rawToken.trim();
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
