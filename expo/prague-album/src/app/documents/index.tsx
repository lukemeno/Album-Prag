import { useCallback, useEffect, useState } from 'react';
import { ActivityIndicator, Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';
import { Link, Stack, useRouter } from 'expo-router';
import { useSQLiteContext } from 'expo-sqlite';
import { colors, space } from '@/domain/theme';
import { importPDF, readTravelDocuments, syncTravelDocuments } from '@/storage/travel-documents';
import { useTripSync } from '@/storage/trip-sync';
import type { TravelDocument } from '@/domain/trip';

export default function DocumentsIndexScreen() {
  const db = useSQLiteContext();
  const router = useRouter();
  const { tripID } = useTripSync();
  const [documents, setDocuments] = useState<TravelDocument[]>([]);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [status, setStatus] = useState<string | null>(null);
  const reload = useCallback(async () => { setDocuments(await readTravelDocuments(db)); }, [db]);
  useEffect(() => { let active = true; void readTravelDocuments(db).then((items) => { if (active) setDocuments(items); }).catch((reason: unknown) => { if (active) setError(reason instanceof Error ? reason.message : 'Unterlagen konnten nicht geladen werden.'); }); return () => { active = false; }; }, [db]);

  const importDocument = async () => { if (busy) return; setBusy(true); setError(null); setStatus(null); try { const document = await importPDF(db); await reload(); if (document) router.push(`/documents/${encodeURIComponent(document.id)}`); } catch (reason) { setError(reason instanceof Error ? reason.message : 'PDF konnte nicht importiert werden.'); } finally { setBusy(false); } };
  const sync = async () => { if (busy || !tripID) return; setBusy(true); setError(null); setStatus(null); try { const ok = await syncTravelDocuments(db, tripID); await reload(); setStatus(ok ? 'Unterlagen wurden abgeglichen.' : 'Keine gemeinsame Reise verbunden.'); } catch (reason) { setError(reason instanceof Error ? reason.message : 'Abgleich fehlgeschlagen.'); } finally { setBusy(false); } };
  return <View style={styles.root}><Stack.Screen options={{ title: 'Unterlagen', headerLargeTitle: false }} /><ScrollView contentInsetAdjustmentBehavior="automatic" contentContainerStyle={styles.content}>
    <Text style={styles.eyebrow}>REISEUNTERLAGEN</Text><Text style={styles.title}>Alles für unterwegs</Text><Text style={styles.body}>PDFs bleiben auf diesem Gerät verfügbar. Die private Synchronisierung wird nur auf Wunsch gestartet.</Text>
    <View style={styles.actions}><Pressable accessibilityRole="button" disabled={busy} onPress={() => void importDocument()} style={[styles.primary, busy && styles.disabled]}>{busy ? <ActivityIndicator color={colors.card} /> : <Text style={styles.primaryText}>PDF importieren</Text>}</Pressable>{!!tripID && <Pressable accessibilityRole="button" disabled={busy} onPress={() => void sync()} style={[styles.secondary, busy && styles.disabled]}><Text style={styles.secondaryText}>Privat synchronisieren</Text></Pressable>}<Link href="/trip-editor" asChild><Pressable accessibilityRole="button" style={styles.secondary}><Text style={styles.secondaryText}>Reiseinformationen bearbeiten</Text></Pressable></Link></View>
    {!!error && <View style={styles.error}><Text style={styles.body}>{error}</Text></View>}{!!status && <Text style={styles.success}>{status}</Text>}
    {!documents.length && <View style={styles.empty}><Text style={styles.section}>Noch keine PDFs</Text><Text style={styles.body}>Importiere eine Buchungsbestätigung oder Bordkarte. Auch ältere Unterlagen ohne Original werden als Text angezeigt, wenn sie vorhanden sind.</Text></View>}
    {documents.map((document) => <Pressable key={document.id} accessibilityRole="button" onPress={() => router.push(`/documents/${encodeURIComponent(document.id)}`)} style={styles.row}><View style={styles.rowCopy}><Text style={styles.rowTitle}>{document.name}</Text><Text style={styles.helper}>{document.originalAvailable ? 'Original offline verfügbar' : 'Original auf diesem Gerät nicht verfügbar'}</Text><Text style={styles.helper}>{document.extractedText ? `${document.extractedText.length.toLocaleString('de-DE')} Zeichen Text` : 'Text noch nicht ausgelesen'}</Text></View><Text style={styles.chevron}>›</Text></Pressable>)}
  </ScrollView></View>;
}
const styles = StyleSheet.create({ root: { backgroundColor: colors.paper, flex: 1 }, content: { gap: 14, padding: space.page, paddingBottom: 52 }, eyebrow: { color: colors.red, fontSize: 12, fontWeight: '700', letterSpacing: 1.4 }, title: { color: colors.ink, fontFamily: 'Fraunces-SemiBold', fontSize: 30 }, body: { color: colors.inkSoft, fontSize: 14, lineHeight: 21 }, actions: { gap: 9 }, primary: { alignItems: 'center', backgroundColor: colors.red, borderRadius: 23, justifyContent: 'center', minHeight: 48 }, primaryText: { color: colors.card, fontSize: 15, fontWeight: '700' }, secondary: { alignItems: 'center', borderColor: colors.red, borderRadius: 23, borderWidth: 1, justifyContent: 'center', minHeight: 46 }, secondaryText: { color: colors.red, fontSize: 15, fontWeight: '700' }, disabled: { opacity: 0.55 }, error: { backgroundColor: colors.card, borderColor: colors.red, borderRadius: 12, borderWidth: 1, padding: 12 }, success: { color: colors.teal, fontWeight: '700' }, empty: { backgroundColor: colors.paperDeep, borderRadius: 17, gap: 8, padding: 16 }, section: { color: colors.ink, fontFamily: 'Fraunces-SemiBold', fontSize: 22 }, row: { alignItems: 'center', backgroundColor: colors.card, borderColor: colors.rule, borderRadius: 16, borderWidth: 1, flexDirection: 'row', gap: 10, padding: 14 }, rowCopy: { flex: 1, gap: 3 }, rowTitle: { color: colors.ink, fontSize: 16, fontWeight: '700' }, helper: { color: colors.inkSoft, fontSize: 12 }, chevron: { color: colors.red, fontSize: 27 } });
