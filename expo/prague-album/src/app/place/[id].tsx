import { useEffect, useRef, useState } from 'react';
import { Linking, Pressable, ScrollView, StyleSheet, Switch, Text, TextInput, View } from 'react-native';
import * as Clipboard from 'expo-clipboard';
import * as ImagePicker from 'expo-image-picker';
import * as Location from 'expo-location';
import { Link, router, Stack, useLocalSearchParams } from 'expo-router';
import { colors, space } from '@/domain/theme';
import { parseOpeningHours } from '@/domain/opening-hours';
import { imageAsset, sourceURL as imageSourceURL } from '@/domain/place-images';
import { PlacePhoto } from '@/components/place-photo';
import { usePlaceStore } from '@/storage/place-store';
import { useTripSync } from '@/storage/trip-sync';
import { useSQLiteContext } from 'expo-sqlite';
import { draftFromPlace, newPlaceDraft, readPlace, savePlaceDraft, selectPlaceLocation, setPlaceDeleted, staleEditorResult, type PlaceDraft } from '@/storage/place-editor';
import { candidateAsset, removeLocalImage, savePickedPhoto, searchPlacePhotos, type PlacePhotoCandidate } from '@/storage/place-media';
import { applyLinkPreview, previewLink } from '@/storage/link-preview';

interface LocationChoice { title: string; address: string; latitude: number; longitude: number; }
const categories = ['Idee', 'Sehenswert', 'Essen & Trinken', 'Aussicht', 'Unterkunft', 'Shopping'];

export default function PlaceEditorScreen() {
  const db = useSQLiteContext();
  const { memberName, reload } = usePlaceStore();
  const { syncNow } = useTripSync();
  const params = useLocalSearchParams<{ id?: string }>();
  const id = Array.isArray(params.id) ? params.id[0] : params.id;
  const [draft, setDraft] = useState<PlaceDraft | null>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [query, setQuery] = useState('');
  const [locations, setLocations] = useState<LocationChoice[]>([]);
  const [photoCandidates, setPhotoCandidates] = useState<PlacePhotoCandidate[]>([]);
  const [photoBusy, setPhotoBusy] = useState(false);
  const [previewBusy, setPreviewBusy] = useState(false);
  const generation = useRef(0);
  const photoToken = useRef(0);
  const previewToken = useRef(0);
  const pendingPhotos = useRef<string[]>([]);
  const savedRef = useRef(false);
  const savingRef = useRef(false);
  const draftRef = useRef<PlaceDraft | null>(null);
  const mounted = useRef(true);

  useEffect(() => {
    mounted.current = true;
    savedRef.current = false;
    const pendingPhotosAtSetup = pendingPhotos.current;
    void (async () => {
      if (!id || id === 'new') { if (mounted.current) setDraft(newPlaceDraft(memberName)); return; }
      const place = await readPlace(db, id);
      if (mounted.current) { if (place) { setDraft(draftFromPlace(place)); setQuery(place.address || place.title); } else setError('Der Ort wurde nicht gefunden.'); }
    })();
    return () => { mounted.current = false; generation.current += 1; if (!savedRef.current) { for (const imageID of pendingPhotosAtSetup) void removeLocalImage(db, imageID); } };
  }, [db, id, memberName]);

  useEffect(() => { draftRef.current = draft; }, [draft]);

  const update = (change: Partial<PlaceDraft>) => { generation.current += 1; setPhotoBusy(false); setPreviewBusy(false); setDraft((current) => current ? { ...current, ...change } : current); };
  const openStreetView = () => { if (typeof draft?.lat !== 'number' || typeof draft.lng !== 'number') return; void Linking.openURL(`https://www.google.com/maps/@?api=1&map_action=pano&viewpoint=${draft.lat},${draft.lng}`); };
  const searchLocation = async () => {
    const text = query.trim(); if (!text) return;
    const token = ++generation.current; setError(null); setLocations([]);
    try {
      const results = await Location.geocodeAsync(`${text}, Prague, Czechia`);
      if (!mounted.current || token !== generation.current) return;
      setLocations(results.slice(0, 6).map((result) => { const value = result as unknown as Record<string, unknown>; return { title: typeof value.name === 'string' ? value.name : text, address: [value.street, value.postalCode, value.city].filter((item): item is string => typeof item === 'string' && item.length > 0).join(', ') || text, latitude: result.latitude, longitude: result.longitude }; }));
      if (!results.length) setError('Kein passender Ort gefunden.');
    } catch { if (mounted.current && token === generation.current) setError('Ortssuche fehlgeschlagen. Bitte prüfe den Suchtext.'); }
  };
  const selectLocation = (choice: LocationChoice) => { generation.current += 1; setPhotoBusy(false); setPreviewBusy(false); setDraft((current) => current ? selectPlaceLocation(current, choice) : current); setQuery(choice.address || choice.title); setLocations([]); setPhotoCandidates([]); };
  const loadPhotos = async () => {
    if (!draft || typeof draft.lat !== 'number' || typeof draft.lng !== 'number') { setError('Wähle zuerst einen Ort mit Koordinaten.'); return; }
    const requested = { ...draft }; const token = ++generation.current; photoToken.current = token; setPhotoBusy(true); setError(null);
    try { const result = await searchPlacePhotos(requested, undefined); if (!mounted.current || token !== generation.current || staleEditorResult(token, generation.current, draft, requested)) return; setPhotoCandidates(result.candidates.length ? result.candidates : result.image ? [result.image] : []); if (!result.candidates.length && !result.image) setError('Keine verifizierte Bildauswahl gefunden.'); }
    catch (reason) { if (mounted.current && token === generation.current) setError(reason instanceof Error ? reason.message : 'Bildsuche fehlgeschlagen.'); }
    finally { if (mounted.current && photoToken.current === token) setPhotoBusy(false); }
  };
  const choosePhoto = (candidate: PlacePhotoCandidate) => { if (!draft) return; generation.current += 1; setDraft({ ...draft, image: candidateAsset(candidate, draft), gallery: photoCandidates.map((item) => { const asset = candidateAsset(item, draft); return 'external' in asset ? { ...asset.external, userSelected: false } : {}; }) }); setPhotoCandidates([]); };
  const chooseOwnPhoto = async () => {
    const requested = draftRef.current;
    if (!requested) return;
    const token = ++generation.current;
    try {
      const result = await ImagePicker.launchImageLibraryAsync({ mediaTypes: ['images'], quality: 0.8, allowsMultipleSelection: false });
      if (result.canceled || !result.assets[0]) return;
      const uploaded = await savePickedPhoto(db, requested.id, result.assets[0].uri);
      if (!mounted.current || token !== generation.current || draftRef.current?.id !== requested.id) { await removeLocalImage(db, uploaded.id); return; }
      pendingPhotos.current.push(uploaded.id);
      generation.current += 1;
      setDraft((current) => current && current.id === requested.id ? { ...current, image: { uploaded }, gallery: null } : current);
      setError(null);
    }
    catch (reason) { if (mounted.current) setError(reason instanceof Error ? reason.message : 'Das Foto konnte nicht gespeichert werden.'); }
  };
  const enrichLink = async () => {
    if (!draft?.sourceURL.trim()) return;
    const requested = { ...draft }; const token = ++generation.current; previewToken.current = token; setPreviewBusy(true); setError(null);
    try { const preview = await previewLink(requested.sourceURL); if (!mounted.current || token !== generation.current || staleEditorResult(token, generation.current, draft, requested)) return; const next = { ...draft, image: draft.image }; applyLinkPreview(preview, next); setDraft(next); }
    catch (reason) { if (mounted.current && token === generation.current) setError(reason instanceof Error ? reason.message : 'Link-Vorschau fehlgeschlagen. Der Link bleibt erhalten.'); }
    finally { if (mounted.current && previewToken.current === token) setPreviewBusy(false); }
  };
  const save = async () => {
    if (!draft || savingRef.current) return;
    savingRef.current = true;
    setBusy(true); setError(null);
    try {
      await savePlaceDraft(db, draft);
      savedRef.current = true;
      const selectedID = draft.image && 'uploaded' in draft.image ? draft.image.uploaded.id : null;
      await Promise.all(pendingPhotos.current.filter((imageID) => imageID !== selectedID).map((imageID) => removeLocalImage(db, imageID).catch(() => undefined)));
      pendingPhotos.current = [];
      await reload();
      void syncNow();
      if (mounted.current) { if (router.canGoBack()) router.back(); else router.replace('/(tabs)/ideen'); }
    }
    catch (reason) { setError(reason instanceof Error ? reason.message : 'Der Ort konnte nicht gespeichert werden.'); }
    finally { savingRef.current = false; if (mounted.current) setBusy(false); }
  };
  const toggleDeleted = async () => { if (!draft) return; try { await setPlaceDeleted(db, draft.id, !draft.deleted); await reload(); if (router.canGoBack()) router.back(); else router.replace('/(tabs)/ideen'); } catch (reason) { setError(reason instanceof Error ? reason.message : 'Der Ort konnte nicht geändert werden.'); } };
  const photoSource = draft?.image ? imageSourceURL(draft.image as unknown as Record<string, unknown>) : null;
  if (!draft) return <View style={styles.center}><Text style={styles.body}>{error || 'Ort wird geladen …'}</Text></View>;
  return <View style={styles.root}>
    <Stack.Screen options={{ title: id === 'new' ? 'Neue Idee' : draft.title || 'Ort bearbeiten', headerLargeTitle: false, headerRight: () => <Pressable accessibilityLabel="Ort speichern" disabled={busy || !draft.title.trim()} onPress={() => void save()} style={{ paddingHorizontal: 8, opacity: busy || !draft.title.trim() ? 0.4 : 1 }}><Text style={{ color: colors.red, fontWeight: '700' }}>{busy ? '…' : 'Speichern'}</Text></Pressable> }} />
    <ScrollView contentInsetAdjustmentBehavior="automatic" contentContainerStyle={styles.content} keyboardShouldPersistTaps="handled">
      <Text style={styles.eyebrow}>ORT BEARBEITEN</Text>
      <TextInput accessibilityLabel="Name des Ortes" onChangeText={(value) => update({ title: value })} placeholder="Name des Ortes" placeholderTextColor={colors.inkSoft} style={styles.titleInput} value={draft.title} />
      <TextInput accessibilityLabel="Link zur Idee" autoCapitalize="none" autoCorrect={false} keyboardType="url" onChangeText={(value) => update({ sourceURL: value })} placeholder="TikTok-, Instagram- oder Webseiten-Link" placeholderTextColor={colors.inkSoft} style={styles.input} value={draft.sourceURL} />
      <Pressable accessibilityLabel="Link aus Zwischenablage einfügen" onPress={() => void Clipboard.getStringAsync().then((value) => { if (value.trim()) update({ sourceURL: value.trim() }); }).catch(() => setError('Die Zwischenablage konnte nicht gelesen werden.'))} style={{ minHeight: 34, justifyContent: 'center', paddingHorizontal: 4 }}><Text style={styles.secondaryText}>Link aus Zwischenablage einfügen</Text></Pressable>
      {!!draft.sourceURL && <Pressable accessibilityRole="button" disabled={previewBusy} onPress={() => void enrichLink()} style={styles.secondaryButton}><Text style={styles.secondaryText}>{previewBusy ? 'Vorschau wird geladen …' : 'Link-Vorschau laden'}</Text></Pressable>}
      <View style={styles.row}><Text style={styles.label}>Kategorie</Text><ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.chips}>{categories.map((category) => <Pressable accessibilityRole="button" key={category} onPress={() => update({ category })} style={[styles.chip, draft.category === category && styles.chipSelected]}><Text style={[styles.chipText, draft.category === category && styles.chipSelectedText]}>{category}</Text></Pressable>)}</ScrollView></View>
      <TextInput accessibilityLabel="Notiz zum Ort" multiline onChangeText={(value) => update({ note: value })} placeholder="Warum möchtet ihr dorthin?" placeholderTextColor={colors.inkSoft} style={[styles.input, styles.multiline]} value={draft.note} />
      <View style={styles.row}><Text style={styles.label}>Öffnungszeiten</Text><TextInput accessibilityLabel="Öffnungszeiten" autoCapitalize="none" autoCorrect={false} onChangeText={(value) => update({ openingHours: value })} placeholder="Mo-Fr 09:00-18:00 oder 24/7" placeholderTextColor={colors.inkSoft} style={styles.input} value={draft.openingHours ?? ''} /><Text style={styles.helper}>{draft.openingHours && !parseOpeningHours(draft.openingHours) ? (draft.openingHours === draft.openingHoursOriginal ? 'Format unbekannt; bleibt als unbekannt gespeichert.' : 'Format nicht erkannt; Speichern zeigt einen Hinweis.') : 'Zum Beispiel Mo-Fr 09:00-18:00 oder 24/7.'}</Text></View>
      <View style={styles.card}><Text style={styles.section}>Ort auswählen</Text><View style={styles.searchRow}><TextInput accessibilityLabel="Ort oder Adresse suchen" onChangeText={(value) => { setQuery(value); setLocations([]); generation.current += 1; }} onSubmitEditing={() => void searchLocation()} placeholder="Ort oder Adresse in Prag" placeholderTextColor={colors.inkSoft} style={[styles.input, styles.flex]} value={query} /><Pressable accessibilityLabel="Ort suchen" onPress={() => void searchLocation()} style={styles.searchButton}><Text style={styles.searchText}>⌕</Text></Pressable></View>{locations.map((choice, index) => <Pressable accessibilityLabel={`Ort auswählen: ${choice.title}`} key={`${choice.latitude}-${choice.longitude}-${index}`} onPress={() => selectLocation(choice)} style={styles.locationChoice}><Text style={styles.placeTitle}>{choice.title}</Text><Text style={styles.helper}>{choice.address}</Text></Pressable>)}{!!draft.address && <Text style={styles.selected}>✓ {draft.address}</Text>}{typeof draft.lat === 'number' && <><Text style={styles.helper}>Koordinaten: {draft.lat.toFixed(5)}, {draft.lng?.toFixed(5)}</Text><Pressable accessibilityRole="link" accessibilityLabel="Google Street View öffnen" onPress={openStreetView} style={styles.secondaryButton}><Text style={styles.secondaryText}>Google Street View öffnen</Text></Pressable></>}</View>
      <View style={styles.card}><Text style={styles.section}>Fotos</Text>{draft.image && <PlacePhoto asset={draft.image as Record<string, unknown>} db={db} placeID={draft.id} size={180} />}{photoSource && /^https?:\/\//iu.test(photoSource) && <Pressable accessibilityRole="link" onPress={() => void Linking.openURL(photoSource)}><Text style={styles.mapLink}>Bildquelle öffnen ↗</Text></Pressable>}{!!draft.gallery?.length && <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.chips}>{draft.gallery.map((raw, index) => { const asset = imageAsset({ external: raw }); if (!asset || !('external' in asset)) return null; return <Pressable key={`${asset.external.imageURL}-${index}`} style={{ width: 140 }} accessibilityLabel={`Galeriefoto auswählen: ${asset.external.credit}`} onPress={() => update({ image: { external: { ...asset.external, userSelected: true } } })}><PlacePhoto asset={asset as unknown as Record<string, unknown>} db={db} placeID={draft.id} size={100} /><Text style={styles.helper}>{asset.external.credit}</Text></Pressable>; })}</ScrollView>}<View style={styles.rowButtons}><Pressable accessibilityLabel="Eigenes Foto auswählen" onPress={() => void chooseOwnPhoto()} style={styles.secondaryButton}><Text style={styles.secondaryText}>Eigenes Foto</Text></Pressable><Pressable accessibilityLabel="Ortsfotos suchen" disabled={photoBusy} onPress={() => void loadPhotos()} style={styles.secondaryButton}><Text style={styles.secondaryText}>{photoBusy ? 'Suche …' : 'Ortsfotos suchen'}</Text></Pressable></View>{photoCandidates.map((candidate, index) => <Pressable accessibilityLabel={`Foto auswählen: ${candidate.credit}`} key={`${candidate.image_url}-${index}`} onPress={() => choosePhoto(candidate)} style={styles.candidate}><Text style={styles.placeTitle}>{candidate.credit || 'Bildquelle'}</Text><Text style={styles.helper}>{candidate.confidence === 'verified' ? 'Verifiziert' : 'Vorschlag'} · Auswählen</Text><PlacePhoto asset={candidateAsset(candidate, draft) as Record<string, unknown>} db={db} placeID={draft.id} size={120} /></Pressable>)}{draft.image && <Pressable onPress={() => update({ image: null, gallery: [] })}><Text style={styles.dangerText}>Foto entfernen</Text></Pressable>}<Text style={styles.helper}>Eigene Fotos bleiben bei einer Ortsänderung erhalten. Ortsfotos werden dann neu geprüft.</Text></View>
      <View style={styles.card}><View style={styles.switchRow}><Text style={styles.label}>Besucht</Text><Switch onValueChange={(visited) => update({ visited })} value={draft.visited} /></View><Text style={styles.label}>Reisetag</Text><View style={styles.chips}>{[null, 4, 5, 6, 7, 8, 9].map((day) => <Pressable accessibilityLabel={day == null ? 'Kein Reisetag' : `Reisetag ${day}. Oktober`} key={day ?? 'none'} onPress={() => update({ day })} style={[styles.chip, draft.day === day && styles.chipSelected]}><Text style={[styles.chipText, draft.day === day && styles.chipSelectedText]}>{day == null ? 'Offen' : day}</Text></Pressable>)}</View></View>
      {!!error && <View style={styles.error}><Text style={styles.body}>{error}</Text></View>}
      <Pressable accessibilityRole="button" disabled={busy || !draft.title.trim()} onPress={() => void save()} style={[styles.primaryButton, (busy || !draft.title.trim()) && styles.disabled]}><Text style={styles.primaryText}>{busy ? 'Speichern …' : 'Speichern'}</Text></Pressable>
      {id !== 'new' && <Pressable accessibilityRole="button" onPress={() => void toggleDeleted()} style={styles.secondaryButton}><Text style={styles.secondaryText}>{draft.deleted ? 'Ort wiederherstellen' : 'Ort archivieren'}</Text></Pressable>}
      <Link href="/(tabs)/karte" style={styles.mapLink}>Karte mit Orten öffnen ↗</Link>
    </ScrollView>
  </View>;
}

const styles = StyleSheet.create({ root: { backgroundColor: colors.paper, flex: 1 }, center: { alignItems: 'center', backgroundColor: colors.paper, flex: 1, justifyContent: 'center', padding: 20 }, content: { gap: 14, padding: space.page, paddingBottom: 48 }, eyebrow: { color: colors.red, fontSize: 12, fontWeight: '700', letterSpacing: 1.4 }, titleInput: { color: colors.ink, fontFamily: 'InstrumentSerif-Regular', fontSize: 32, minHeight: 48 }, input: { backgroundColor: colors.card, borderColor: colors.rule, borderRadius: 12, borderWidth: 1, color: colors.ink, minHeight: 46, paddingHorizontal: 13, paddingVertical: 10 }, multiline: { minHeight: 90, textAlignVertical: 'top' }, row: { gap: 8 }, label: { color: colors.ink, fontSize: 14, fontWeight: '700' }, chips: { flexDirection: 'row', flexWrap: 'wrap', gap: 7 }, chip: { backgroundColor: colors.paperDeep, borderRadius: 18, paddingHorizontal: 11, paddingVertical: 8 }, chipSelected: { backgroundColor: colors.ink }, chipText: { color: colors.ink, fontSize: 13 }, chipSelectedText: { color: colors.card }, card: { backgroundColor: colors.paperDeep, borderRadius: 17, gap: 9, padding: 15 }, section: { color: colors.ink, fontFamily: 'Fraunces-SemiBold', fontSize: 22 }, searchRow: { alignItems: 'center', flexDirection: 'row', gap: 8 }, flex: { flex: 1 }, searchButton: { alignItems: 'center', backgroundColor: colors.red, borderRadius: 22, height: 44, justifyContent: 'center', width: 44 }, searchText: { color: colors.card, fontSize: 25 }, locationChoice: { backgroundColor: colors.card, borderColor: colors.rule, borderRadius: 12, borderWidth: 1, gap: 3, padding: 11 }, placeTitle: { color: colors.ink, fontSize: 15, fontWeight: '700' }, selected: { color: colors.teal, fontSize: 14, fontWeight: '700' }, helper: { color: colors.inkSoft, fontSize: 12, lineHeight: 18 }, rowButtons: { flexDirection: 'row', flexWrap: 'wrap', gap: 8 }, secondaryButton: { alignItems: 'center', borderColor: colors.rule, borderRadius: 22, borderWidth: 1, justifyContent: 'center', minHeight: 43, paddingHorizontal: 14 }, secondaryText: { color: colors.ink, fontSize: 14, fontWeight: '700' }, candidate: { backgroundColor: colors.card, borderColor: colors.rule, borderRadius: 12, borderWidth: 1, gap: 7, padding: 10 }, switchRow: { alignItems: 'center', flexDirection: 'row', justifyContent: 'space-between' }, error: { backgroundColor: colors.card, borderColor: colors.red, borderRadius: 12, borderWidth: 1, padding: 12 }, body: { color: colors.inkSoft, fontSize: 14, lineHeight: 21 }, primaryButton: { alignItems: 'center', backgroundColor: colors.red, borderRadius: 24, justifyContent: 'center', minHeight: 48 }, primaryText: { color: colors.card, fontSize: 15, fontWeight: '700' }, disabled: { opacity: 0.45 }, dangerText: { color: colors.red, fontSize: 14, fontWeight: '700' }, mapLink: { color: colors.red, fontSize: 14, fontWeight: '700', paddingVertical: 7 },
});
