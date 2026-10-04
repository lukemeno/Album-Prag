import { Link, Stack } from 'expo-router';
import { ScrollView, StyleSheet, Text } from 'react-native';
import { colors } from '@/domain/theme';

export default function NotFoundScreen() {
  return (
    <>
      <Stack.Screen options={{ title: 'Nicht gefunden' }} />
      <ScrollView contentInsetAdjustmentBehavior="automatic" contentContainerStyle={styles.content}>
        <Text style={styles.title}>Diese Seite gibt es nicht.</Text>
        <Link href="/(tabs)" style={styles.link}>Zur Reise zurück</Link>
      </ScrollView>
    </>
  );
}

const styles = StyleSheet.create({
  content: { alignItems: 'center', flexGrow: 1, gap: 18, justifyContent: 'center', padding: 20 },
  title: { color: colors.ink, fontSize: 20 },
  link: { color: colors.red, fontSize: 16 },
});
