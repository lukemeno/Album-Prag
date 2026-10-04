import { useCallback, useMemo, useState } from 'react';
import { Pressable, ScrollView, StyleSheet, Text, TextInput, View } from 'react-native';
import * as Haptics from 'expo-haptics';
import { colors, fonts, space } from '@/domain/theme';
import { myDecision } from '@/domain/place-decisions';
import { usePlaceStore } from '@/storage/place-store';
import { showSyncError, useTripSync } from '@/storage/trip-sync';
import type { PlaceDecision } from '@/domain/place';
import DecisionCard from '@/components/DecisionCard';

type Filter = PlaceDecision | 'all';
const filters: { id: Filter; title: string }[] = [
  { id: 'open', title: 'Offen' },
  { id: 'approved', title: 'Dafür' },
  { id: 'opposed', title: 'Dagegen' },
  { id: 'all', title: 'Alle' },
];

export default function IdeasScreen() {
  const { places, memberName, decide, addPlace, assignDay, ready } = usePlaceStore();
  const { syncNow } = useTripSync();
  const [filter, setFilter] = useState<Filter>('open');
  const [query, setQuery] = useState('');
  const [title, setTitle] = useState('');
  const [category, setCategory] = useState('Idee');
  const [note, setNote] = useState('');
  const [undoAction, setUndoAction] = useState<{ placeID: string; title: string; previous: PlaceDecision; next: PlaceDecision } | null>(null);

  const changeDecision = useCallback(async (placeID: string, next: PlaceDecision) => {
    const place = places.find((item) => item.id === placeID);
    if (!place) return;
    const previous = myDecision(place, memberName);
    if (previous === next) return;
    try {
      await decide(placeID, next);
      setUndoAction({ placeID, title: place.title, previous, next });
      await Haptics.selectionAsync();
      void syncNow();
    } catch (error) {
      showSyncError(error);
    }
  }, [decide, memberName, places, syncNow]);

  const undoDecision = useCallback(async () => {
    if (!undoAction) return;
    const action = undoAction;
    setUndoAction(null);
    try {
      await decide(action.placeID, action.previous);
      await Haptics.selectionAsync();
      void syncNow();
    } catch (error) {
      setUndoAction(action);
      showSyncError(error);
    }
  }, [decide, syncNow, undoAction]);

  const visiblePlaces = useMemo(() => places.filter((place) => {
    const decision = myDecision(place, memberName);
    const matchesFilter = filter === 'all' || decision === filter;
    const searchText = `${place.title} ${place.category} ${place.note} ${place.address}`.toLocaleLowerCase('de');
    return !place.deleted && matchesFilter && searchText.includes(query.trim().toLocaleLowerCase('de'));
  }), [filter, memberName, places, query]);

  const assignPlaceDay = useCallback(async (id: string, day: number | null) => {
    try {
      await assignDay(id, day);
      void syncNow();
    } catch (error) {
      showSyncError(error);
    }
  }, [assignDay, syncNow]);

  return (
    <ScrollView contentInsetAdjustmentBehavior="automatic" contentContainerStyle={styles.content}>
      {undoAction && <View accessibilityLiveRegion="polite" style={styles.undoBanner}>
        <View style={styles.undoCopy}>
          <Text style={styles.undoTitle}>{undoAction.title}</Text>
          <Text style={styles.undoText}>Als „{filters.find((item) => item.id === undoAction.next)?.title}“ markiert</Text>
        </View>
        <Pressable accessibilityRole="button" accessibilityLabel={`Entscheidung für ${undoAction.title} rückgängig machen`} onPress={() => void undoDecision()} style={styles.undoButton}>
          <Text style={styles.undoButtonText}>Rückgängig</Text>
        </Pressable>
      </View>}
      <Text style={styles.intro}>{ready ? `${places.length} Orte und Erlebnisse für eure Reise.` : 'Ideen werden geladen …'}</Text>
      <TextInput
        accessibilityLabel="Ideen durchsuchen"
        onChangeText={setQuery}
        placeholder="Orte, Cafés, Erlebnisse"
        placeholderTextColor={colors.inkSoft}
        returnKeyType="search"
        style={styles.search}
        value={query}
      />
      <View style={styles.addCard}>
        <Text style={styles.addHeading}>Idee hinzufügen</Text>
        <TextInput accessibilityLabel="Name der Idee" onChangeText={setTitle} placeholder="Ort oder Erlebnis" placeholderTextColor={colors.inkSoft} style={styles.input} value={title} />
        <View style={styles.addFields}>
          <TextInput accessibilityLabel="Kategorie" onChangeText={setCategory} placeholder="Kategorie" placeholderTextColor={colors.inkSoft} style={[styles.input, styles.categoryInput]} value={category} />
          <Pressable accessibilityRole="button" onPress={() => {
            if (!title.trim()) return;
            void addPlace(title, category, note);
            setTitle(''); setNote('');
          }} style={styles.addButton}><Text style={styles.addButtonText}>Hinzufügen</Text></Pressable>
        </View>
        <TextInput accessibilityLabel="Notiz zur Idee" onChangeText={setNote} placeholder="Notiz (optional)" placeholderTextColor={colors.inkSoft} style={styles.input} value={note} />
      </View>
      <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.filters}>
        {filters.map((item) => {
          const selected = filter === item.id;
          return (
            <Pressable accessibilityRole="tab" accessibilityState={{ selected }} key={item.id} onPress={() => setFilter(item.id)} style={[styles.filter, selected && styles.selectedFilter]}>
              <Text style={[styles.filterText, selected && styles.selectedFilterText]}>{item.title}</Text>
            </Pressable>
          );
        })}
      </ScrollView>
      <Text style={styles.count}>{visiblePlaces.length} {visiblePlaces.length === 1 ? 'Idee' : 'Ideen'}</Text>
      <View style={styles.list}>
        {visiblePlaces.map((place) => <DecisionCard key={place.id} place={place} onDecide={changeDecision} onAssignDay={assignPlaceDay} memberName={memberName} />)}
        {ready && visiblePlaces.length === 0 && <Text style={styles.empty}>Hier ist gerade nichts. Probiere einen anderen Filter.</Text>}
      </View>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  content: { gap: space.medium, padding: space.page, paddingBottom: 48 },
  undoBanner: { alignItems: 'center', backgroundColor: colors.ink, borderRadius: 18, flexDirection: 'row', gap: 12, justifyContent: 'space-between', paddingHorizontal: 16, paddingVertical: 13 },
  undoCopy: { flex: 1, gap: 2 },
  undoTitle: { color: colors.card, fontSize: 14, fontWeight: '700' },
  undoText: { color: '#D8D1C5', fontSize: 12 },
  undoButton: { alignItems: 'center', justifyContent: 'center', minHeight: 40, paddingHorizontal: 8 },
  undoButtonText: { color: '#F3B29F', fontSize: 13, fontWeight: '700' },
  intro: { color: colors.inkSoft, fontSize: 16, lineHeight: 22 },
  search: { backgroundColor: colors.card, borderColor: colors.rule, borderRadius: 16, borderWidth: 1, color: colors.ink, fontSize: 16, minHeight: 52, paddingHorizontal: 16 },
  filters: { gap: 8, paddingVertical: 2 },
  filter: { backgroundColor: colors.paperDeep, borderRadius: 24, justifyContent: 'center', minHeight: 42, paddingHorizontal: 16 },
  selectedFilter: { backgroundColor: colors.ink },
  filterText: { color: colors.ink, fontSize: 14, fontWeight: '600' },
  selectedFilterText: { color: colors.card },
  count: { color: colors.inkSoft, fontSize: 13, fontWeight: '600', letterSpacing: 0.8, marginTop: 2, textTransform: 'uppercase' },
  list: { gap: 12 },
  addCard: { backgroundColor: colors.card, borderColor: colors.rule, borderRadius: space.cardRadius, borderWidth: 1, gap: 10, padding: 16 },
  addHeading: { color: colors.ink, fontFamily: fonts.display, fontSize: 20 },
  addFields: { alignItems: 'center', flexDirection: 'row', gap: 8 },
  input: { backgroundColor: colors.paper, borderColor: colors.rule, borderRadius: 13, borderWidth: 1, color: colors.ink, flex: 1, minHeight: 46, paddingHorizontal: 13 },
  categoryInput: { minWidth: 80 },
  addButton: { alignItems: 'center', backgroundColor: colors.red, borderRadius: 23, justifyContent: 'center', minHeight: 46, paddingHorizontal: 15 },
  addButtonText: { color: colors.card, fontSize: 14, fontWeight: '700' },
  empty: { color: colors.inkSoft, fontSize: 15, lineHeight: 22, padding: 20, textAlign: 'center' },
});
