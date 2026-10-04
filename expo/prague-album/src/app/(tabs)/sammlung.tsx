import { useCallback, useEffect, useState } from 'react';
import { Pressable, ScrollView, StyleSheet, Text, TextInput, View } from 'react-native';
import { useSQLiteContext } from 'expo-sqlite';
import { colors, fonts, space } from '@/domain/theme';
import { usePlaceStore } from '@/storage/place-store';
import { useTripSync } from '@/storage/trip-sync';

interface CollectionEntry {
  id: string;
  kind: 'post' | 'comment' | 'reaction' | 'placeLink';
  postID?: string;
  authorID: string;
  authorName: string;
  createdAt?: number;
  updatedAt?: number;
  text?: string;
  url?: string;
  canonicalURL?: string;
  displayTitle?: string;
  caption?: string;
  active?: boolean;
  deleted?: boolean;
}

const referenceTime = () => (Date.now() - 978307200000) / 1000;

export default function CollectionScreen() {
  const db = useSQLiteContext();
  const [entries, setEntries] = useState<CollectionEntry[]>([]);
  const [participantID, setParticipantID] = useState('');
  const [draft, setDraft] = useState('');
  const [commentDrafts, setCommentDrafts] = useState<Record<string, string>>({});
  const [revision, setRevision] = useState(0);
  const { memberName } = usePlaceStore();
  const { syncNow, revision: syncRevision } = useTripSync();

  useEffect(() => {
    let active = true;
    Promise.all([
      db.getAllAsync<{ payload_json: string }>('SELECT payload_json FROM collection_entries WHERE deleted = 0 ORDER BY updated_at DESC'),
      db.getFirstAsync<{ value: string }>("SELECT value FROM album_settings WHERE key = 'participantID'"),
    ]).then(async ([rows, savedID]) => {
      if (!active) return;
      const id = savedID?.value ?? `expo-${Date.now()}-${Math.random().toString(36).slice(2)}`;
      if (!savedID) await db.runAsync("INSERT OR REPLACE INTO album_settings (key,value) VALUES ('participantID',?)", [id]);
      if (!active) return;
      setParticipantID(id);
      setEntries(rows.map((row) => JSON.parse(row.payload_json) as CollectionEntry));
    });
    return () => { active = false; };
  }, [db, revision, syncRevision]);

  const saveEntry = useCallback(async (entry: CollectionEntry) => {
    const updatedAt = Date.now();
    await db.runAsync(
      'INSERT OR REPLACE INTO collection_entries (id,payload_json,version,deleted,updated_at) VALUES (?,?,1,0,?)',
      [entry.id, JSON.stringify(entry), updatedAt],
    );
    setRevision((value) => value + 1);
    void syncNow();
  }, [db, syncNow]);

  const addPost = async () => {
    const value = draft.trim();
    if (!value || !participantID) return;
    const id = `expo-post-${Date.now()}-${Math.random().toString(36).slice(2, 7)}`;
    let url: string | undefined;
    let displayTitle: string | undefined;
    if (/^https?:\/\//i.test(value)) {
      try {
        const parsed = new URL(value);
        url = parsed.toString();
        displayTitle = parsed.host.replace(/^www\./, '');
      } catch {
        url = undefined;
      }
    }
    const now = referenceTime();
    await saveEntry({ id, kind: 'post', authorID: participantID, authorName: memberName, createdAt: now, updatedAt: now, text: url ? undefined : value, url, canonicalURL: url, displayTitle, deleted: false });
    setDraft('');
  };

  const addComment = async (postID: string) => {
    const value = commentDrafts[postID]?.trim();
    if (!value || !participantID) return;
    const now = referenceTime();
    const id = `expo-comment-${Date.now()}-${Math.random().toString(36).slice(2, 7)}`;
    await saveEntry({ id, kind: 'comment', postID, authorID: participantID, authorName: memberName, createdAt: now, updatedAt: now, text: value, deleted: false });
    setCommentDrafts((current) => ({ ...current, [postID]: '' }));
  };

  const toggleReaction = async (postID: string) => {
    const current = entries.find((entry) => entry.kind === 'reaction' && entry.postID === postID && entry.authorID === participantID);
    const now = referenceTime();
    await saveEntry({ id: current?.id ?? `expo-reaction-${postID}-${participantID}`, kind: 'reaction', postID, authorID: participantID, authorName: memberName, createdAt: current?.createdAt ?? now, updatedAt: now, active: current?.active !== true, deleted: false });
  };

  const posts = entries.filter((entry) => entry.kind === 'post' && !entry.deleted);
  const comments = entries.filter((entry) => entry.kind === 'comment' && !entry.deleted);
  const reactions = entries.filter((entry) => entry.kind === 'reaction' && !entry.deleted && entry.active !== false);

  return (
    <ScrollView contentInsetAdjustmentBehavior="automatic" contentContainerStyle={styles.content}>
      <Text style={styles.intro}>{posts.length} gespeicherte Links · {comments.length} Kommentare · {reactions.length} Reaktionen</Text>
      {posts.map((post) => {
        const relatedComments = comments.filter((entry) => entry.postID === post.id);
        const relatedReactions = reactions.filter((entry) => entry.postID === post.id);
        return (
          <View key={post.id} style={styles.card}>
            <Text style={styles.author}>{post.authorName}</Text>
            <Text style={styles.title}>{post.displayTitle || post.url || 'Gespeicherter Link'}</Text>
            {!!post.caption && <Text style={styles.body}>{post.caption}</Text>}
            {!!post.text && <Text style={styles.body}>{post.text}</Text>}
            {!!post.url && <Text selectable style={styles.link}>{post.url}</Text>}
            {!!relatedReactions.length && <Text style={styles.meta}>{relatedReactions.length} Reaktionen</Text>}
            {relatedComments.map((comment) => <Text key={comment.id} style={styles.comment}><Text style={styles.author}>{comment.authorName}: </Text>{comment.text}</Text>)}
            <View style={styles.actions}>
              <Pressable onPress={() => void toggleReaction(post.id)} style={styles.action}><Text style={styles.meta}>{relatedReactions.some((entry) => entry.authorID === participantID && entry.active) ? '♥ Gefällt euch' : '♡ Gefällt mir'}</Text></Pressable>
              <TextInput accessibilityLabel={`Kommentar zu ${post.displayTitle ?? 'Beitrag'}`} onChangeText={(value) => setCommentDrafts((current) => ({ ...current, [post.id]: value }))} onSubmitEditing={() => void addComment(post.id)} placeholder="Kommentar" placeholderTextColor={colors.inkSoft} style={styles.commentInput} value={commentDrafts[post.id] ?? ''} />
              <Pressable onPress={() => void addComment(post.id)} style={styles.action}><Text style={styles.meta}>Senden</Text></Pressable>
            </View>
          </View>
        );
      })}
      <View style={styles.card}>
        <Text style={styles.title}>Link oder Notiz teilen</Text>
        <TextInput accessibilityLabel="Link oder Notiz" onChangeText={setDraft} onSubmitEditing={() => void addPost()} placeholder="Beitrag, Link oder Idee" placeholderTextColor={colors.inkSoft} style={styles.postInput} value={draft} />
        <Pressable accessibilityRole="button" onPress={() => void addPost()} style={styles.button}><Text style={styles.buttonText}>Zur Sammlung hinzufügen</Text></Pressable>
      </View>
      {posts.length === 0 && <View style={styles.card}><Text style={styles.title}>Noch keine Links in der Sammlung</Text><Text style={styles.body}>Nach dem Import erscheinen gespeicherte Beiträge hier.</Text></View>}
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  content: { gap: space.medium, padding: space.page, paddingBottom: 48 },
  intro: { color: colors.inkSoft, fontSize: 14 },
  card: { backgroundColor: colors.card, borderColor: colors.rule, borderRadius: space.cardRadius, borderWidth: 1, gap: 11, padding: 18 },
  author: { color: colors.red, fontSize: 12, fontWeight: '700' },
  title: { color: colors.ink, fontFamily: fonts.place, fontSize: 25, lineHeight: 29 },
  body: { color: colors.inkSoft, fontSize: 15, lineHeight: 21 },
  link: { color: colors.red, fontSize: 13 },
  meta: { color: colors.teal, fontSize: 13, fontWeight: '600' },
  comment: { borderLeftColor: colors.rule, borderLeftWidth: 2, color: colors.inkSoft, fontSize: 14, lineHeight: 20, paddingLeft: 10 },
  actions: { gap: 8, marginTop: 3 },
  action: { alignSelf: 'flex-start', paddingVertical: 5 },
  commentInput: { backgroundColor: colors.paper, borderColor: colors.rule, borderRadius: 13, borderWidth: 1, color: colors.ink, minHeight: 44, paddingHorizontal: 12 },
  postInput: { backgroundColor: colors.paper, borderColor: colors.rule, borderRadius: 14, borderWidth: 1, color: colors.ink, minHeight: 48, paddingHorizontal: 14 },
  button: { alignItems: 'center', backgroundColor: colors.red, borderRadius: 24, justifyContent: 'center', minHeight: space.button, paddingHorizontal: 16 },
  buttonText: { color: colors.card, fontSize: 14, fontWeight: '700' },
});
