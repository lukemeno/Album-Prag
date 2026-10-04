import { Link } from 'expo-router';
import { Alert, Pressable, ScrollView, StyleSheet, Text, TextInput, View } from 'react-native';
import * as Clipboard from 'expo-clipboard';
import { colors, fonts, space } from '@/domain/theme';
import { usePlaceStore } from '@/storage/place-store';
import { showSyncError, useTripSync } from '@/storage/trip-sync';
import { useEffect, useState } from 'react';
import { useSQLiteContext } from 'expo-sqlite';
import * as DocumentPicker from 'expo-document-picker';
import * as Sharing from 'expo-sharing';
import { File, Paths } from 'expo-file-system';
import { exportAlbum, importAlbum } from '@/storage/album-transfer';

export default function TripScreen() {
  const { places, memberName, renameMember, reload } = usePlaceStore();
  const { tripID, inviteToken, status, revision, createTrip, joinTrip, syncNow, reloadTripInfo } = useTripSync();
  const db = useSQLiteContext();
  const [name, setName] = useState(memberName);
  const [token, setToken] = useState('');
  const [documents, setDocuments] = useState<{ id: string; name: string; extractedText: string }[]>([]);

  useEffect(() => {
    let active = true;
    db.getAllAsync<{ payload_json: string }>('SELECT payload_json FROM trip_documents ORDER BY updated_at DESC')
      .then((rows) => { if (active) setDocuments(rows.map(({ payload_json }) => JSON.parse(payload_json) as { id: string; name: string; extractedText: string })); });
    return () => { active = false; };
  }, [db, revision]);

  return (
    <ScrollView contentInsetAdjustmentBehavior="automatic" contentContainerStyle={styles.content}>
      <Text style={styles.eyebrow}>4.–9. OKTOBER · TSCHECHIEN</Text>
      <Text style={styles.title}>Prag</Text>
      <Text style={styles.subtitle}>Euer gemeinsames Reisealbum</Text>
      <Link href="/(tabs)/ideen" style={styles.feature}>
        <Text style={styles.featureKicker}>EURE IDEEN</Text>
        <Text style={styles.featureCount}>{places.length}</Text>
        <Text style={styles.featureText}>Orte und Erlebnisse warten auf euch.</Text>
        <Text style={styles.featureAction}>Ideen ansehen  ›</Text>
      </Link>
      <View style={styles.card}>
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
              if (created) Alert.alert('Reise erstellt', 'Der Einladungscode wurde angezeigt. Kopiere und sende ihn an die zweite Person.');
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
        {documents.map((document) => <View key={document.id} style={styles.document}>
          <Text style={styles.documentName}>{document.name}</Text>
          <Text selectable style={styles.body}>{document.extractedText || 'Kein Textauszug verfügbar.'}</Text>
          <Text style={styles.helper}>Der Textauszug ist übernommen. Die PDF-Datei selbst muss noch separat aus der bisherigen App exportiert werden.</Text>
        </View>)}
      </View>}
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  content: { gap: space.medium, padding: space.page, paddingBottom: 40 },
  eyebrow: { color: colors.red, fontSize: 12, fontWeight: '700', letterSpacing: 1.5 },
  title: { color: colors.ink, fontFamily: fonts.display, fontSize: 42, letterSpacing: -0.5, marginTop: -8 },
  subtitle: { color: colors.inkSoft, fontSize: 16, lineHeight: 23, marginTop: -space.medium },
  feature: { backgroundColor: colors.sky, borderColor: colors.card, borderRadius: space.floatingRadius, borderWidth: 1, gap: 8, padding: 22 },
  featureKicker: { color: colors.red, fontSize: 12, fontWeight: '700', letterSpacing: 1.4 },
  featureCount: { color: colors.ink, fontFamily: fonts.display, fontSize: 42 },
  featureText: { color: colors.inkSoft, fontSize: 16 },
  featureAction: { color: colors.red, fontSize: 16, fontWeight: '600', marginTop: 10 },
  card: { backgroundColor: colors.card, borderColor: colors.rule, borderWidth: 1, borderRadius: space.cardRadius, gap: 10, padding: 18 },
  section: { color: colors.ink, fontFamily: fonts.display, fontSize: 21 },
  body: { color: colors.inkSoft, fontSize: 15, lineHeight: 22 },
  input: { backgroundColor: colors.paper, borderColor: colors.rule, borderRadius: 14, borderWidth: 1, color: colors.ink, minHeight: 48, paddingHorizontal: 14 },
  primaryButton: { alignItems: 'center', backgroundColor: colors.red, borderRadius: 24, justifyContent: 'center', minHeight: space.button, paddingHorizontal: 17 },
  primaryText: { color: colors.card, fontSize: 15, fontWeight: '700' },
  secondaryButton: { alignItems: 'center', backgroundColor: colors.paper, borderColor: colors.rule, borderRadius: 24, borderWidth: 1, justifyContent: 'center', minHeight: 48, paddingHorizontal: 15 },
  secondaryText: { color: colors.ink, fontSize: 14, fontWeight: '600' },
  helper: { color: colors.inkSoft, fontSize: 13, lineHeight: 19 },
  tripCode: { color: colors.teal, fontWeight: '700' },
  document: { borderTopColor: colors.rule, borderTopWidth: 1, gap: 7, paddingTop: 12 },
  documentName: { color: colors.ink, fontSize: 16, fontWeight: '700' },
});
