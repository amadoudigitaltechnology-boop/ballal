import { Ionicons } from '@expo/vector-icons';
import * as Haptics from 'expo-haptics';
import { Tabs, useFocusEffect } from 'expo-router';
import { useCallback, useEffect, useState } from 'react';
import { Platform, type ColorValue } from 'react-native';

import { unreadMessages } from '@/lib/api';
import { supabase } from '@/lib/supabase';
import { C, F } from '@/lib/theme';

type IconName = 'home' | 'search' | 'chatbubbles' | 'person';

function TabIcon({ name, color, focused }: { name: IconName; color: ColorValue; focused: boolean }) {
  return <Ionicons name={focused ? name : `${name}-outline`} size={24} color={color as string} />;
}

/** Barre du bas flottante et arrondie : Accueil · Recherche · Messages · Profil. */
export default function TabsLayout() {
  const [unread, setUnread] = useState(0);
  const refresh = useCallback(() => {
    unreadMessages().then(setUnread).catch(() => undefined);
  }, []);
  useFocusEffect(refresh);
  useEffect(() => {
    const ch = supabase
      .channel('tab-unread')
      .on('postgres_changes', { event: '*', schema: 'public', table: 'messages' }, refresh)
      .on('postgres_changes', { event: 'UPDATE', schema: 'public', table: 'conversation_members' }, refresh)
      .subscribe();
    return () => {
      supabase.removeChannel(ch);
    };
  }, [refresh]);
  const icon = (name: IconName) => function TabBarIcon(p: { color: ColorValue; focused: boolean }) {
    return <TabIcon name={name} {...p} />;
  };
  return (
    <Tabs
      screenListeners={{ tabPress: () => Haptics.selectionAsync().catch(() => undefined) }}
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
      <Tabs.Screen name="messages" options={{
          title: 'Messages',
          tabBarIcon: icon('chatbubbles'),
          tabBarBadge: unread ? (unread > 99 ? '99+' : unread) : undefined,
          tabBarBadgeStyle: { backgroundColor: C.accent, fontFamily: F.heavy, fontSize: 10 },
        }} />
      <Tabs.Screen name="profile" options={{ title: 'Profil', tabBarIcon: icon('person') }} />
    </Tabs>
  );
}
