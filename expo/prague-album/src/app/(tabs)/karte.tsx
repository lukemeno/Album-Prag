import { useMemo, useState } from 'react';
import { ActivityIndicator, Linking, Platform, Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';
import MapView, { Marker, Polyline } from 'react-native-maps';
import * as Location from 'expo-location';
import { colors, fonts } from '@/domain/theme';
import { usePlaceStore } from '@/storage/place-store';

const pragueRegion = { latitude: 50.0875, longitude: 14.4213, latitudeDelta: 0.085, longitudeDelta: 0.085 };

export default function MapScreen() {
  const { places, setCoordinates } = usePlaceStore();
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState('');
  const [selectedDay, setSelectedDay] = useState(4);
  const pins = useMemo(() => places.filter((place) => !place.deleted && place.lat != null && place.lng != null), [places]);
  const planned = useMemo(() => places.filter((place) => !place.deleted && place.franked && place.day === selectedDay && place.lat != null && place.lng != null).sort((a, b) => (a.dayOrder ?? 999) - (b.dayOrder ?? 999)), [places, selectedDay]);

  const openWalkingRoute = () => {
    if (!planned.length) return;
    const ordered = planned.map((place) => `${place.lat},${place.lng}`);
    const origin = ordered[0];
    const destination = ordered[ordered.length - 1];
    const waypoints = ordered.slice(1, -1).join('|');
    const url = `https://www.google.com/maps/dir/?api=1&origin=${encodeURIComponent(origin)}&destination=${encodeURIComponent(destination)}${waypoints ? `&waypoints=${encodeURIComponent(waypoints)}` : ''}&travelmode=walking`;
    void Linking.openURL(url);
  };

  const geocodeNextPlaces = async () => {
    if (busy) return;
    setBusy(true);
    setMessage('Suche Orte in Prag …');
    let resolved = 0;
    let missed = 0;
    try {
      if (Platform.OS === 'android') {
        const permission = await Location.requestForegroundPermissionsAsync();
        if (permission.status !== 'granted') {
          setMessage('Für die Ortssuche ist unter Android der Standortzugriff nötig.');
          return;
        }
      }
      const candidates = places.filter((place) => !place.deleted && (place.lat == null || place.lng == null)).slice(0, 12);
      for (const place of candidates) {
        const query = `${place.address || place.title}, Prague, Czechia`;
        try {
          const results = await Location.geocodeAsync(query);
          if (results[0]) {
            await setCoordinates(place.id, results[0].latitude, results[0].longitude);
            resolved += 1;
          } else missed += 1;
        } catch {
          missed += 1;
        }
        await new Promise((resolve) => setTimeout(resolve, 350));
      }
      setMessage(`${resolved} Orte auf der Karte ergänzt${missed ? ` · ${missed} ohne Treffer` : ''}.`);
    } finally {
      setBusy(false);
    }
  };

  return (
    <View style={styles.screen}>
      <MapView accessibilityLabel="Karte mit Reiseorten in Prag" initialRegion={pragueRegion} mapType="standard" style={styles.map}>
        {planned.length > 1 && <Polyline coordinates={planned.map((place) => ({ latitude: place.lat!, longitude: place.lng! }))} strokeColor={colors.red} strokeWidth={3} />}
        {pins.map((place) => <Marker key={place.id} coordinate={{ latitude: place.lat!, longitude: place.lng! }} title={place.title} description={place.category} />)}
      </MapView>
      <View style={styles.panel}>
        <Text style={styles.title}>{pins.length} Orte auf der Karte · Tag {selectedDay}</Text>
        <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.days}>
          {[4, 5, 6, 7, 8, 9].map((day) => <Pressable key={day} onPress={() => setSelectedDay(day)} style={[styles.day, selectedDay === day && styles.daySelected]}><Text style={[styles.dayText, selectedDay === day && styles.dayTextSelected]}>{day}. Okt.</Text></Pressable>)}
        </ScrollView>
        <Text style={styles.body}>{planned.length ? `${planned.length} bestätigte Orte · verbunden in geplanter Reihenfolge.` : 'Noch keine bestätigten Orte für diesen Tag. Bestätigte Orte kannst du in der Ideenliste einem Tag zuordnen.'}</Text>
        {!!planned.length && <Pressable accessibilityRole="button" onPress={openWalkingRoute} style={styles.routeButton}><Text style={styles.routeButtonText}>Fußroute öffnen ↗</Text></Pressable>}
        <Pressable accessibilityRole="button" disabled={busy} onPress={() => void geocodeNextPlaces()} style={[styles.button, busy && styles.disabled]}>
          {busy ? <ActivityIndicator color={colors.card} /> : <Text style={styles.buttonText}>Nächste 12 Orte suchen</Text>}
        </Pressable>
        {!!message && <Text style={styles.status}>{message}</Text>}
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1 },
  map: { flex: 1 },
  panel: { backgroundColor: colors.card, borderTopLeftRadius: 26, borderTopRightRadius: 26, elevation: 8, gap: 11, marginTop: -20, padding: 18, paddingBottom: 20, shadowColor: colors.ink, shadowOpacity: 0.08, shadowRadius: 18, shadowOffset: { width: 0, height: -4 } },
  title: { color: colors.ink, fontFamily: fonts.display, fontSize: 21, lineHeight: 28 },
  body: { color: colors.inkSoft, fontSize: 13, lineHeight: 18 },
  button: { alignItems: 'center', backgroundColor: colors.red, borderRadius: 24, justifyContent: 'center', minHeight: 48, paddingHorizontal: 16 },
  disabled: { opacity: 0.6 },
  buttonText: { color: colors.card, fontWeight: '700' },
  status: { color: colors.teal, fontSize: 13 },
  days: { gap: 7, paddingVertical: 1 },
  day: { alignItems: 'center', backgroundColor: colors.paperDeep, borderRadius: 20, justifyContent: 'center', minHeight: 38, paddingHorizontal: 13 },
  daySelected: { backgroundColor: colors.ink },
  dayText: { color: colors.ink, fontSize: 12, fontWeight: '600' },
  dayTextSelected: { color: colors.card },
  routeButton: { alignItems: 'center', borderColor: colors.red, borderRadius: 22, borderWidth: 1, justifyContent: 'center', minHeight: 42 },
  routeButtonText: { color: colors.red, fontWeight: '700' },
});
