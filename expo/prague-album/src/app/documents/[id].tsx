import { useCallback, useEffect, useState } from 'react';
import { ActivityIndicator, Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';
import { Stack, useLocalSearchParams } from 'expo-router';
import { useSQLiteContext } from 'expo-sqlite';
import { colors, space } from '@/domain/theme';
import { parseTripDocument, applyExtractedTrip, type ExtractedTrip } from '@/domain/trip-document-parser';
import { readTripInfoSnapshot, saveTripInfo } from '@/storage/trip-info';
import { getLocalDocumentFile, importPDF, readTravelDocuments, shareDocument, updateExtractedText } from '@/storage/travel-documents';
import { DocumentReader } from '@/components/document-reader';
import { useTripSync } from '@/storage/trip-sync';
import type { TravelDocument, TripInfo } from '@/domain/trip';

export default function DocumentDetailScreen() {
  const db = useSQLiteContext();
  const params = useLocalSearchParams<{ id: string }>();
  const { tripID, syncNow } = useTripSync();
  const id = decodeURIComponent(String(params.id ?? ''));
  const [document, setDocument] = useState<TravelDocument | null>(null);
  const [fileURI, setFileURI] = useState<string | null>(null);
  const [mode, setMode] = useState<'original' | 'text' | 'extract'>('original');
  const [text, setText] = useState('');
  const [extracted, setExtracted] = useState<ExtractedTrip | null>(null);
  const [trip, setTrip] = useState<TripInfo | null>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const load = useCallback(async () => { const docs = await readTravelDocuments(db); const found = docs.find((item) => item.id === id) ?? null; setDocument(found); setText(found?.extractedText ?? ''); const file = found ? await getLocalDocumentFile(db, found.id) : null; setFileURI(file?.uri ?? null); if (found && !file) setMode('text'); }, [db, id]);
  useEffect(() => { let active = true; void readTravelDocuments(db).then(async (docs) => { if (!active) return; const found = docs.find((item) => item.id === id) ?? null; setDocument(found); setText(found?.extractedText ?? ''); const file = found ? await getLocalDocumentFile(db, found.id) : null; if (!active) return; setFileURI(file?.uri ?? null); if (found && !file) setMode('text'); }).catch((reason: unknown) => { if (active) setError(reason instanceof Error ? reason.message : 'Dokument konnte nicht geladen werden.'); }); return () => { active = false; }; }, [db, id]);

  const onText = (value: string) => { setText(value); void updateExtractedText(db, id, value).then(() => load()).catch((reason: unknown) => setError(reason instanceof Error ? reason.message : 'Text konnte nicht gespeichert werden.')); };
  const recognize = () => { if (!text.trim()) return; setError(null); setExtracted(parseTripDocument(text)); };
  const apply = async () => {
    if (!extracted || busy) return;
    setBusy(true); setError(null);
    try {
      const before = await readTripInfoSnapshot(db);
      const next = applyExtractedTrip(before.trip, extracted);
      const fresh = await readTripInfoSnapshot(db);
      if (fresh.raw !== before.raw || fresh.albumID !== before.albumID || fresh.tripID !== before.tripID) throw new Error('Die Reiseinformationen wurden inzwischen geändert. Bitte die Erkennung erneut prüfen.');
      const saved = await saveTripInfo(db, next, before);
      if (tripID && !(await syncNow())) throw new Error('Die Reise konnte nicht synchronisiert werden. Die lokale Übernahme bleibt erhalten.');
      setTrip(saved); setExtracted(null);
    } catch (reason) { setError(reason instanceof Error ? reason.message : 'Reiseinformationen konnten nicht übernommen werden.'); } finally { setBusy(false); }
  };
  const loadTrip = async () => { try { setTrip((await readTripInfoSnapshot(db)).trip); } catch (reason) { setError(reason instanceof Error ? reason.message : 'Reiseinformationen konnten nicht geladen werden.'); } };

  if (!document) return <View style={styles.root}><Stack.Screen options={{ title: 'Dokument', headerLargeTitle: false }} /><ActivityIndicator color={colors.red} style={styles.loader} /></View>;
  return <View style={styles.root}><Stack.Screen options={{ title: document.name, headerLargeTitle: false }} /><ScrollView contentInsetAdjustmentBehavior="automatic" contentContainerStyle={styles.content}>
    <View style={styles.header}><Text style={styles.title}>{document.name}</Text><Text style={styles.helper}>{document.originalAvailable ? 'Original lokal gespeichert' : 'Original nicht auf diesem Gerät verfügbar'}</Text></View>
    <View style={styles.tabs}>{fileURI && <Pressable accessibilityRole="button" onPress={() => setMode('original')} style={[styles.tab, mode === 'original' && styles.activeTab]}><Text style={styles.tabText}>Original</Text></Pressable>}<Pressable accessibilityRole="button" onPress={() => setMode('text')} style={[styles.tab, mode === 'text' && styles.activeTab]}><Text style={styles.tabText}>Text</Text></Pressable></View>
    {mode === 'original' && fileURI ? <View style={styles.reader}><DocumentReader key={`${fileURI}-original`} uri={fileURI} mode="original" onError={setError} /></View> : <View style={styles.textCard}>{text ? <Text selectable style={styles.documentText}>{text}</Text> : <Text style={styles.body}>Noch kein Text ausgelesen. Das Original bleibt für die Anzeige und zum Teilen verfügbar.</Text>}{fileURI && <Pressable onPress={() => setMode('text')} style={styles.secondary}><Text style={styles.secondaryText}>Text anzeigen</Text></Pressable>}</View>}
    {fileURI && <Pressable accessibilityRole="button" disabled={busy} onPress={() => setMode('extract')} style={styles.secondary}><Text style={styles.secondaryText}>Text aus PDF auslesen</Text></Pressable>}
    {!fileURI && <Pressable accessibilityRole="button" disabled={busy} onPress={() => void importPDF(db, text, id).then(() => load()).catch((reason: unknown) => setError(reason instanceof Error ? reason.message : 'Original konnte nicht importiert werden.'))} style={styles.secondary}><Text style={styles.secondaryText}>Original für diese Unterlage importieren</Text></Pressable>}
    {mode === 'extract' && fileURI && <View style={styles.reader}><DocumentReader key={`${fileURI}-extract`} uri={fileURI} mode="extract" onText={onText} onError={setError} /></View>}
    <View style={styles.actions}><Pressable accessibilityRole="button" onPress={() => void shareDocument(db, id).catch((reason: unknown) => setError(reason instanceof Error ? reason.message : 'Teilen nicht möglich.'))} style={styles.secondary}><Text style={styles.secondaryText}>Original teilen</Text></Pressable><Pressable accessibilityRole="button" onPress={recognize} disabled={!text.trim()} style={[styles.primary, !text.trim() && styles.disabled]}><Text style={styles.primaryText}>Reiseinfos erkennen</Text></Pressable><Pressable accessibilityRole="button" onPress={() => void loadTrip()} style={styles.secondary}><Text style={styles.secondaryText}>Reiseinfos anzeigen</Text></Pressable></View>
    {!!error && <View style={styles.error}><Text style={styles.body}>{error}</Text></View>}{trip && <TripSummary trip={trip} />}{extracted && <View style={styles.preview}><Text style={styles.section}>Erkannte Angaben prüfen</Text>{extracted.flights.map((flight) => <Text style={styles.body} key={`${flight.direction}-${flight.number}`}>{flight.direction === 'outbound' ? 'Hinflug' : 'Rückflug'}: {flight.number}, {flight.date}, {flight.departure}–{flight.arrival}, {flight.from} → {flight.to}</Text>)}{!!extracted.hotelDetails.name && <Text style={styles.body}>Hotel: {extracted.hotelDetails.name}{extracted.hotelDetails.address ? ` · ${extracted.hotelDetails.address}` : ''}</Text>}{!!extracted.bookingNumber && <Text style={styles.body}>Buchung: {extracted.bookingNumber}</Text>}{!!extracted.travelers.length && <Text style={styles.body}>Reisende: {extracted.travelers.join(', ')}</Text>}{!!extracted.notes.length && <Text style={styles.body}>{extracted.notes.join('\n')}</Text>}<Pressable accessibilityRole="button" disabled={busy} onPress={() => void apply()} style={[styles.primary, busy && styles.disabled]}><Text style={styles.primaryText}>{busy ? 'Übernahme …' : 'Geprüfte Angaben übernehmen'}</Text></Pressable></View>}
  </ScrollView></View>;
}
function TripSummary({ trip }: { trip: TripInfo }) { return <View style={styles.preview}><Text style={styles.section}>Reiseinformationen</Text><Text style={styles.body}>Hotel: {trip.hotel || 'nicht eingetragen'}</Text><Text style={styles.body}>Flug: {trip.flightNumber || 'nicht eingetragen'} · {trip.route || 'Route nicht eingetragen'}</Text><Text style={styles.body}>{trip.outbound || 'Hinflug nicht eingetragen'} – {trip.arrival || 'Ankunft nicht eingetragen'}</Text>{trip.bookingNumber && <Text style={styles.body}>Buchung: {trip.bookingNumber}</Text>}</View>; }
const styles = StyleSheet.create({ root: { backgroundColor: colors.paper, flex: 1 }, content: { gap: 13, padding: space.page, paddingBottom: 52 }, loader: { flex: 1 }, header: { gap: 4 }, title: { color: colors.ink, fontFamily: 'Fraunces-SemiBold', fontSize: 28 }, helper: { color: colors.inkSoft, fontSize: 12 }, tabs: { flexDirection: 'row', gap: 8 }, tab: { borderColor: colors.rule, borderRadius: 18, borderWidth: 1, paddingHorizontal: 14, paddingVertical: 8 }, activeTab: { backgroundColor: colors.paperDeep, borderColor: colors.red }, tabText: { color: colors.ink, fontWeight: '700' }, reader: { height: 430, overflow: 'hidden' }, textCard: { backgroundColor: colors.card, borderRadius: 14, gap: 10, maxHeight: 430, padding: 14 }, documentText: { color: colors.ink, fontSize: 13, lineHeight: 19 }, body: { color: colors.inkSoft, fontSize: 14, lineHeight: 21 }, actions: { gap: 9 }, primary: { alignItems: 'center', backgroundColor: colors.red, borderRadius: 23, justifyContent: 'center', minHeight: 46, paddingHorizontal: 12 }, primaryText: { color: colors.card, fontSize: 14, fontWeight: '700' }, secondary: { alignItems: 'center', borderColor: colors.red, borderRadius: 23, borderWidth: 1, justifyContent: 'center', minHeight: 44, paddingHorizontal: 12 }, secondaryText: { color: colors.red, fontSize: 14, fontWeight: '700' }, disabled: { opacity: 0.45 }, error: { backgroundColor: colors.card, borderColor: colors.red, borderRadius: 12, borderWidth: 1, padding: 12 }, preview: { backgroundColor: colors.paperDeep, borderRadius: 16, gap: 8, padding: 15 }, section: { color: colors.ink, fontFamily: 'Fraunces-SemiBold', fontSize: 21 } });
