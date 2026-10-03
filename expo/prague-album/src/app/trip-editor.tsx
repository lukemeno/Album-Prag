import { useEffect, useState } from 'react';
import { ActivityIndicator, Pressable, ScrollView, StyleSheet, Text, TextInput, View } from 'react-native';
import { Stack } from 'expo-router';
import { useSQLiteContext } from 'expo-sqlite';
import { colors, space } from '@/domain/theme';
import { emptyTrip, type TripInfo } from '@/domain/trip';
import { readTripInfoSnapshot, saveTripInfo, type TripInfoSnapshot } from '@/storage/trip-info';
import { useTripSync } from '@/storage/trip-sync';

export default function TripEditorScreen() {
  const db = useSQLiteContext();
  const { tripID, syncNow } = useTripSync();
  const [trip, setTrip] = useState<TripInfo>(emptyTrip());
  const [snapshot, setSnapshot] = useState<TripInfoSnapshot | null>(null);
  const [busy, setBusy] = useState(false);
  const [status, setStatus] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  useEffect(() => { void readTripInfoSnapshot(db).then((next) => { setTrip(next.trip); setSnapshot(next); }).catch((reason: unknown) => setError(reason instanceof Error ? reason.message : 'Reise konnte nicht geladen werden.')); }, [db]);
  const update = (key: keyof TripInfo, value: string) => setTrip((current) => ({ ...current, [key]: value }));
  const save = async () => { if (busy || !snapshot) return; setBusy(true); setError(null); setStatus(null); try { const next = await saveTripInfo(db, trip, snapshot); const fresh = await readTripInfoSnapshot(db); setTrip(next); setSnapshot(fresh); if (tripID && !(await syncNow())) throw new Error('Die lokale Änderung wurde gespeichert, aber nicht synchronisiert.'); setStatus('Reiseinformationen gespeichert.'); } catch (reason) { setError(reason instanceof Error ? reason.message : 'Speichern fehlgeschlagen.'); } finally { setBusy(false); } };
  return <View style={styles.root}><Stack.Screen options={{ title: 'Reiseinformationen', headerLargeTitle: false }} /><ScrollView contentInsetAdjustmentBehavior="automatic" contentContainerStyle={styles.content}>
    <Text style={styles.eyebrow}>REISE</Text><Text style={styles.title}>Handy griffbereit</Text><Text style={styles.body}>Erkannte Angaben kannst du hier korrigieren. Es werden keine Orte automatisch angelegt.</Text>
    <Field label="Hotel" value={trip.hotel} onChangeText={(value) => update('hotel', value)} placeholder="Name der Unterkunft" /><Field label="Hinflug" value={trip.outbound} onChangeText={(value) => update('outbound', value)} placeholder="Datum und Abflugzeit" /><Field label="Ankunft" value={trip.arrival} onChangeText={(value) => update('arrival', value)} placeholder="Ankunftszeit" /><Field label="Flugnummer" value={trip.flightNumber} onChangeText={(value) => update('flightNumber', value)} placeholder="z. B. EW 1234" /><Field label="Route" value={trip.route} onChangeText={(value) => update('route', value)} placeholder="Köln → Prag" /><Field label="Buchungsnummer" value={trip.bookingNumber ?? ''} onChangeText={(value) => update('bookingNumber', value)} placeholder="Optional" /><Field label="Notizen" value={trip.notes} onChangeText={(value) => update('notes', value)} placeholder="Check-in, Gepäck …" multiline />
    {!!error && <View style={styles.error}><Text style={styles.body}>{error}</Text></View>}{!!status && <Text style={styles.success}>{status}</Text>}<Pressable accessibilityRole="button" disabled={busy} onPress={() => void save()} style={[styles.primary, busy && styles.disabled]}>{busy ? <ActivityIndicator color={colors.card} /> : <Text style={styles.primaryText}>Speichern</Text>}</Pressable>
  </ScrollView></View>;
}
function Field({ label, ...props }: { label: string; value: string; onChangeText: (value: string) => void; placeholder: string; multiline?: boolean }) { return <View style={styles.field}><Text style={styles.label}>{label}</Text><TextInput {...props} placeholderTextColor={colors.inkSoft} style={[styles.input, props.multiline && styles.multiline]} /></View>; }
const styles = StyleSheet.create({ root: { backgroundColor: colors.paper, flex: 1 }, content: { gap: 14, padding: space.page, paddingBottom: 52 }, eyebrow: { color: colors.red, fontSize: 12, fontWeight: '700', letterSpacing: 1.4 }, title: { color: colors.ink, fontFamily: 'Fraunces-SemiBold', fontSize: 30 }, body: { color: colors.inkSoft, fontSize: 14, lineHeight: 21 }, field: { gap: 6 }, label: { color: colors.ink, fontSize: 13, fontWeight: '700' }, input: { backgroundColor: colors.card, borderColor: colors.rule, borderRadius: 12, borderWidth: 1, color: colors.ink, minHeight: 45, paddingHorizontal: 12, paddingVertical: 10 }, multiline: { minHeight: 100, textAlignVertical: 'top' }, primary: { alignItems: 'center', backgroundColor: colors.red, borderRadius: 23, justifyContent: 'center', minHeight: 48 }, primaryText: { color: colors.card, fontWeight: '700' }, disabled: { opacity: 0.5 }, error: { backgroundColor: colors.card, borderColor: colors.red, borderRadius: 12, borderWidth: 1, padding: 12 }, success: { color: colors.teal, fontWeight: '700' } });
