import { Link, Stack } from 'expo-router';
import { Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';
import { useSQLiteContext } from 'expo-sqlite';
import { colors, space } from '@/domain/theme';
import { usePlaceStore } from '@/storage/place-store';
import { PlacePhoto } from '@/components/place-photo';

export default function MemoriesScreen() {
  const db = useSQLiteContext();
  const { places } = usePlaceStore();
  const memories = places.filter((place) => place.visited).sort((a, b) => (a.day ?? 99) - (b.day ?? 99) || (a.dayOrder ?? 99) - (b.dayOrder ?? 99) || a.title.localeCompare(b.title, 'de'));
  return <>
    <Stack.Screen options={{ title: 'Erinnerungen' }} />
    <ScrollView contentInsetAdjustmentBehavior="automatic" contentContainerStyle={styles.content}>
      <Text style={styles.intro}>Besuchte Orte und ihre Fotos, nach Reisetag geordnet.</Text>
      {memories.map((place) => <Link key={place.id} href={{ pathname: '/place/[id]', params: { id: place.id } }} asChild>
        <Pressable style={styles.card}>
          {place.image && <PlacePhoto asset={place.image} db={db} placeID={place.id} size={180} />}
          <Text style={styles.kicker}>{place.day ? `TAG ${place.day}. OKTOBER` : 'BESUCHT'}</Text>
          <Text style={styles.title}>{place.title}</Text>
          {!!place.note && <Text style={styles.body} numberOfLines={3}>{place.note}</Text>}
          {!!place.gallery?.length && <Text style={styles.meta}>{place.gallery.length} weitere Fotos</Text>}
        </Pressable>
      </Link>)}
      {memories.length === 0 && <View style={styles.card}><Text style={styles.title}>Eure Erinnerungen beginnen hier</Text><Text style={styles.body}>Markiert einen Ort auf der Karte oder in der Ortsansicht als besucht. Er erscheint dann in dieser Chronik.</Text></View>}
    </ScrollView>
  </>;
}

const styles = StyleSheet.create({
  content: { gap: space.medium, padding: space.page, paddingBottom: 48 },
  intro: { color: colors.inkSoft, fontSize: 14, lineHeight: 21 },
  card: { backgroundColor: colors.card, borderColor: colors.rule, borderRadius: 18, borderWidth: 1, gap: 9, padding: 18 },
  kicker: { color: colors.red, fontSize: 11, fontWeight: '700', letterSpacing: 1 },
  title: { color: colors.ink, fontFamily: 'InstrumentSerif-Regular', fontSize: 23, lineHeight: 29 },
  body: { color: colors.inkSoft, fontSize: 14, lineHeight: 20 },
  meta: { color: colors.teal, fontSize: 12 },
});
