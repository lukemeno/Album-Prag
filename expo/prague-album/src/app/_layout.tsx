import { SQLiteProvider } from 'expo-sqlite';
import { Stack } from 'expo-router';
import { StatusBar } from 'expo-status-bar';
import { useFonts } from 'expo-font';
import { migrateDatabase } from '@/storage/database';
import { PlaceStoreProvider } from '@/storage/place-store';
import { TripSyncProvider } from '@/storage/trip-sync';

export default function RootLayout() {
  const [fontsLoaded] = useFonts({
    'Fraunces-SemiBold': require('../../assets/fonts/Fraunces-SemiBold.ttf'),
    'InstrumentSerif-Regular': require('../../assets/fonts/InstrumentSerif-Regular.ttf'),
  });
  if (!fontsLoaded) return null;
  return (
    <SQLiteProvider databaseName="prague-album.db" onInit={migrateDatabase}>
      <PlaceStoreProvider>
        <TripSyncProvider>
          <StatusBar style="dark" />
          <Stack screenOptions={{
            headerLargeTitle: true,
            headerBackTitle: 'Zurück',
            headerShadowVisible: false,
            headerStyle: { backgroundColor: '#F4EFE4' },
            headerTitleStyle: { color: '#1C1915' },
            contentStyle: { backgroundColor: '#F4EFE4' },
            headerTintColor: '#B64532',
          }}>
            <Stack.Screen name="(tabs)" options={{ headerShown: false }} />
            <Stack.Screen name="place/[id]" options={{ title: 'Ort bearbeiten', headerLargeTitle: false }} />
            <Stack.Screen name="itinerary" options={{ title: 'Tagesplan', headerLargeTitle: false }} />
            <Stack.Screen name="assistant" options={{ title: 'Reise-Assistent', headerLargeTitle: false }} />
            <Stack.Screen name="documents/index" options={{ title: 'Unterlagen', headerLargeTitle: false }} />
            <Stack.Screen name="documents/[id]" options={{ title: 'Dokument', headerLargeTitle: false }} />
            <Stack.Screen name="trip-editor" options={{ title: 'Reiseinformationen', headerLargeTitle: false }} />
          </Stack>
        </TripSyncProvider>
      </PlaceStoreProvider>
    </SQLiteProvider>
  );
}
