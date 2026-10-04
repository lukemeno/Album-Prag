import { createContext, useCallback, useContext, useEffect, useMemo, useState, type PropsWithChildren } from 'react';
import { useSQLiteContext } from 'expo-sqlite';
import type { Place, PlaceDecision } from '@/domain/place';
import { decidePlace } from '@/domain/place-decisions';

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
  decide: (id: string, decision: PlaceDecision) => Promise<void>;
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

async function savePlace(db: ReturnType<typeof useSQLiteContext>, place: Place): Promise<void> {
  await db.runAsync(
    `UPDATE places SET franked = ?, deferred = ?, approvals_json = ?, passed_by_json = ?, updated_at = ? WHERE id = ?`,
    [Number(place.franked), Number(place.deferred), JSON.stringify(place.approvals), JSON.stringify(place.passedBy), place.updatedAt, place.id],
  );
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

  const decide = useCallback(async (id: string, decision: PlaceDecision) => {
    const place = places.find((item) => item.id === id);
    if (!place) return;
    const changed = decidePlace(place, memberName, decision);
    await savePlace(db, changed);
    setPlaces((current) => current.map((item) => item.id === id ? changed : item));
  }, [db, memberName, places]);

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
    const updatedAt = Date.now();
    await db.runAsync('UPDATE places SET lat = ?, lng = ?, updated_at = ? WHERE id = ?', [latitude, longitude, updatedAt, id]);
    setPlaces((current) => current.map((place) => place.id === id ? { ...place, lat: latitude, lng: longitude, updatedAt } : place));
  }, [db]);

  const assignDay = useCallback(async (id: string, day: number | null) => {
    const updatedAt = Date.now();
    const order = day == null ? null : (places.filter((place) => place.day === day && place.id !== id).reduce((max, place) => Math.max(max, place.dayOrder ?? -1), -1) + 1);
    await db.runAsync('UPDATE places SET day = ?, day_order = ?, updated_at = ? WHERE id = ?', [day, order, updatedAt, id]);
    setPlaces((current) => current.map((place) => place.id === id ? { ...place, day, dayOrder: order, updatedAt } : place));
  }, [db, places]);

  const value = useMemo(() => ({ places, memberName, ready, decide, addPlace, renameMember, reload, setCoordinates, assignDay }), [places, memberName, ready, decide, addPlace, renameMember, reload, setCoordinates, assignDay]);
  return <PlaceStoreContext.Provider value={value}>{children}</PlaceStoreContext.Provider>;
}

export function usePlaceStore(): PlaceStoreValue {
  const value = useContext(PlaceStoreContext);
  if (!value) throw new Error('usePlaceStore requires PlaceStoreProvider');
  return value;
}
