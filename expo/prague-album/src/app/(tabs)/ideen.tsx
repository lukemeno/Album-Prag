import { useCallback, useEffect, useMemo, useState } from 'react';
import { Link, useFocusEffect } from 'expo-router';
import { Linking, Pressable, ScrollView, StyleSheet, Text, TextInput, View } from 'react-native';
import { colors, space } from '@/domain/theme';
import { myDecision } from '@/domain/place-decisions';
import { usePlaceStore } from '@/storage/place-store';
import { useSQLiteContext } from 'expo-sqlite';
import { readArchivedPlaces } from '@/storage/place-editor';
import { useTripSync } from '@/storage/trip-sync';
import type { Place } from '@/domain/place';
import { PlacePhoto } from '@/components/place-photo';
import CollectionScreen from '@/components/collection-screen';

type Filter = 'open' | 'approved' | 'later' | 'all';
const filters: { id: Filter; title: string }[] = [
  { id: 'open', title: 'Offen' },
  { id: 'approved', title: 'Dafür' },
  { id: 'later', title: 'Später' },
  { id: 'all', title: 'Alle' },
];

export default function IdeasScreen() {
  const { places, memberName, decide, addPlace, assignDay, ready } = usePlaceStore();
  const db = useSQLiteContext();
  const { syncNow, revision } = useTripSync();
  const [archivedPlaces, setArchivedPlaces] = useState<Place[]>([]);
  const [showArchived, setShowArchived] = useState(false);
  useFocusEffect(useCallback(() => {
    if (!showArchived) return undefined;
    let active = true;
    void readArchivedPlaces(db).then((value) => { if (active) setArchivedPlaces(value); });
    return () => { active = false; };
  }, [db, showArchived]));
  useEffect(() => {
    if (!showArchived) return;
    let active = true;
    void readArchivedPlaces(db).then((value) => { if (active) setArchivedPlaces(value); });
    return () => { active = false; };
  }, [db, showArchived, revision]);
  const [filter, setFilter] = useState<Filter>('open');
  const [section, setSection] = useState<'discover' | 'collection'>('discover');
  const [query, setQuery] = useState('');
  const [title, setTitle] = useState('');
  const [category, setCategory] = useState('Idee');
  const [note, setNote] = useState('');
  const visiblePlaces = useMemo(() => (showArchived ? archivedPlaces : places).filter((place) => {
    const decision = myDecision(place, memberName);
    const matchesFilter = showArchived || filter === 'all' || filter === 'open' && decision === 'open' || filter === 'approved' && decision === 'approved' || filter === 'later' && decision === 'later';
    const searchText = `${place.title} ${place.category} ${place.note} ${place.address}`.toLocaleLowerCase('de');
    return (showArchived ? place.deleted : !place.deleted) && matchesFilter && searchText.includes(query.trim().toLocaleLowerCase('de'));
  }), [archivedPlaces, filter, memberName, places, query, showArchived]);

  if (section === 'collection') {
    return <View style={styles.sectionRoot}>
      <IdeasSegment section={section} onChange={setSection} />
      <CollectionScreen embedded />
    </View>;
  }

  return (
    <ScrollView contentInsetAdjustmentBehavior="automatic" contentContainerStyle={styles.content}>
      <IdeasSegment section={section} onChange={setSection} />
      <Text style={styles.intro}>{ready ? `${places.length} Orte und Erlebnisse für eure Reise.` : 'Ideen werden geladen …'}</Text>
      <View style={styles.topActions}><Link href="/place/new" asChild><Pressable accessibilityLabel="Neue Idee hinzufügen" style={styles.newButton}><Text style={styles.newButtonText}>＋ Neue Idee</Text></Pressable></Link><Pressable accessibilityRole="button" onPress={() => setShowArchived((value) => !value)} style={styles.archiveButton}><Text style={styles.archiveText}>{showArchived ? 'Aktive Ideen' : 'Archiv anzeigen'}</Text></Pressable></View>
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
        {visiblePlaces.map((place) => <IdeaCard key={place.id} place={place} onDecide={decide as unknown as (id: string, approve: boolean | null) => Promise<void>} onAssignDay={async (id, day) => { await assignDay(id, day); void syncNow(); }} memberName={memberName} />)}
        {ready && visiblePlaces.length === 0 && <Text style={styles.empty}>{showArchived ? 'Noch keine archivierten Orte.' : 'Hier ist gerade nichts. Probiere einen anderen Filter.'}</Text>}
      </View>
    </ScrollView>
  );
}

function IdeasSegment({ section, onChange }: { section: 'discover' | 'collection'; onChange: (value: 'discover' | 'collection') => void }) {
  return <View accessibilityRole="tablist" style={styles.segment}>
    {(['discover', 'collection'] as const).map((item) => {
      const selected = item === section;
      return <Pressable accessibilityRole="tab" accessibilityState={{ selected }} key={item} onPress={() => onChange(item)} style={[styles.segmentButton, selected && styles.segmentSelected]}>
        <Text style={[styles.segmentText, selected && styles.segmentTextSelected]}>{item === 'discover' ? 'Entdecken' : 'Sammlung'}</Text>
      </Pressable>;
    })}
  </View>;
}

function IdeaCard({ place, memberName, onDecide, onAssignDay }: { place: Place; memberName: string; onDecide: (id: string, approve: boolean | null) => Promise<void>; onAssignDay: (id: string, day: number | null) => Promise<void> }) {
  const decision = myDecision(place, memberName);
  const db = useSQLiteContext();
  return (
    <View style={styles.card}>
      {place.image && <PlacePhoto asset={place.image} db={db} placeID={place.id} label={place.title} size={150} />}
      <View style={styles.cardHeader}>
        <Text style={styles.category}>{place.category.toLocaleUpperCase('de')}</Text>
        {place.approvals.length > 1 && <Text style={styles.shared}>Gemeinsam</Text>}
      </View>
      <Link href={{ pathname: '/place/[id]', params: { id: place.id } }} asChild><Pressable accessibilityLabel={`${place.title} bearbeiten`}><Text selectable style={styles.placeTitle}>{place.title}</Text></Pressable></Link>
      {!!place.note && <Text selectable style={styles.note}>{place.note}</Text>}
      {!!place.address && <Text selectable style={styles.address}>{place.address}</Text>}
      <View style={styles.actions}>
        {decision !== 'approved' && (
          <Pressable accessibilityRole="button" onPress={() => void onDecide(place.id, true)} style={styles.yesButton}>
            <Text style={styles.yesText}>Dafür</Text>
          </Pressable>
        )}
        {decision !== 'later' && (
          <Pressable accessibilityRole="button" onPress={() => void onDecide(place.id, false)} style={styles.laterButton}>
            <Text style={styles.laterText}>Später</Text>
          </Pressable>
        )}
        {decision !== 'open' && <Pressable accessibilityRole="button" onPress={() => void onDecide(place.id, null)} style={styles.clearVoteButton}><Text style={styles.clearVoteText}>Abstimmung zurücknehmen</Text></Pressable>}
        {place.sourceURL.length > 0 && (
          <Pressable accessibilityRole="link" onPress={() => void Linking.openURL(place.sourceURL)} style={styles.linkButton}>
            <Text style={styles.linkText}>Quelle ↗</Text>
          </Pressable>
        )}
      </View>
      {decision === 'approved' && <View style={styles.dayActions}>
        <Text style={styles.dayLabel}>{place.day ? `Geplant: ${place.day}. Oktober` : 'Tag planen'}</Text>
        {[4, 5, 6, 7, 8, 9].map((day) => <Pressable accessibilityRole="button" accessibilityLabel={`Am ${day}. Oktober planen`} key={day} onPress={() => void onAssignDay(place.id, day)} style={[styles.dayButton, place.day === day && styles.dayButtonSelected]}><Text style={[styles.dayButtonText, place.day === day && styles.dayButtonTextSelected]}>{day}</Text></Pressable>)}
        {place.day != null && <Pressable accessibilityRole="button" onPress={() => void onAssignDay(place.id, null)} style={styles.clearDay}><Text style={styles.clearDayText}>×</Text></Pressable>}
      </View>}
    </View>
  );
}

const styles = StyleSheet.create({
  sectionRoot: { backgroundColor: colors.paper, flex: 1 },
  segment: { backgroundColor: colors.paperDeep, borderRadius: 10, flexDirection: 'row', gap: 3, marginHorizontal: space.page, marginTop: 8, padding: 3 },
  segmentButton: { alignItems: 'center', borderRadius: 8, flex: 1, justifyContent: 'center', minHeight: 34 },
  segmentSelected: { backgroundColor: colors.card },
  segmentText: { color: colors.inkSoft, fontSize: 13, fontWeight: '600' },
  segmentTextSelected: { color: colors.ink },
  content: { gap: space.medium, padding: space.page, paddingBottom: 150 },
  topActions: { alignItems: 'center', flexDirection: 'row', gap: 8 },
  newButton: { backgroundColor: colors.red, borderRadius: 22, justifyContent: 'center', minHeight: 43, paddingHorizontal: 15 },
  newButtonText: { color: colors.card, fontSize: 14, fontWeight: '700' },
  archiveButton: { borderColor: colors.rule, borderRadius: 22, borderWidth: 1, justifyContent: 'center', minHeight: 43, paddingHorizontal: 13 },
  archiveText: { color: colors.ink, fontSize: 13, fontWeight: '600' },
  intro: { color: colors.inkSoft, fontSize: 16, lineHeight: 22 },
  search: { backgroundColor: colors.card, borderColor: colors.rule, borderRadius: 14, borderWidth: 1, color: colors.ink, fontSize: 16, minHeight: 50, paddingHorizontal: 16 },
  filters: { gap: 8, paddingVertical: 2 },
  filter: { backgroundColor: colors.paperDeep, borderRadius: 30, justifyContent: 'center', minHeight: 40, paddingHorizontal: 16 },
  selectedFilter: { backgroundColor: colors.ink },
  filterText: { color: colors.ink, fontSize: 14, fontWeight: '600' },
  selectedFilterText: { color: colors.card },
  count: { color: colors.inkSoft, fontSize: 13, fontWeight: '600', letterSpacing: 0.8, marginTop: 2, textTransform: 'uppercase' },
  addCard: { backgroundColor: colors.paperDeep, borderRadius: 18, gap: 9, padding: 15 },
  addHeading: { color: colors.ink, fontFamily: 'Fraunces-SemiBold', fontSize: 21 },
  addFields: { alignItems: 'center', flexDirection: 'row', gap: 8 },
  input: { backgroundColor: colors.card, borderColor: colors.rule, borderRadius: 12, borderWidth: 1, color: colors.ink, flex: 1, minHeight: 43, paddingHorizontal: 12 },
  categoryInput: { minWidth: 80 },
  addButton: { backgroundColor: colors.red, borderRadius: 22, justifyContent: 'center', minHeight: 43, paddingHorizontal: 15 },
  addButtonText: { color: colors.card, fontSize: 14, fontWeight: '700' },
  list: { gap: 12 },
  card: { backgroundColor: colors.card, borderColor: colors.rule, borderRadius: 18, borderWidth: 1, gap: 8, padding: 17 },
  cardHeader: { alignItems: 'center', flexDirection: 'row', justifyContent: 'space-between' },
  category: { color: colors.red, fontSize: 11, fontWeight: '700', letterSpacing: 1.2 },
  shared: { color: colors.teal, fontSize: 12, fontWeight: '600' },
  placeTitle: { color: colors.ink, fontFamily: 'InstrumentSerif-Regular', fontSize: 25, lineHeight: 30 },
  note: { color: colors.inkSoft, fontSize: 15, lineHeight: 21 },
  address: { color: colors.inkSoft, fontSize: 13 },
  actions: { alignItems: 'center', flexDirection: 'row', flexWrap: 'wrap', gap: 8, marginTop: 5 },
  yesButton: { backgroundColor: colors.red, borderRadius: 24, justifyContent: 'center', minHeight: 42, paddingHorizontal: 18 },
  yesText: { color: colors.card, fontSize: 14, fontWeight: '700' },
  laterButton: { borderColor: colors.rule, borderRadius: 24, borderWidth: 1, justifyContent: 'center', minHeight: 42, paddingHorizontal: 18 },
  laterText: { color: colors.ink, fontSize: 14, fontWeight: '600' },
  linkButton: { justifyContent: 'center', minHeight: 42, paddingHorizontal: 10 },
  linkText: { color: colors.red, fontSize: 14, fontWeight: '600' },
  dayActions: { alignItems: 'center', flexDirection: 'row', flexWrap: 'wrap', gap: 6, marginTop: 3 },
  dayLabel: { color: colors.inkSoft, fontSize: 12, marginRight: 2 },
  dayButton: { alignItems: 'center', backgroundColor: colors.paperDeep, borderRadius: 16, justifyContent: 'center', minHeight: 32, minWidth: 32 },
  dayButtonSelected: { backgroundColor: colors.teal },
  dayButtonText: { color: colors.ink, fontSize: 12, fontWeight: '600' },
  dayButtonTextSelected: { color: colors.card },
  clearDay: { alignItems: 'center', justifyContent: 'center', minHeight: 32, minWidth: 32 },
  clearDayText: { color: colors.red, fontSize: 20 },
  clearVoteButton: { justifyContent: 'center', minHeight: 42, paddingHorizontal: 8 },
  clearVoteText: { color: colors.inkSoft, fontSize: 13, textDecorationLine: 'underline' },
  empty: { color: colors.inkSoft, fontSize: 15, lineHeight: 22, padding: 20, textAlign: 'center' },
});
