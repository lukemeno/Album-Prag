import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { Link } from 'expo-router';
import { Alert, Image, Linking, Pressable, ScrollView, StyleSheet, Text, TextInput, View } from 'react-native';
import { useSQLiteContext } from 'expo-sqlite';
import { colors, space } from '@/domain/theme';
import type { CollectionEntry } from '@/domain/collection';
import { addCollectionComment, addCollectionPost, linkCollectionPlace, participantID, readCollectionEntries, tombstoneCollectionEntry, toggleCollectionHeart, unlinkCollectionPlace, updateCollectionMetadata, readCollectionSync } from '@/storage/collection-store';
import { previewLink } from '@/storage/link-preview';
import { usePlaceStore } from '@/storage/place-store';
import { useTripSync } from '@/storage/trip-sync';

export default function CollectionScreen({ embedded = false }: { embedded?: boolean }) {
  const db = useSQLiteContext();
  const { memberName, places } = usePlaceStore();
  const { syncNow, revision: syncRevision } = useTripSync();
  const [entries, setEntries] = useState<CollectionEntry[]>([]);
  const [authorID, setAuthorID] = useState('');
  const [draft, setDraft] = useState('');
  const [commentDrafts, setCommentDrafts] = useState<Record<string, string>>({});
  const [revision, setRevision] = useState(0);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const [expandedPostID, setExpandedPostID] = useState<string | null>(null);
  const metadataRequests = useRef(new Set<string>());

  const refresh = useCallback(async () => {
    const [id, all] = await Promise.all([participantID(db), readCollectionEntries(db)]);
    setAuthorID(id);
    setEntries(all);
  }, [db]);

  useEffect(() => {
    let mounted = true;
    Promise.resolve().then(async () => { if (mounted) await refresh(); }).catch((reason: unknown) => setError(reason instanceof Error ? reason.message : 'Die Sammlung konnte nicht geladen werden.'));
    return () => { mounted = false; };
  }, [refresh, revision, syncRevision]);

  const saveAction = useCallback(async (action: () => Promise<unknown>) => {
    setBusy(true);
    setError('');
    try {
      await action();
      await refresh();
      setRevision((value) => value + 1);
      void syncNow();
    } catch (reason) {
      setError(reason instanceof Error ? reason.message : 'Die Sammlung konnte nicht gespeichert werden.');
    } finally { setBusy(false); }
  }, [refresh, syncNow]);

  const posts = useMemo(() => entries.filter((entry) => entry.kind === 'post'), [entries]);
  const comments = useMemo(() => entries.filter((entry) => entry.kind === 'comment'), [entries]);
  const reactions = useMemo(() => entries.filter((entry) => entry.kind === 'reaction' && entry.active !== false), [entries]);

  useEffect(() => {
    const controller = new AbortController();
    for (const post of posts) {
      if (!post.url || post.metadataState !== 'pending' || metadataRequests.current.has(post.id)) continue;
      metadataRequests.current.add(post.id);
      void previewLink(post.url, controller.signal).then(async (preview) => {
        const sync = await readCollectionSync(db, post.id);
        const changed = await updateCollectionMetadata(db, post.id, { displayTitle: preview.title || post.displayTitle, caption: preview.author ? `${preview.author}: ${preview.description ?? ''}` : preview.description ?? undefined, thumbnailURL: preview.thumbnailURL ?? undefined, state: 'available' }, sync?.mutationToken);
        if (changed) { await refresh(); void syncNow(); }
      }).catch(async () => {
        if (controller.signal.aborted) return;
        const sync = await readCollectionSync(db, post.id);
        const changed = await updateCollectionMetadata(db, post.id, { state: 'unavailable' }, sync?.mutationToken);
        if (changed) { await refresh(); void syncNow(); }
      });
    }
    return () => controller.abort();
  }, [db, posts, refresh, syncNow]);

  return (
    <ScrollView style={embedded ? styles.embeddedScroll : undefined} contentInsetAdjustmentBehavior="automatic" contentContainerStyle={styles.content}>
      {!embedded && <Text style={styles.intro}>Links und Notizen bleiben lokal gespeichert und werden bei Verbindung abgeglichen.</Text>}
      {error ? <Text accessibilityRole="alert" style={styles.error}>{error}</Text> : null}
      <View style={styles.card}>
        <Text style={styles.title}>Etwas zur Sammlung hinzufügen</Text>
        <TextInput accessibilityLabel="Link oder Nachricht" multiline maxLength={4000} onChangeText={setDraft} placeholder="Link oder Nachricht …" placeholderTextColor={colors.inkSoft} style={styles.input} value={draft} />
        <Pressable accessibilityRole="button" disabled={busy || !draft.trim()} onPress={() => void saveAction(async () => { await addCollectionPost(db, { authorID, authorName: memberName, text: draft }); setDraft(''); })} style={[styles.button, (busy || !draft.trim()) && styles.disabled]}><Text style={styles.buttonText}>{busy ? 'Speichern …' : 'Zur Sammlung hinzufügen'}</Text></Pressable>
      </View>
      {posts.map((post) => {
        const relatedComments = comments.filter((entry) => entry.postID === post.id).sort((a, b) => (a.createdAt ?? 0) - (b.createdAt ?? 0));
        const relatedReactions = reactions.filter((entry) => entry.postID === post.id);
        const relatedPlaceLinks = entries.filter((entry) => entry.kind === 'placeLink' && entry.postID === post.id && entry.active !== false);
        const myHeart = relatedReactions.some((entry) => entry.authorID === authorID);
        return <View key={post.id} style={styles.card}>
          <Text style={styles.author}>{post.authorName}</Text>
          <Text style={styles.title}>{post.displayTitle || post.url || 'Nachricht'}</Text>
          {!!post.text && <Text style={styles.body}>{post.text}</Text>}
          {!!post.caption && <Text style={styles.body}>{post.caption}</Text>}
          {!!post.thumbnailURL && <Image accessibilityLabel="Linkvorschau" resizeMode="cover" source={{ uri: post.thumbnailURL }} style={styles.thumbnail} />}
          {!!post.url && <Pressable accessibilityRole="link" onPress={() => void Linking.openURL(post.url!).catch(() => setError('Der Link konnte nicht geöffnet werden.'))}><Text selectable style={styles.link}>{post.url}</Text></Pressable>}
          {!!relatedReactions.length && <Text style={styles.meta}>{relatedReactions.length} ♥</Text>}
          {!!relatedPlaceLinks.length && <View style={styles.placeList}>{relatedPlaceLinks.map((entry) => { const place = places.find((candidate) => candidate.id === entry.placeID && !candidate.deleted); return place ? <View key={entry.id} style={styles.placeRow}><Link href={{ pathname: '/place/[id]', params: { id: place.id } }} asChild><Pressable><Text style={styles.meta}>{place.title}  ›</Text></Pressable></Link><Pressable accessibilityRole="button" disabled={busy} onPress={() => void saveAction(() => unlinkCollectionPlace(db, post.id, place.id))}><Text style={styles.delete}>Trennen</Text></Pressable></View> : null; })}</View>}
          <Pressable accessibilityRole="button" onPress={() => setExpandedPostID((current) => current === post.id ? null : post.id)}><Text style={styles.meta}>{expandedPostID === post.id ? 'Ort-Auswahl schließen' : 'Ort verknüpfen'}</Text></Pressable>
          {expandedPostID === post.id && <View style={styles.placeList}>{places.filter((place) => !place.deleted && !relatedPlaceLinks.some((entry) => entry.placeID === place.id)).map((place) => <Pressable accessibilityRole="button" disabled={busy} key={place.id} onPress={() => void saveAction(() => linkCollectionPlace(db, { postID: post.id, placeID: place.id, authorID, authorName: memberName }))}><Text style={styles.meta}>+ {place.title}</Text></Pressable>)}</View>}
          {relatedComments.map((comment) => <Text key={comment.id} style={styles.comment}><Text style={styles.author}>{comment.authorName}: </Text>{comment.text}</Text>)}
          <View style={styles.actions}>
            <Pressable accessibilityRole="button" disabled={busy} onPress={() => void saveAction(() => toggleCollectionHeart(db, post.id, authorID, memberName))}><Text style={styles.meta}>{myHeart ? '♥ Gefällt euch' : '♡ Gefällt mir'}</Text></Pressable>
            <TextInput accessibilityLabel={`Kommentar zu ${post.displayTitle ?? 'Beitrag'}`} editable={!busy} onChangeText={(value) => setCommentDrafts((current) => ({ ...current, [post.id]: value }))} onSubmitEditing={() => void saveAction(async () => { const value = commentDrafts[post.id] ?? ''; await addCollectionComment(db, { postID: post.id, authorID, authorName: memberName, text: value }); setCommentDrafts((current) => ({ ...current, [post.id]: '' })); })} placeholder="Kommentar …" placeholderTextColor={colors.inkSoft} style={styles.input} value={commentDrafts[post.id] ?? ''} />
            <Pressable accessibilityRole="button" disabled={busy || !commentDrafts[post.id]?.trim()} onPress={() => void saveAction(async () => { await addCollectionComment(db, { postID: post.id, authorID, authorName: memberName, text: commentDrafts[post.id] ?? '' }); setCommentDrafts((current) => ({ ...current, [post.id]: '' })); })}><Text style={styles.meta}>Senden</Text></Pressable>
            <Pressable accessibilityRole="button" disabled={busy} onPress={() => Alert.alert('Beitrag löschen?', 'Der Beitrag wird aus der gemeinsamen Sammlung entfernt.', [{ text: 'Abbrechen', style: 'cancel' }, { text: 'Löschen', style: 'destructive', onPress: () => void saveAction(() => tombstoneCollectionEntry(db, post.id)) }])}><Text style={styles.delete}>Löschen</Text></Pressable>
          </View>
        </View>;
      })}
      {posts.length === 0 && <View style={styles.card}><Text style={styles.title}>Noch keine Beiträge</Text><Text style={styles.body}>Füge oben einen Link oder eine Nachricht hinzu.</Text></View>}
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  embeddedScroll: { flex: 1 },
  content: { gap: space.medium, padding: space.page, paddingBottom: 150 },
  intro: { color: colors.inkSoft, fontSize: 14, lineHeight: 21 },
  card: { backgroundColor: colors.card, borderColor: colors.rule, borderRadius: 18, borderWidth: 1, gap: 10, padding: 18 },
  author: { color: colors.red, fontSize: 12, fontWeight: '700' },
  title: { color: colors.ink, fontFamily: 'Fraunces-SemiBold', fontSize: 22, lineHeight: 28 },
  body: { color: colors.inkSoft, fontSize: 15, lineHeight: 21 },
  link: { color: colors.red, fontSize: 13, lineHeight: 19 },
  thumbnail: { borderRadius: 12, height: 170, width: '100%' },
  meta: { color: colors.teal, fontSize: 14, fontWeight: '600', paddingVertical: 5 },
  comment: { borderLeftColor: colors.rule, borderLeftWidth: 2, color: colors.inkSoft, fontSize: 14, lineHeight: 20, paddingLeft: 10 },
  actions: { gap: 9, marginTop: 3 },
  input: { backgroundColor: colors.paperDeep, borderRadius: 12, color: colors.ink, minHeight: 44, padding: 12, textAlignVertical: 'top' },
  button: { alignItems: 'center', backgroundColor: colors.red, borderRadius: 24, justifyContent: 'center', minHeight: 44 },
  buttonText: { color: colors.card, fontSize: 14, fontWeight: '700' },
  disabled: { opacity: 0.5 },
  delete: { color: colors.red, fontSize: 13, paddingVertical: 4 },
  placeList: { backgroundColor: colors.paperDeep, borderRadius: 12, gap: 7, padding: 10 },
  placeRow: { alignItems: 'center', flexDirection: 'row', justifyContent: 'space-between' },
  error: { color: colors.red, fontSize: 14 },
});
