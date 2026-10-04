import { Tabs } from 'expo-router';
import { SymbolView, type AndroidSymbol, type SFSymbol } from 'expo-symbols';
import { colors } from '@/domain/theme';

function TabGlyph({ name, focused }: { name: { ios: SFSymbol; android: AndroidSymbol; web: AndroidSymbol }; focused: boolean }) {
  return <SymbolView name={name} tintColor={focused ? colors.red : colors.inkSoft} size={22} />;
}

export default function TabLayout() {
  return (
    <Tabs initialRouteName="ideen" screenOptions={{
      headerShown: true,
      headerTitleAlign: 'center',
      headerShadowVisible: false,
      headerStyle: { backgroundColor: colors.paper },
      headerTitleStyle: { color: colors.ink, fontSize: 17, fontWeight: '700' },
      headerTintColor: colors.red,
      tabBarActiveTintColor: colors.red,
      tabBarInactiveTintColor: colors.inkSoft,
      tabBarStyle: { backgroundColor: colors.card, borderTopColor: colors.rule, paddingTop: 5 },
      tabBarLabelStyle: { fontSize: 11, fontWeight: '600' },
      sceneStyle: { backgroundColor: colors.paper },
    }}>
      <Tabs.Screen name="index" options={{ title: 'Reise', tabBarIcon: ({ focused }) => <TabGlyph name={{ ios: focused ? 'house.fill' : 'house', android: 'home', web: 'home' }} focused={focused} /> }} />
      <Tabs.Screen name="ideen" options={{ title: 'Ideen', tabBarIcon: ({ focused }) => <TabGlyph name={{ ios: focused ? 'sparkles' : 'sparkle', android: 'auto_awesome', web: 'auto_awesome' }} focused={focused} /> }} />
      <Tabs.Screen name="karte" options={{ title: 'Karte', tabBarIcon: ({ focused }) => <TabGlyph name={{ ios: focused ? 'map.fill' : 'map', android: 'map', web: 'map' }} focused={focused} /> }} />
      <Tabs.Screen name="sammlung" options={{ title: 'Sammlung', tabBarIcon: ({ focused }) => <TabGlyph name={{ ios: focused ? 'square.stack.fill' : 'square.stack', android: 'collections_bookmark', web: 'collections_bookmark' }} focused={focused} /> }} />
    </Tabs>
  );
}
