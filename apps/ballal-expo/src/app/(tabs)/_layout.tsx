import { Ionicons } from '@expo/vector-icons';
import { Tabs } from 'expo-router';
import { Platform, type ColorValue } from 'react-native';

import { C, F } from '@/lib/theme';

type IconName = 'home' | 'search' | 'chatbubbles' | 'person';

function TabIcon({ name, color, focused }: { name: IconName; color: ColorValue; focused: boolean }) {
  return <Ionicons name={focused ? name : `${name}-outline`} size={24} color={color as string} />;
}

/** Barre du bas flottante et arrondie : Accueil · Recherche · Messages · Profil. */
export default function TabsLayout() {
  const icon = (name: IconName) => function TabBarIcon(p: { color: ColorValue; focused: boolean }) {
    return <TabIcon name={name} {...p} />;
  };
  return (
    <Tabs
      screenOptions={{
        headerShown: false,
        animation: 'shift',
        tabBarActiveTintColor: C.primary,
        tabBarInactiveTintColor: C.muted,
        tabBarLabelStyle: { fontFamily: F.bold, fontSize: 11 },
        tabBarStyle: {
          position: 'absolute',
          left: 14,
          right: 14,
          bottom: Platform.OS === 'ios' ? 24 : 12,
          height: 66,
          borderRadius: 30,
          paddingTop: 6,
          paddingBottom: 8,
          backgroundColor: 'rgba(255,255,255,0.96)',
          borderTopWidth: 0,
          shadowColor: C.primary,
          shadowOpacity: 0.16,
          shadowRadius: 24,
          shadowOffset: { width: 0, height: 10 },
          elevation: 10,
        },
        sceneStyle: { backgroundColor: C.bg },
      }}>
      <Tabs.Screen name="index" options={{ title: 'Accueil', tabBarIcon: icon('home') }} />
      <Tabs.Screen name="search" options={{ title: 'Recherche', tabBarIcon: icon('search') }} />
      <Tabs.Screen name="messages" options={{ title: 'Messages', tabBarIcon: icon('chatbubbles') }} />
      <Tabs.Screen name="profile" options={{ title: 'Profil', tabBarIcon: icon('person') }} />
    </Tabs>
  );
}
