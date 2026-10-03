import { createContext, useCallback, useContext, useEffect, useMemo, useState, type PropsWithChildren } from 'react';
import { useSQLiteContext } from 'expo-sqlite';
import type { Place } from '@/domain/place';
import { recordVote } from '@/storage/vote-store';
import { shouldDiscardOnMove } from '@/domain/place-images';

interface PlaceRow {
  id: string;
  title: string;
  note: string;
  source_url: string;
  category: string;
  author: string;
  image_json: string | null;
  address: string;
  lat: number | null;
  lng: number | null;
  franked: number;
  deferred: number;
  deleted: number;
  visited: number;
  day: number | null;
  day_order: number | null;
  approvals_json: string;
  passed_by_json: string;
  opening_hours: string | null;
  gallery_json: string | null;
  updated_at: number;
}

interface PlaceStoreValue {
  places: Place[];
  memberName: string;
  renameMember: (name: string) => Promise<void>;
  ready: boolean;
  decide: (id: string, approve: boolean | null) => Promise<void>;
  addPlace: (title: string, category: string, note: string) => Promise<void>;
  reload: () => Promise<void>;
  setCoordinates: (id: string, latitude: number, longitude: number) => Promise<void>;
  assignDay: (id: string, day: number | null) => Promise<void>;
}

const PlaceStoreContext = createContext<PlaceStoreValue | null>(null);

function fromRow(row: PlaceRow): Place {
  return {
    id: row.id,
    title: row.title,
    note: row.note,
    sourceURL: row.source_url,
    category: row.category,
    author: row.author,
    image: row.image_json ? JSON.parse(row.image_json) as Record<string, unknown> : null,
    address: row.address,
    lat: row.lat ?? undefined,
    lng: row.lng ?? undefined,
    franked: Boolean(row.franked),
    deferred: Boolean(row.deferred),
    deleted: Boolean(row.deleted),
    visited: Boolean(row.visited),
    day: row.day,
    dayOrder: row.day_order,
    approvals: JSON.parse(row.approvals_json) as string[],
    passedBy: JSON.parse(row.passed_by_json) as string[],
    openingHours: row.opening_hours,
    gallery: row.gallery_json ? JSON.parse(row.gallery_json) as Record<string, unknown>[] : null,
    updatedAt: row.updated_at,
  };
}

export async function readPlaces(db: ReturnType<typeof useSQLiteContext>): Promise<Place[]> {
  const rows = await db.getAllAsync<PlaceRow>('SELECT * FROM places WHERE deleted = 0 ORDER BY title COLLATE NOCASE');
  return rows.map(fromRow);
}

export function PlaceStoreProvider({ children }: PropsWithChildren) {
  const db = useSQLiteContext();
  const [places, setPlaces] = useState<Place[]>([]);
  const [memberName, setMemberName] = useState('Ich');
  const [ready, setReady] = useState(false);

  useEffect(() => {
    let active = true;
    Promise.all([
      readPlaces(db),
      db.getFirstAsync<{ value: string }>("SELECT value FROM album_settings WHERE key = 'memberName'"),
    ]).then(([loaded, setting]) => {
      if (!active) return;
      setPlaces(loaded);
      if (setting?.value.trim()) setMemberName(setting.value);
      setReady(true);
    }).catch(() => {
      if (active) setReady(true);
    });
    return () => { active = false; };
  }, [db]);

  const decide = useCallback(async (id: string, approve: boolean | null) => {
    await recordVote(db, id, memberName, approve);
    setPlaces(await readPlaces(db));
  }, [db, memberName]);

  const addPlace = useCallback(async (title: string, category: string, note: string) => {
    const cleanedTitle = title.trim();
    if (!cleanedTitle) return;
    const place: Place = {
      id: `expo-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`,
      title: cleanedTitle,
      category: category.trim() || 'Idee',
      note: note.trim(),
      sourceURL: '',
      author: memberName,
      image: null,
      address: '',
      franked: false,
      deferred: false,
      deleted: false,
      visited: false,
      day: null,
      dayOrder: null,
      approvals: [],
      passedBy: [],
      openingHours: null,
      gallery: null,
      updatedAt: Date.now(),
    };
    await db.runAsync(
      `INSERT INTO places (id, title, note, category, author, approvals_json, passed_by_json, updated_at)
       VALUES (?, ?, ?, ?, ?, '[]', '[]', ?)`,
      [place.id, place.title, place.note, place.category, place.author, place.updatedAt],
    );
    setPlaces((current) => [...current, place].sort((a, b) => a.title.localeCompare(b.title, 'de')));
  }, [db, memberName]);

  const renameMember = useCallback(async (name: string) => {
    const cleaned = name.trim();
    if (!cleaned) return;
    await db.runAsync("INSERT OR REPLACE INTO album_settings (key, value) VALUES ('memberName', ?)", [cleaned]);
    setMemberName(cleaned);
  }, [db]);

  const reload = useCallback(async () => {
    setPlaces(await readPlaces(db));
  }, [db]);

  const setCoordinates = useCallback(async (id: string, latitude: number, longitude: number) => {
    if (!Number.isFinite(latitude) || latitude < -90 || latitude > 90 || !Number.isFinite(longitude) || longitude < -180 || longitude > 180) throw new Error('Die Kartenposition ist ungültig.');
    await db.withExclusiveTransactionAsync(async (transaction) => {
      const current = await transaction.getFirstAsync<{ lat: number | null; lng: number | null; updated_at: number; image_json: string | null; gallery_json: string | null; opening_hours: string | null }>('SELECT lat,lng,updated_at,image_json,gallery_json,opening_hours FROM places WHERE id=?', [id]);
      if (!current || (current.lat === latitude && current.lng === longitude)) return;
      const moved = current.lat === null || current.lng === null || Math.abs(current.lat - latitude) > 0.0001 || Math.abs(current.lng - longitude) > 0.0001;
      let image = current.image_json;
      if (moved && current.image_json) { try { image = shouldDiscardOnMove(JSON.parse(current.image_json) as Record<string, unknown>) ? null : current.image_json; } catch { image = current.image_json; } }
      await transaction.runAsync('UPDATE places SET lat = ?, lng = ?, image_json = ?, gallery_json = ?, opening_hours = ?, updated_at = MAX(updated_at + 1, ?) WHERE id = ?', [latitude, longitude, image, moved ? null : current.gallery_json, moved ? null : current.opening_hours, Math.max(Date.now(), current.updated_at + 1), id]);
    });
    setPlaces(await readPlaces(db));
  }, [db]);

  const assignDay = useCallback(async (id: string, day: number | null) => {
    if (day !== null && (!Number.isInteger(day) || day < 4 || day > 9)) throw new Error('Der Reisetag ist ungültig.');
    await db.withExclusiveTransactionAsync(async (transaction) => {
      const selected = await transaction.getFirstAsync<{ id: string; day: number | null; day_order: number | null; updated_at: number; franked: number; deleted: number }>('SELECT id,day,day_order,updated_at,franked,deleted FROM places WHERE id=?', [id]);
      if (!selected || selected.day === day) return;
      if (!selected.franked || selected.deleted) {
        const order = day === null ? null : ((await transaction.getAllAsync<{ day_order: number | null }>('SELECT day_order FROM places WHERE deleted=0 AND franked=1 AND day=?', [day])).reduce((max, row) => Math.max(max, row.day_order ?? -1), -1) + 1);
        await transaction.runAsync('UPDATE places SET day=?,day_order=?,updated_at=MAX(updated_at+1,?) WHERE id=?', [day, order, Math.max(Date.now(), selected.updated_at + 1), id]);
        return;
      }
      const affectedDays = [selected.day, day].filter((value): value is number => value !== null);
      const placeholders = affectedDays.map(() => '?').join(',');
      const rows = await transaction.getAllAsync<{ id: string; day: number | null; day_order: number | null; updated_at: number }>(`SELECT id,day,day_order,updated_at FROM places WHERE deleted=0 AND franked=1 AND day IN (${placeholders})`, affectedDays);
      const groups = new Map<number, typeof rows>();
      for (const candidate of rows) if (candidate.day !== null) groups.set(candidate.day, [...(groups.get(candidate.day) ?? []), candidate]);
      for (const list of groups.values()) list.sort((a, b) => (a.day_order ?? 999) - (b.day_order ?? 999) || a.id.localeCompare(b.id));
      if (selected.day !== null && groups.has(selected.day)) groups.set(selected.day, groups.get(selected.day)!.filter((row) => row.id !== id));
      if (day !== null) groups.set(day, [...(groups.get(day) ?? []).filter((row) => row.id !== id), selected]);
      const next = new Map<string, { day: number | null; order: number | null }>();
      for (const row of rows) next.set(row.id, { day: row.day, order: row.day_order });
      next.set(selected.id, { day: null, order: null });
      for (const [targetDay, list] of groups) list.forEach((row, index) => next.set(row.id, { day: targetDay, order: index }));
      for (const row of new Map([...rows, selected].map((row) => [row.id, row])).values()) {
        const assignment = next.get(row.id)!;
        if (row.day === assignment.day && row.day_order === assignment.order) continue;
        await transaction.runAsync('UPDATE places SET day=?,day_order=?,updated_at=MAX(updated_at+1,?) WHERE id=?', [assignment.day, assignment.order, Math.max(Date.now(), row.updated_at + 1), row.id]);
      }
    });
    setPlaces(await readPlaces(db));
  }, [db]);

  const value = useMemo(() => ({ places, memberName, ready, decide, addPlace, renameMember, reload, setCoordinates, assignDay }), [places, memberName, ready, decide, addPlace, renameMember, reload, setCoordinates, assignDay]);
  return <PlaceStoreContext.Provider value={value}>{children}</PlaceStoreContext.Provider>;
}

export function usePlaceStore(): PlaceStoreValue {
  const value = useContext(PlaceStoreContext);
  if (!value) throw new Error('usePlaceStore requires PlaceStoreProvider');
  return value;
}
