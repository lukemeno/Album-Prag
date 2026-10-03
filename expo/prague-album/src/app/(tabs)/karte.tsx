import { useEffect, useMemo, useRef, useState } from 'react';
import { Linking, Platform, Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';
import { Link } from 'expo-router';
import MapView, { Marker, Polyline } from 'react-native-maps';
import * as Location from 'expo-location';
import { colors } from '@/domain/theme';
import { filterPlaces, googleWalkingURL, haversineMeters, hotelCoordinate, routeSegments, sameMapFilter, sortNearby, TRIP_DAYS, validCoordinate, type Coordinate, type MapFilter, type TripDay, type RoutePoint } from '@/domain/map-route';
import { usePlaceStore } from '@/storage/place-store';
import { applyMapPlan, mapSnapshotMatchesPlaces, readMapSnapshot, setPlaceCoordinates, type MapAssignment, type MapSnapshot } from '@/storage/map-actions';
import { useSQLiteContext } from 'expo-sqlite';
import { useTripSync } from '@/storage/trip-sync';

const pragueRegion = { latitude: 50.0875, longitude: 14.4213, latitudeDelta: 0.085, longitudeDelta: 0.085 };
interface GeocodeChoice { latitude: number; longitude: number; label: string; }
interface GeocodeRequest { token: number; placeID: string; identity: string; snapshot: MapSnapshot; }

async function currentPositionWithTimeout(milliseconds: number): Promise<Location.LocationObject> {
  let timer: ReturnType<typeof setTimeout> | undefined;
  try {
    return await Promise.race([
      Location.getCurrentPositionAsync({ accuracy: Location.Accuracy.Balanced }),
      new Promise<never>((_, reject) => { timer = setTimeout(() => reject(new Error('timeout')), milliseconds); }),
    ]);
  } finally { if (timer) clearTimeout(timer); }
}

export default function MapScreen() {
  const db = useSQLiteContext();
  const { places, reload } = usePlaceStore();
  const { tripID, syncNow } = useTripSync();
  const mapRef = useRef<MapView>(null);
  const mounted = useRef(true);
  const busyRef = useRef(false);
  const placesRef = useRef(places);
  const geocodeBusyRef = useRef(false);
  const geocodeToken = useRef(0);
  const geocodeRequest = useRef<GeocodeRequest | null>(null);
  const [filter, setFilter] = useState<MapFilter>('all');
  const [selectedID, setSelectedID] = useState<string | null>(null);
  const [selectedDay, setSelectedDay] = useState<TripDay>(4);
  const [userCoordinate, setUserCoordinate] = useState<Coordinate | null>(null);
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState('');
  const [locationError, setLocationError] = useState('');
  const [geocodeBusy, setGeocodeBusy] = useState(false);
  const [geocodeChoices, setGeocodeChoices] = useState<GeocodeChoice[]>([]);
  const [geocodePlaceID, setGeocodePlaceID] = useState<string | null>(null);
  useEffect(() => { mounted.current = true; placesRef.current = places; }, [places]);
  useEffect(() => () => { mounted.current = false; geocodeToken.current += 1; }, []);

  const visible = useMemo(() => filterPlaces(places, filter), [places, filter]);
  const nearbyVisible = useMemo(() => sortNearby(visible, userCoordinate), [visible, userCoordinate]);
  const pins = useMemo(() => nearbyVisible.filter((place) => validCoordinate(place) !== null), [nearbyVisible]);
  const dayPlaces = useMemo(() => places.filter((place) => !place.deleted && place.franked && place.day === selectedDay).sort((a, b) => (a.dayOrder ?? 999) - (b.dayOrder ?? 999) || a.title.localeCompare(b.title, 'de')), [places, selectedDay]);
  const selected = selectedID ? places.find((place) => place.id === selectedID) ?? null : null;
  const hotel = useMemo(() => hotelCoordinate(places), [places]);
  const routePlaces = useMemo(() => dayPlaces.filter((place) => validCoordinate(place) !== null), [dayPlaces]);
  const missingDayPlaces = dayPlaces.filter((place) => validCoordinate(place) === null);
  const routeStages = useMemo(() => routeSegments(routePlaces, hotel), [routePlaces, hotel]);

  useEffect(() => {
    if (!pins.length) return;
    const coordinates = pins.flatMap((place) => { const coordinate = validCoordinate(place); return coordinate ? [coordinate] : []; });
    if (coordinates.length) mapRef.current?.fitToCoordinates(coordinates, { edgePadding: { top: 80, right: 40, bottom: 300, left: 40 }, animated: false });
  }, [pins]);

  const startBusy = () => { if (busyRef.current || !mounted.current) return false; busyRef.current = true; setBusy(true); return true; };
  const finishBusy = () => { busyRef.current = false; if (mounted.current) setBusy(false); };
  const currentAssignments = (nextPlaces = places): MapAssignment[] => {
    const groups = new Map<number, typeof places>();
    for (const day of TRIP_DAYS) groups.set(day, []);
    for (const place of nextPlaces) if (place.franked && !place.deleted && place.day !== null && groups.has(place.day)) groups.get(place.day)!.push(place);
    const result: MapAssignment[] = [];
    for (const day of TRIP_DAYS) {
      const list = groups.get(day)!.sort((a, b) => (a.dayOrder ?? 999) - (b.dayOrder ?? 999) || a.title.localeCompare(b.title, 'de'));
      list.forEach((place, index) => result.push({ id: place.id, day, dayOrder: index }));
    }
    for (const place of nextPlaces) if (place.franked && !place.deleted && place.day === null) result.push({ id: place.id, day: null, dayOrder: null });
    return result;
  };
  const mutateAssignments = async (nextPlaces: typeof places, visited?: Record<string, boolean>) => {
    if (!startBusy()) return;
    try {
      const fresh = await readMapSnapshot(db);
      if (fresh.tripID !== (tripID ?? '')) { await reload(); throw new Error('Die gemeinsame Reise ist veraltet. Bitte die Karte neu laden.'); }
      if (!mapSnapshotMatchesPlaces(fresh, places)) throw new Error('Die Kartenansicht ist veraltet. Bitte die Orte neu laden.');
      const changed = await applyMapPlan(db, fresh, currentAssignments(nextPlaces), visited);
      if (mounted.current) { await reload(); if (tripID) void syncNow(); setMessage(changed ? 'Tagesplan gespeichert.' : 'Keine Änderung nötig.'); }
    } catch (reason) { if (mounted.current) setMessage(reason instanceof Error ? reason.message : 'Die Kartenänderung konnte nicht gespeichert werden.'); }
    finally { finishBusy(); }
  };
  const reorder = (id: string, direction: -1 | 1) => {
    const list = [...dayPlaces];
    const index = list.findIndex((place) => place.id === id);
    const target = index + direction;
    if (index < 0 || target < 0 || target >= list.length) return;
    [list[index], list[target]] = [list[target], list[index]];
    const replacement = new Map(list.map((place) => [place.id, place]));
    void mutateAssignments(places.map((place) => replacement.get(place.id) ? { ...place, dayOrder: list.indexOf(replacement.get(place.id)!) } : place));
  };
  const moveDay = (id: string, day: TripDay | null) => void mutateAssignments(places.map((place) => place.id === id ? { ...place, day, dayOrder: null } : place));
  const toggleVisited = (id: string, visited: boolean) => void mutateAssignments(places, { [id]: visited });

  const requestLocation = async () => {
    if (!startBusy()) return;
    setLocationError('');
    try {
      const permission = await Location.requestForegroundPermissionsAsync();
      if (!mounted.current) return;
      if (permission.status !== 'granted') { setLocationError('Standortzugriff wurde abgelehnt. Die gespeicherten Kartenorte bleiben verfügbar.'); return; }
      const location = await currentPositionWithTimeout(10_000);
      if (!mounted.current) return;
      const coordinate = { latitude: location.coords.latitude, longitude: location.coords.longitude };
      if (!validCoordinate(coordinate)) throw new Error('Der Standort ist ungültig.');
      setUserCoordinate(coordinate);
      setMessage('Standort geladen; Orte sind nach Entfernung sortiert.');
    } catch (reason) { if (mounted.current) setLocationError(reason instanceof Error && reason.message === 'timeout' ? 'Standort konnte nicht rechtzeitig ermittelt werden.' : 'Standort konnte nicht geladen werden.'); }
    finally { finishBusy(); }
  };

  const searchPlace = async (placeID: string) => {
    if (busyRef.current || geocodeBusyRef.current || !mounted.current) return;
    const place = placesRef.current.find((item) => item.id === placeID);
    if (!place) return;
    const token = ++geocodeToken.current;
    geocodeBusyRef.current = true;
    setGeocodeBusy(true); setGeocodePlaceID(placeID); setGeocodeChoices([]); setMessage('Suche mögliche Kartenpositionen …');
    try {
      const requestedSnapshot = await readMapSnapshot(db);
      const identity = requestedSnapshot.places[placeID];
      if (!identity) throw new Error('Der Ort ist nicht mehr bestätigt.');
      geocodeRequest.current = { token, placeID, identity, snapshot: requestedSnapshot };
      if (Platform.OS === 'android') {
        const permission = await Location.requestForegroundPermissionsAsync();
        if (permission.status !== 'granted') { if (mounted.current) setMessage('Standortzugriff wurde für die Ortssuche abgelehnt.'); return; }
      }
      const query = `${place.address || place.title}, Prague, Czechia`;
      const result = await Location.geocodeAsync(query);
      if (!mounted.current || geocodeToken.current !== token || placesRef.current.find((item) => item.id === placeID)?.title !== place.title || placesRef.current.find((item) => item.id === placeID)?.address !== place.address || !mapSnapshotMatchesPlaces(requestedSnapshot, placesRef.current)) return;
      const choices = await Promise.all(result.filter((item) => validCoordinate({ latitude: item.latitude, longitude: item.longitude }) !== null).slice(0, 5).map(async (item) => {
        let label = `${item.latitude.toFixed(5)}, ${item.longitude.toFixed(5)}`;
        try {
          const addresses = await Location.reverseGeocodeAsync({ latitude: item.latitude, longitude: item.longitude });
          const address = addresses[0];
          label = [address?.name, address?.formattedAddress, address?.street].filter((value, index, all): value is string => typeof value === 'string' && value.length > 0 && all.indexOf(value) === index).join(', ') || label;
        } catch { /* Koordinaten bleiben als Auswahl sichtbar. */ }
        return { latitude: item.latitude, longitude: item.longitude, label };
      }));
      if (!mounted.current || geocodeToken.current !== token) return;
      setGeocodeChoices(choices);
      setMessage(choices.length ? 'Bitte die passende Position auswählen.' : 'Keine passende Position gefunden. Öffne den Ort zur bestätigten Suche.');
    } catch (reason) { if (mounted.current && geocodeToken.current === token) setMessage(reason instanceof Error ? reason.message : 'Ortssuche fehlgeschlagen. Öffne den Ort zur bestätigten Suche.'); }
    finally { if (geocodeToken.current === token) { geocodeBusyRef.current = false; if (mounted.current) setGeocodeBusy(false); } }
  };
  const choosePlace = async (choice: GeocodeChoice) => {
    const request = geocodeRequest.current;
    if (!request || request.placeID !== geocodePlaceID || request.token !== geocodeToken.current || !startBusy()) return;
    try {
      if (placesRef.current.find((item) => item.id === request.placeID)?.id !== request.placeID || !mapSnapshotMatchesPlaces(request.snapshot, placesRef.current)) throw new Error('Der Ort wurde geändert. Bitte neu suchen.');
      await setPlaceCoordinates(db, request.snapshot, request.placeID, choice);
      if (!mounted.current) return;
      setGeocodeChoices([]); setGeocodePlaceID(null); geocodeRequest.current = null;
      await reload();
      if (!mounted.current) return;
      if (tripID && !(await syncNow())) throw new Error('Position lokal gespeichert; gemeinsame Reise konnte nicht synchronisiert werden.');
      if (mounted.current) setMessage('Kartenposition gespeichert.');
    } catch (reason) { if (mounted.current) setMessage(reason instanceof Error ? reason.message : 'Kartenposition konnte nicht gespeichert werden.'); }
    finally { finishBusy(); }
  };
  const openWalkingRoute = async (segment: RoutePoint[], index: number) => {
    if (segment.length < 2 || !startBusy()) return;
    try {
      await Linking.openURL(googleWalkingURL(segment));
      if (mounted.current) setMessage(missingDayPlaces.length ? `Etappe ${index + 1} geöffnet. ${missingDayPlaces.length} Ort(e) ohne Kartenposition fehlen weiterhin.` : `Etappe ${index + 1} geöffnet.`);
    } catch { if (mounted.current) setMessage('Die Kartenroute konnte nicht geöffnet werden.'); }
    finally { finishBusy(); }
  };

  const filterLabel = (value: MapFilter) => value === 'all' ? 'Alle' : value === 'approved' ? 'Bestätigt' : value === 'visited' ? 'Besucht' : `Tag ${value.day}`;
  return <View style={styles.screen}>
    <MapView ref={mapRef} accessibilityLabel="Karte mit Reiseorten in Prag" initialRegion={pragueRegion} mapType="standard" style={styles.map}>
      {routePlaces.length > 1 && <Polyline coordinates={routePlaces.flatMap((place) => { const coordinate = validCoordinate(place); return coordinate ? [coordinate] : []; })} strokeColor={colors.red} strokeWidth={3} />}
      {userCoordinate && <Marker coordinate={userCoordinate} pinColor={colors.teal} title="Mein Standort" />}
      {pins.map((place) => { const coordinate = validCoordinate(place)!; return <Marker key={place.id} coordinate={coordinate} title={place.title} description={place.category} onPress={() => setSelectedID(place.id)} />; })}
    </MapView>
    <View style={styles.panel}><ScrollView style={styles.panelScroll} contentContainerStyle={styles.panelContent} nestedScrollEnabled>
      <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.filters}>{(['all', 'approved', 'visited'] as MapFilter[]).concat(TRIP_DAYS.map((day) => ({ day }))).map((value) => <Pressable key={typeof value === 'string' ? value : `day-${value.day}`} onPress={() => { setFilter(value); if (typeof value !== 'string') setSelectedDay(value.day); }} style={[styles.chip, sameMapFilter(filter, value) && styles.chipSelected]}><Text style={[styles.chipText, sameMapFilter(filter, value) && styles.chipSelectedText]}>{filterLabel(value)}</Text></Pressable>)}</ScrollView>
      <View style={styles.headerRow}><Text style={styles.title}>{visible.length} Orte · {filterLabel(filter)}</Text><Pressable disabled={busy} onPress={() => void requestLocation()} style={styles.locationButton}><Text style={styles.locationText}>◎ Standort</Text></Pressable></View>
      {!!locationError && <Text style={styles.warning}>{locationError}</Text>}
      {!!userCoordinate && <View style={styles.nearby}><Text style={styles.section}>In deiner Nähe</Text>{nearbyVisible.slice(0, 10).map((place) => { const coordinate = validCoordinate(place); return coordinate ? <Pressable key={`nearby-${place.id}`} onPress={() => setSelectedID(place.id)} style={styles.nearbyRow}><Text style={styles.stopTitle}>{place.title}</Text><Text style={styles.helper}>{Math.round(haversineMeters(userCoordinate, coordinate))} m · {place.category}</Text></Pressable> : null; })}</View>}
      {visible.length > pins.length && <Text style={styles.warning}>{visible.length - pins.length} Orte haben noch keine Kartenposition. Wähle die Position im Orteditor aus.</Text>}
      <Link href="/itinerary" asChild><Pressable style={styles.planLink}><Text style={styles.planText}>Tagesplanung öffnen ↗</Text></Pressable></Link>
      {selected && <View style={styles.detail}><Text style={styles.detailTitle}>{selected.title}</Text><Text style={styles.body}>{selected.category}{selected.address ? ` · ${selected.address}` : ''}</Text><View style={styles.rowButtons}><Link href={{ pathname: '/place/[id]', params: { id: selected.id } }} asChild><Pressable style={styles.smallButton}><Text style={styles.smallText}>Ort bearbeiten</Text></Pressable></Link>{selected.franked && <Pressable onPress={() => toggleVisited(selected.id, !selected.visited)} style={styles.smallButton}><Text style={styles.smallText}>{selected.visited ? 'Als offen markieren' : 'Als besucht markieren'}</Text></Pressable>}</View></View>}
      <Text style={styles.section}>Tag {selectedDay} · bestätigte Orte</Text>
      {dayPlaces.length === 0 && <Text style={styles.body}>Keine bestätigten Orte für diesen Tag.</Text>}
      {dayPlaces.map((place, index) => <View key={place.id} style={styles.stopRow}><Pressable style={styles.stopMain} onPress={() => setSelectedID(place.id)}><Text style={styles.stopTitle}>{index + 1}. {place.title}</Text><Text style={styles.helper}>{place.category} · {validCoordinate(place) ? 'Kartenposition vorhanden' : 'ohne Kartenposition'}</Text></Pressable><View style={styles.rowButtons}><Pressable accessibilityLabel={`${place.title} nach oben`} disabled={busy || index === 0} onPress={() => reorder(place.id, -1)}><Text style={styles.arrow}>↑</Text></Pressable><Pressable accessibilityLabel={`${place.title} nach unten`} disabled={busy || index === dayPlaces.length - 1} onPress={() => reorder(place.id, 1)}><Text style={styles.arrow}>↓</Text></Pressable><Pressable onPress={() => moveDay(place.id, null)} disabled={busy}><Text style={styles.remove}>×</Text></Pressable></View>{!validCoordinate(place) && <Pressable disabled={geocodeBusy || busy} onPress={() => void searchPlace(place.id)} style={styles.searchButton}><Text style={styles.smallText}>{geocodeBusy && geocodePlaceID === place.id ? 'Suche …' : 'Position suchen'}</Text></Pressable>}{geocodePlaceID === place.id && geocodeChoices.map((choice, choiceIndex) => <Pressable key={`${choice.latitude}-${choice.longitude}-${choiceIndex}`} onPress={() => void choosePlace(choice)} style={styles.choice}><Text style={styles.helper}>{choice.label}</Text><Text style={styles.smallText}>Diese Position auswählen</Text></Pressable>)}<ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.dayChoices}>{TRIP_DAYS.filter((day) => day !== selectedDay).map((day) => <Pressable key={day} disabled={busy} onPress={() => moveDay(place.id, day)} style={styles.dayChoice}><Text style={styles.helper}>Tag {day}</Text></Pressable>)}</ScrollView></View>)}
      {!!routeStages.length && <View style={styles.routeList}><Text style={styles.section}>Fußroute</Text>{routeStages.map((segment, index) => <Pressable key={`route-${index}`} disabled={busy} onPress={() => void openWalkingRoute(segment, index)} style={[styles.routeButton, busy && styles.disabled]}><Text style={styles.routeText}>Etappe {index + 1}: {segment[0].label} → {segment[segment.length - 1].label}</Text></Pressable>)}</View>}
      {!!message && <Text style={styles.status}>{message}</Text>}
    </ScrollView></View>
  </View>;
}

const styles = StyleSheet.create({ screen: { flex: 1 }, map: { flex: 1, minHeight: '40%' }, panel: { backgroundColor: colors.paper, borderTopColor: colors.rule, borderTopWidth: 1, height: '58%' }, panelScroll: { flex: 1 }, panelContent: { gap: 9, padding: 14, paddingBottom: 22 }, filters: { gap: 7, paddingVertical: 1 }, chip: { backgroundColor: colors.paperDeep, borderRadius: 18, justifyContent: 'center', minHeight: 34, paddingHorizontal: 12 }, chipSelected: { backgroundColor: colors.ink }, chipText: { color: colors.ink, fontSize: 12, fontWeight: '600' }, chipSelectedText: { color: colors.card }, headerRow: { alignItems: 'center', flexDirection: 'row', justifyContent: 'space-between' }, title: { color: colors.ink, flex: 1, fontFamily: 'Fraunces-SemiBold', fontSize: 21 }, locationButton: { borderColor: colors.teal, borderRadius: 18, borderWidth: 1, paddingHorizontal: 10, paddingVertical: 7 }, locationText: { color: colors.teal, fontSize: 12, fontWeight: '700' }, body: { color: colors.inkSoft, fontSize: 13, lineHeight: 18 }, warning: { color: colors.red, fontSize: 12, lineHeight: 17 }, planLink: { paddingVertical: 3 }, planText: { color: colors.red, fontSize: 13, fontWeight: '700' }, detail: { backgroundColor: colors.paperDeep, borderRadius: 14, gap: 4, padding: 11 }, detailTitle: { color: colors.ink, fontSize: 16, fontWeight: '700' }, section: { color: colors.ink, fontFamily: 'Fraunces-SemiBold', fontSize: 19 }, nearby: { backgroundColor: colors.paperDeep, borderRadius: 13, gap: 6, padding: 10 }, nearbyRow: { backgroundColor: colors.card, borderRadius: 9, padding: 8 }, stopRow: { backgroundColor: colors.card, borderColor: colors.rule, borderRadius: 12, borderWidth: 1, gap: 7, padding: 9 }, stopMain: { gap: 2 }, stopTitle: { color: colors.ink, fontSize: 14, fontWeight: '700' }, helper: { color: colors.inkSoft, fontSize: 12, lineHeight: 17 }, rowButtons: { alignItems: 'center', flexDirection: 'row', flexWrap: 'wrap', gap: 9 }, arrow: { color: colors.red, fontSize: 22, fontWeight: '700', paddingHorizontal: 5 }, remove: { color: colors.red, fontSize: 24 }, dayChoices: { gap: 6 }, dayChoice: { backgroundColor: colors.paperDeep, borderRadius: 14, paddingHorizontal: 9, paddingVertical: 5 }, searchButton: { alignSelf: 'flex-start', borderColor: colors.rule, borderRadius: 15, borderWidth: 1, paddingHorizontal: 10, paddingVertical: 6 }, choice: { backgroundColor: colors.paperDeep, borderRadius: 9, gap: 2, padding: 8 }, smallButton: { borderColor: colors.rule, borderRadius: 15, borderWidth: 1, paddingHorizontal: 9, paddingVertical: 6 }, smallText: { color: colors.ink, fontSize: 12, fontWeight: '700' }, routeList: { gap: 7 }, routeButton: { alignItems: 'center', borderColor: colors.red, borderRadius: 22, borderWidth: 1, justifyContent: 'center', minHeight: 43, paddingHorizontal: 8 }, routeText: { color: colors.red, fontSize: 12, fontWeight: '700', textAlign: 'center' }, disabled: { opacity: 0.55 }, status: { color: colors.teal, fontSize: 12, fontWeight: '700' }, });
