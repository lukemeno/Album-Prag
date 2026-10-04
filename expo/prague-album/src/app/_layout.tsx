import { SQLiteProvider } from 'expo-sqlite';
import { Stack } from 'expo-router';
import { useFonts } from 'expo-font';
import { StatusBar } from 'expo-status-bar';
import { GestureHandlerRootView } from 'react-native-gesture-handler';
import { migrateDatabase } from '@/storage/database';
import { PlaceStoreProvider } from '@/storage/place-store';
import { TripSyncProvider } from '@/storage/trip-sync';
import { colors } from '@/domain/theme';

export default function RootLayout() {
  const [fontsLoaded, fontError] = useFonts({
    'Fraunces-SemiBold': require('../../assets/fonts/Fraunces-SemiBold.ttf'),
    'InstrumentSerif-Regular': require('../../assets/fonts/InstrumentSerif-Regular.ttf'),
  });

  if (!fontsLoaded && !fontError) return null;

  return (
    <GestureHandlerRootView style={{ flex: 1 }}>
      <SQLiteProvider databaseName="prague-album.db" onInit={migrateDatabase}>
        <PlaceStoreProvider>
          <TripSyncProvider>
            <StatusBar style="dark" />
            <Stack screenOptions={{
              headerLargeTitle: true,
              headerShadowVisible: false,
              headerStyle: { backgroundColor: colors.paper },
              headerTitleStyle: { color: colors.ink },
              contentStyle: { backgroundColor: colors.paper },
              headerTintColor: colors.red,
            }}>
              <Stack.Screen name="(tabs)" options={{ headerShown: false }} />
            </Stack>
          </TripSyncProvider>
        </PlaceStoreProvider>
      </SQLiteProvider>
    </GestureHandlerRootView>
  );
}
