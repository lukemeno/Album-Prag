import { Tabs, Link } from 'expo-router';
import type { BottomTabBarProps } from 'expo-router/build/react-navigation/bottom-tabs';
import { Pressable, StyleSheet, Text, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { SymbolView } from 'expo-symbols';
import { colors } from '@/domain/theme';

const tabMeta: Record<string, { title: string; icon: string }> = {
  index: { title: 'Reise', icon: 'suitcase.fill' },
  ideen: { title: 'Ideen', icon: 'tray' },
  karte: { title: 'Karte', icon: 'map' },
};

export default function TabLayout() {
  const insets = useSafeAreaInsets();
  return <View style={styles.root}>
    <Tabs initialRouteName="index" screenOptions={{
      headerShown: true,
      headerShadowVisible: false,
      headerStyle: { backgroundColor: colors.paper },
      headerTitleStyle: { color: colors.ink, fontFamily: 'Fraunces-SemiBold' },
      headerTintColor: colors.red,
      sceneStyle: { backgroundColor: colors.paper },
      tabBarStyle: { backgroundColor: 'transparent', borderTopWidth: 0, elevation: 0, position: 'absolute' },
    }} tabBar={(props) => <AlbumTabBar {...props} bottom={insets.bottom} />}>
      <Tabs.Screen name="index" options={{ title: 'Reise', headerShown: false }} />
      <Tabs.Screen name="ideen" options={{ title: 'Ideen' }} />
      <Tabs.Screen name="karte" options={{ title: 'Karte' }} />
      <Tabs.Screen name="sammlung" options={{ href: null, title: 'Sammlung' }} />
    </Tabs>
    <Link href="/assistant" asChild>
      <Pressable accessibilityRole="button" accessibilityLabel="Reise-Assistent öffnen" style={[styles.assistant, { bottom: insets.bottom + 78 }]}>
        <Text style={styles.sparkle}>✦</Text><Text style={styles.assistantText}>Reise-Assistent</Text>
      </Pressable>
    </Link>
  </View>;
}

function AlbumTabBar({ state, descriptors, navigation, bottom }: BottomTabBarProps & { bottom: number }) {
  return <View pointerEvents="box-none" style={[styles.barPosition, { bottom: bottom + 10 }]}>
    <View style={styles.bar}>
      {state.routes.filter((route) => tabMeta[route.name]).map((route) => {
        const focused = state.routes[state.index]?.key === route.key;
        const { title, icon } = tabMeta[route.name];
        const options = descriptors[route.key]?.options;
        const label = typeof options?.tabBarLabel === 'string' ? options.tabBarLabel : title;
        return <Pressable accessibilityRole="tab" accessibilityState={{ selected: focused }} accessibilityLabel={label} key={route.key} onPress={() => {
          const event = navigation.emit({ type: 'tabPress', target: route.key, canPreventDefault: true });
          if (!focused && !event.defaultPrevented) navigation.navigate(route.name, route.params);
        }} onLongPress={() => navigation.emit({ type: 'tabLongPress', target: route.key })} style={styles.tab}>
          <SymbolView name={icon as 'suitcase.fill' | 'tray' | 'map'} size={17} weight="semibold" tintColor={focused ? colors.red : colors.inkSoft} />
          <Text style={[styles.tabLabel, focused && styles.tabLabelActive]}>{title}</Text>
        </Pressable>;
      })}
    </View>
  </View>;
}

const styles = StyleSheet.create({
  root: { backgroundColor: colors.paper, flex: 1 },
  barPosition: { alignItems: 'center', left: 0, position: 'absolute', right: 0 },
  bar: { alignItems: 'center', backgroundColor: colors.card, borderColor: colors.rule, borderRadius: 32, borderWidth: 1, elevation: 12, flexDirection: 'row', gap: 3, paddingHorizontal: 7, paddingVertical: 6, shadowColor: '#211A12', shadowOffset: { width: 0, height: 5 }, shadowOpacity: 0.13, shadowRadius: 14 },
  tab: { alignItems: 'center', borderRadius: 26, justifyContent: 'center', minHeight: 48, minWidth: 76, paddingHorizontal: 12 },
  tabLabel: { color: colors.inkSoft, fontSize: 11, fontWeight: '500', marginTop: 1 },
  tabLabelActive: { color: colors.red, fontWeight: '700' },
  assistant: { alignItems: 'center', backgroundColor: colors.red, borderRadius: 26, elevation: 7, flexDirection: 'row', gap: 8, minHeight: 48, paddingHorizontal: 17, position: 'absolute', right: 20, shadowColor: '#211A12', shadowOffset: { width: 0, height: 3 }, shadowOpacity: 0.2, shadowRadius: 7 },
  sparkle: { color: '#fff', fontSize: 16 },
  assistantText: { color: '#fff', fontSize: 14, fontWeight: '600' },
});
