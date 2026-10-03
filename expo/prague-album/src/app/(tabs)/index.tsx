import { Link } from 'expo-router';
import { Alert, Pressable, ScrollView, StyleSheet, Text, TextInput, View } from 'react-native';
import * as Clipboard from 'expo-clipboard';
import { colors, space } from '@/domain/theme';
import { usePlaceStore } from '@/storage/place-store';
import { showSyncError, useTripSync } from '@/storage/trip-sync';
import { useEffect, useMemo, useState } from 'react';
import { useSQLiteContext } from 'expo-sqlite';
import * as DocumentPicker from 'expo-document-picker';
import * as Sharing from 'expo-sharing';
import { File, Paths } from 'expo-file-system';
import { exportAlbum, importAlbum } from '@/storage/album-transfer';
import { readTripInfo } from '@/storage/trip-info';
import { emptyTrip, type TripInfo } from '@/domain/trip';
import { myDecision } from '@/domain/place-decisions';
import { SymbolView } from 'expo-symbols';

export default function TripScreen() {
  const { places, memberName, renameMember, reload } = usePlaceStore();
  const { tripID, inviteToken, status, revision, createTrip, joinTrip, syncNow, reloadTripInfo } = useTripSync();
  const db = useSQLiteContext();
  const [nameDraft, setName] = useState<string | null>(null);
  const name = nameDraft ?? memberName;
  const [token, setToken] = useState('');
  const [documents, setDocuments] = useState<{ id: string; name: string; extractedText: string }[]>([]);
  const [tripInfo, setTripInfo] = useState<TripInfo>(emptyTrip());
  const [selectedDay, setSelectedDay] = useState(getCurrentTripDay);
  const [shareSettingsY, setShareSettingsY] = useState(0);
  const [scrollView, setScrollView] = useState<ScrollView | null>(null);

  useEffect(() => {
    let active = true;
    void readTripInfo(db).then((value) => { if (active) setTripInfo(value); });
    return () => { active = false; };
  }, [db, revision]);

  useEffect(() => {
    let active = true;
    db.getAllAsync<{ payload_json: string }>('SELECT payload_json FROM trip_documents ORDER BY updated_at DESC')
      .then((rows) => { if (active) setDocuments(rows.map(({ payload_json }) => JSON.parse(payload_json) as { id: string; name: string; extractedText: string })); });
    return () => { active = false; };
  }, [db, revision]);

  const dayPlaces = useMemo(() => places.filter((place) => !place.deleted && place.day === selectedDay).sort((a, b) => (a.dayOrder ?? 0) - (b.dayOrder ?? 0)), [places, selectedDay]);
  const assignedFlights = useMemo(() => tripInfo.flights?.filter((flight) => !flight.date.startsWith(`${String(selectedDay).padStart(2, '0')}.10.`)) ?? [], [selectedDay, tripInfo.flights]);
  const now = new Date();
  const beforeTrip = now < new Date(2026, 9, 4);
  const afterTrip = now > new Date(2026, 9, 9, 23, 59);
  const daysUntilStart = Math.ceil((new Date(2026, 9, 4).getTime() - new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime()) / 86_400_000);
  const partner = places.flatMap((place) => [place.author, ...place.approvals]).find((person) => person && person !== memberName && person.toLocaleLowerCase('de') !== 'wir');
  const tripSubtitle = [
    '4.–9. Oktober',
    beforeTrip ? daysUntilStart > 1 ? `noch ${daysUntilStart} Tage` : 'morgen geht’s los' : afterTrip ? '6 Tage in Prag' : `Tag ${now.getDate() - 3} von 6`,
    ...(partner ? [`mit ${partner}`] : []),
  ].join(' · ');
  const dayTitle = ['Sonntag', 'Montag', 'Dienstag', 'Mittwoch', 'Donnerstag', 'Freitag'][selectedDay - 4];

  return (
    <ScrollView ref={setScrollView} contentInsetAdjustmentBehavior="automatic" contentContainerStyle={styles.content}>
      <View style={styles.homeHeader}>
        <View style={styles.headingCopy}>
          <Text style={styles.title}>Prag</Text>
          <Text style={styles.subtitle}>{tripSubtitle}</Text>
        </View>
        <View style={styles.headerActions}>
          <Link href="/place/new" asChild><Pressable accessibilityRole="button" accessibilityLabel="Idee einwerfen" style={styles.shareButton}><SymbolView name="plus" size={18} weight="semibold" tintColor={colors.red} /></Pressable></Link>
          <Pressable accessibilityRole="button" accessibilityLabel="Gemeinsame Reise verwalten" onPress={() => scrollView?.scrollTo({ y: shareSettingsY, animated: true })} style={styles.shareButton}>
            <SymbolView name="person.2.fill" size={18} weight="medium" tintColor={colors.red} />
          </Pressable>
        </View>
      </View>
      <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.dayStrip}>
        {[4, 5, 6, 7, 8, 9].map((day, index) => {
          const active = day === selectedDay;
          const labels = ['So', 'Mo', 'Di', 'Mi', 'Do', 'Fr'];
          return <Pressable accessibilityRole="button" accessibilityState={{ selected: active }} key={day} onPress={() => setSelectedDay(day)} style={[styles.dayChip, active && styles.dayChipSelected]}>
            <Text style={[styles.dayWeek, active && styles.dayTextSelected]}>{labels[index]}</Text>
            <Text style={[styles.dayNumber, active && styles.dayTextSelected]}>{day}</Text>
            <Text style={[styles.dayMonth, active && styles.dayTextSelected]}>OKT</Text>
          </Pressable>;
        })}
      </ScrollView>
      <View style={styles.sectionHead}>
        <Text style={styles.section}>{selectedDay === now.getDate() && !beforeTrip && !afterTrip ? 'Heute' : dayTitle}</Text>
        <Link href="/itinerary" asChild><Pressable><Text style={styles.inlineLink}>Planen</Text></Pressable></Link>
      </View>
      <Text style={styles.dayDate}>{selectedDay}. Oktober 2026 · {dayPlaces.length} {dayPlaces.length === 1 ? 'Ort' : 'Orte'}</Text>
      {selectedDay === 4 && !!tripInfo.outbound && <TicketRow symbol="airplane" title="Anreise" detail={`${tripInfo.flightNumber || 'Flug'} · ${tripInfo.outbound}${tripInfo.arrival ? ` – ${tripInfo.arrival}` : ''}`} />}
      {dayPlaces.length ? dayPlaces.map((place, index) => <View key={place.id} style={styles.stopRow}>
        <View style={styles.stopRail}><View style={styles.stopDot}><Text style={styles.stopIndex}>{index + 1}</Text></View>{index < dayPlaces.length - 1 && <View style={styles.stopLine} />}</View>
        <View style={styles.stopCopy}><Text style={styles.stopTitle}>{place.title}</Text><Text style={styles.stopDetail}>{place.category}{place.visited ? ' · Besucht' : ''}</Text></View>
        <Link href={{ pathname: '/place/[id]', params: { id: place.id } }} asChild><Pressable style={styles.rowChevron}><Text style={styles.chevron}>›</Text></Pressable></Link>
      </View>) : <View style={styles.emptyPlan}><Text style={styles.emptyTitle}>Noch nichts geplant</Text><Link href="/(tabs)/karte" asChild><Pressable><Text style={styles.inlineLink}>Orte auf der Karte planen  ›</Text></Pressable></Link></View>}
      <View style={styles.sectionHead}><Text style={styles.section}>Unterlagen</Text><Link href="/documents" asChild><Pressable><Text style={styles.inlineLink}>Alle</Text></Pressable></Link></View>
      {assignedFlights.length ? assignedFlights.map((flight) => <TicketRow key={`${flight.direction}-${flight.number}`} symbol="airplane" title={flight.number || 'Flug'} detail={`${flight.date} · ${flight.from} → ${flight.to}`} />) : !tripInfo.flights?.length && <Link href="/documents" asChild><Pressable><TicketRow symbol="airplane" title="Flüge hinzufügen" detail="Das Album liest Buchungs-PDFs automatisch." /></Pressable></Link>}
      <Link href="/documents" asChild><Pressable><TicketRow symbol="bed.double" title={tripInfo.hotel || 'Unterkunft hinzufügen'} detail={tripInfo.hotelDetails?.checkIn ? `Check-in ab ${tripInfo.hotelDetails.checkIn}` : 'Unterkunft und Buchung'} /></Pressable></Link>
      {!!places.filter((place) => !place.deleted && myDecision(place, memberName) === 'open').length && <Link href="/(tabs)/ideen" asChild><Pressable style={styles.waitingCard}><Text style={styles.waitingTitle}>{places.filter((place) => !place.deleted && myDecision(place, memberName) === 'open').length} Ideen warten</Text><Text style={styles.waitingSubtitle}>Ja, Nein oder Offen</Text><Text style={styles.chevron}>›</Text></Pressable></Link>}
      {afterTrip && <Link href="/memories" asChild><Pressable style={styles.memoriesLink}><Text style={styles.inlineLink}>Erinnerungen ansehen  ›</Text></Pressable></Link>}
      <View onLayout={(event) => setShareSettingsY(event.nativeEvent.layout.y)} style={styles.card}>
        <Text style={styles.section}>Eure gemeinsame Reise</Text>
        <Text style={styles.body}>{status}</Text>
        <TextInput accessibilityLabel="Dein Name für gemeinsame Abstimmungen" onChangeText={setName} placeholder="Dein Name" placeholderTextColor={colors.inkSoft} style={styles.input} value={name} />
        <Pressable onPress={() => void renameMember(name)} style={styles.secondaryButton}><Text style={styles.secondaryText}>Name speichern</Text></Pressable>
        {tripID ? (
          <>
            <Text style={styles.tripCode}>Verbunden</Text>
            <Pressable onPress={() => void syncNow()} style={styles.primaryButton}><Text style={styles.primaryText}>Jetzt synchronisieren</Text></Pressable>
            {!!inviteToken && <Pressable onPress={() => void Clipboard.setStringAsync(inviteToken).then(() => Alert.alert('Einladung kopiert', 'Sende den Einladungscode an die zweite Person.'))} style={styles.secondaryButton}><Text style={styles.secondaryText}>Einladungscode kopieren</Text></Pressable>}
          </>
        ) : (
          <>
            <Pressable onPress={() => void createTrip().then((created) => {
              if (created) Alert.alert('Reise erstellt', 'Kopiere den Einladungscode mit dem entsprechenden Button und sende ihn an die zweite Person.');
            }).catch(showSyncError)} style={styles.primaryButton}><Text style={styles.primaryText}>Gemeinsame Reise erstellen</Text></Pressable>
            <Text style={styles.helper}>Oder mit dem Einladungscode der anderen Person verbinden:</Text>
            <TextInput accessibilityLabel="Einladungscode" autoCapitalize="none" onChangeText={setToken} placeholder="Einladungscode" placeholderTextColor={colors.inkSoft} style={styles.input} value={token} />
            <Pressable onPress={() => void joinTrip(token).then(() => setToken('')).catch(showSyncError)} style={styles.secondaryButton}><Text style={styles.secondaryText}>Reise beitreten</Text></Pressable>
          </>
        )}
      </View>
      <View style={styles.card}>
        <Text style={styles.section}>Album übertragen</Text>
        <Text style={styles.body}>Exportiere die Ideen aus der bisherigen App als JSON und importiere die Datei hier. Orte werden anhand ihrer IDs abgeglichen.</Text>
        <Pressable onPress={() => void (async () => {
          const file = new File(Paths.cache, 'prag-album-export.json');
          file.create({ overwrite: true });
          file.write(JSON.stringify(await exportAlbum(db), null, 2));
          if (await Sharing.isAvailableAsync()) await Sharing.shareAsync(file.uri, { mimeType: 'application/json', dialogTitle: 'Prag-Album exportieren' });
          else Alert.alert('Export erstellt', file.uri);
        })().catch(showSyncError)} style={styles.secondaryButton}><Text style={styles.secondaryText}>Album exportieren</Text></Pressable>
        <Pressable onPress={() => void (async () => {
          const result = await DocumentPicker.getDocumentAsync({ type: ['application/json', 'public.json'], copyToCacheDirectory: true });
          if (result.canceled) return;
          const file = new File(result.assets[0].uri);
          const count = await importAlbum(db, JSON.parse(await file.text()) as unknown);
          await reload();
          await reloadTripInfo();
          const restoredDocuments = await db.getAllAsync<{ payload_json: string }>('SELECT payload_json FROM trip_documents ORDER BY updated_at DESC');
          setDocuments(restoredDocuments.map(({ payload_json }) => JSON.parse(payload_json) as { id: string; name: string; extractedText: string }));
          Alert.alert('Import abgeschlossen', `${count} Orte wurden übernommen. Verbinde die gemeinsame Reise bei Bedarf über den Einladungscode.`);
        })().catch(showSyncError)} style={styles.secondaryButton}><Text style={styles.secondaryText}>JSON-Backup importieren</Text></Pressable>
      </View>
      {!!documents.length && <View style={styles.card}>
        <Text style={styles.section}>Reiseunterlagen</Text>
        <Link href="/documents" asChild><Pressable style={styles.secondaryButton}><Text style={styles.secondaryText}>Unterlagen öffnen</Text></Pressable></Link>
        {documents.map((document) => <View key={document.id} style={styles.document}>
          <Text style={styles.documentName}>{document.name}</Text>
          <Text selectable style={styles.body}>{document.extractedText || 'Kein Textauszug verfügbar.'}</Text>
          <Text style={styles.helper}>Legacy-Unterlage: Der Textauszug ist übernommen; ein Original ist nur verfügbar, wenn es hier separat importiert wurde.</Text>
        </View>)}
      </View>}
    </ScrollView>
  );
}

function TicketRow({ symbol, title, detail }: { symbol: 'airplane' | 'bed.double'; title: string; detail: string }) {
  return <View style={styles.ticket}>
    <View style={styles.ticketIcon}><SymbolView name={symbol} size={18} weight="medium" tintColor={colors.teal} /></View>
    <View style={styles.ticketCopy}><Text numberOfLines={1} style={styles.ticketTitle}>{title}</Text><Text numberOfLines={2} style={styles.ticketDetail}>{detail}</Text></View>
    <Text style={styles.chevron}>›</Text>
  </View>;
}

function getCurrentTripDay(): number {
  const today = new Date();
  if (today < new Date(2026, 9, 4)) return 4;
  if (today > new Date(2026, 9, 9, 23, 59)) return 9;
  return today.getDate();
}

const styles = StyleSheet.create({
  content: { gap: space.medium, padding: space.page, paddingBottom: 190 },
  homeHeader: { alignItems: 'flex-start', flexDirection: 'row', justifyContent: 'space-between', marginBottom: 1 },
  headingCopy: { flex: 1, gap: 1 },
  headerActions: { flexDirection: 'row', gap: 8 },
  eyebrow: { color: colors.red, fontSize: 12, fontWeight: '700', letterSpacing: 1.5 },
  title: { color: colors.ink, fontFamily: 'Fraunces-SemiBold', fontSize: 48, fontWeight: '600', letterSpacing: -1.3, marginTop: -8 },
  subtitle: { color: colors.inkSoft, fontSize: 14, marginTop: -space.small },
  shareButton: { alignItems: 'center', backgroundColor: colors.card, borderColor: colors.rule, borderRadius: 22, borderWidth: 1, height: 44, justifyContent: 'center', marginTop: 5, width: 44 },
  shareIcon: { color: colors.red, fontSize: 21, fontWeight: '500' },
  dayStrip: { gap: 8, paddingBottom: 2, paddingTop: 3 },
  dayChip: { alignItems: 'center', backgroundColor: colors.card, borderColor: colors.rule, borderRadius: 16, borderWidth: 1, gap: 3, minWidth: 51, paddingHorizontal: 9, paddingVertical: 10 },
  dayChipSelected: { backgroundColor: colors.red, borderColor: colors.red, minWidth: 57, paddingVertical: 12 },
  dayWeek: { color: colors.inkSoft, fontSize: 11, fontWeight: '600' },
  dayNumber: { color: colors.ink, fontFamily: 'Fraunces-SemiBold', fontSize: 21, lineHeight: 23 },
  dayMonth: { color: colors.inkSoft, fontSize: 9, fontWeight: '700', letterSpacing: 1 },
  dayTextSelected: { color: '#FFFFFF' },
  sectionHead: { alignItems: 'center', flexDirection: 'row', justifyContent: 'space-between', marginTop: 5 },
  dayDate: { color: colors.inkSoft, fontSize: 13, marginTop: -space.medium },
  inlineLink: { color: colors.red, fontSize: 14, fontWeight: '600' },
  stopRow: { alignItems: 'stretch', flexDirection: 'row', gap: 12, minHeight: 58 },
  stopRail: { alignItems: 'center', width: 30 },
  stopDot: { alignItems: 'center', backgroundColor: colors.teal, borderRadius: 14, height: 28, justifyContent: 'center', width: 28 },
  stopIndex: { color: '#FFFFFF', fontSize: 12, fontWeight: '700' },
  stopLine: { backgroundColor: colors.rule, flex: 1, marginVertical: 3, width: 1 },
  stopCopy: { backgroundColor: colors.card, borderColor: colors.rule, borderRadius: 14, borderWidth: 1, flex: 1, justifyContent: 'center', paddingHorizontal: 13, paddingVertical: 9 },
  stopTitle: { color: colors.ink, fontFamily: 'InstrumentSerif-Regular', fontSize: 20, lineHeight: 24 },
  stopDetail: { color: colors.inkSoft, fontSize: 12, marginTop: 2 },
  rowChevron: { alignItems: 'center', justifyContent: 'center', width: 22 },
  chevron: { color: colors.inkSoft, fontSize: 24 },
  emptyPlan: { backgroundColor: colors.card, borderColor: colors.rule, borderRadius: 16, borderWidth: 1, gap: 6, padding: 16 },
  emptyTitle: { color: colors.ink, fontSize: 15, fontWeight: '700' },
  ticket: { alignItems: 'center', backgroundColor: colors.card, borderColor: colors.rule, borderRadius: 16, borderWidth: 1, flexDirection: 'row', gap: 12, minHeight: 68, paddingHorizontal: 12, paddingVertical: 10 },
  ticketIcon: { alignItems: 'center', backgroundColor: colors.paperDeep, borderRadius: 12, height: 42, justifyContent: 'center', width: 42 },
  ticketSymbol: { color: colors.teal, fontSize: 20 },
  ticketCopy: { flex: 1, gap: 3 },
  ticketTitle: { color: colors.ink, fontSize: 14, fontWeight: '700' },
  ticketDetail: { color: colors.inkSoft, fontSize: 12, lineHeight: 17 },
  waitingCard: { backgroundColor: colors.card, borderColor: colors.rule, borderRadius: 15, borderWidth: 1, gap: 3, padding: 14 },
  waitingTitle: { color: colors.ink, fontSize: 15, fontWeight: '700' },
  waitingSubtitle: { color: colors.inkSoft, fontSize: 13 },
  memoriesLink: { alignItems: 'center', paddingVertical: 12 },
  feature: { backgroundColor: colors.card, borderColor: colors.rule, borderRadius: 18, borderWidth: 1, gap: 6, padding: 18 },
  featureKicker: { color: colors.red, fontSize: 12, fontWeight: '700', letterSpacing: 1.4 },
  featureCount: { color: colors.ink, fontFamily: 'Fraunces-SemiBold', fontSize: 36, fontWeight: '600' },
  featureText: { color: colors.inkSoft, fontSize: 14, lineHeight: 20 },
  featureAction: { color: colors.red, fontSize: 14, fontWeight: '600', marginTop: 4 },
  assistantLink: { backgroundColor: colors.paperDeep, borderColor: colors.rule, borderRadius: 18, borderWidth: 1, gap: 6, padding: 17 },
  assistantTitle: { color: colors.ink, fontFamily: 'Fraunces-SemiBold', fontSize: 23, fontWeight: '600', lineHeight: 29 },
  card: { backgroundColor: colors.paperDeep, borderRadius: 18, gap: 8, padding: 20 },
  section: { color: colors.ink, fontFamily: 'Fraunces-SemiBold', fontSize: 22 },
  body: { color: colors.inkSoft, fontSize: 15, lineHeight: 22 },
  input: { backgroundColor: colors.card, borderColor: colors.rule, borderRadius: 12, borderWidth: 1, color: colors.ink, minHeight: 46, paddingHorizontal: 13 },
  primaryButton: { alignItems: 'center', backgroundColor: colors.red, borderRadius: 25, justifyContent: 'center', minHeight: 48, paddingHorizontal: 17 },
  primaryText: { color: colors.card, fontSize: 15, fontWeight: '700' },
  secondaryButton: { alignItems: 'center', borderColor: colors.rule, borderRadius: 25, borderWidth: 1, justifyContent: 'center', minHeight: 45, paddingHorizontal: 15 },
  secondaryText: { color: colors.ink, fontSize: 14, fontWeight: '600' },
  helper: { color: colors.inkSoft, fontSize: 13, lineHeight: 19 },
  tripCode: { color: colors.teal, fontWeight: '700' },
  document: { borderTopColor: colors.rule, borderTopWidth: 1, gap: 7, paddingTop: 12 },
  documentName: { color: colors.ink, fontSize: 16, fontWeight: '700' },
});
