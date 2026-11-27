import { Ionicons } from '@expo/vector-icons';
import * as Haptics from 'expo-haptics';
import { Tabs, useFocusEffect } from 'expo-router';
import { useCallback, useEffect, useState } from 'react';
import { Animated, Platform, View, type ColorValue } from 'react-native';

import { unreadMessages } from '@/lib/api';
import { supabase } from '@/lib/supabase';
import { C, F } from '@/lib/theme';

type IconName = 'home' | 'search' | 'chatbubbles';

/** Icône d'onglet épurée : l'icône se remplit et un petit trait apparaît au-dessus quand l'onglet est actif. */
function TabIcon({ name, color, focused }: { name: IconName; color: ColorValue; focused: boolean }) {
  const v = useState(() => new Animated.Value(focused ? 1 : 0))[0];
  useEffect(() => {
    Animated.spring(v, { toValue: focused ? 1 : 0, useNativeDriver: true, speed: 16, bounciness: 8 }).start();
  }, [focused, v]);
  const scale = v.interpolate({ inputRange: [0, 1], outputRange: [1, 1.08] });
  return (
    <View style={{ width: 52, height: 34, alignItems: 'center', justifyContent: 'center' }}>
      <Animated.View
        style={{ position: 'absolute', top: -9, width: 22, height: 3, borderRadius: 2, backgroundColor: C.primary, opacity: v, transform: [{ scaleX: v }] }}
      />
      <Animated.View style={{ transform: [{ scale }] }}>
        <Ionicons name={focused ? name : `${name}-outline`} size={24} color={color as string} />
      </Animated.View>
    </View>
  );
}

/** Barre du bas blanche et flottante : Accueil · Recherche · Messages. Le profil est accessible en haut de l'accueil et dans Paramètres. */
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
        tabBarInactiveTintColor: '#98A2B3',
        tabBarLabelStyle: { fontFamily: F.bold, fontSize: 11, letterSpacing: 0.2 },
        tabBarStyle: {
          position: 'absolute',
          left: 20,
          right: 20,
          bottom: Platform.OS === 'ios' ? 24 : 14,
          height: 68,
          borderRadius: 26,
          paddingTop: 10,
          paddingBottom: 8,
          backgroundColor: '#FFFFFF',
          borderTopWidth: 0,
          borderWidth: 1,
          borderColor: 'rgba(15,23,42,0.06)',
          shadowColor: '#0F172A',
          shadowOpacity: 0.12,
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
    </Tabs>
  );
}
