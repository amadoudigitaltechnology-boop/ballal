import { Ionicons } from '@expo/vector-icons';
import * as Haptics from 'expo-haptics';
import { Tabs, useFocusEffect } from 'expo-router';
import { useCallback, useEffect, useState } from 'react';
import { LinearGradient } from 'expo-linear-gradient';
import { Animated, Platform, View, type ColorValue } from 'react-native';

import { unreadMessages } from '@/lib/api';
import { supabase } from '@/lib/supabase';
import { C, F } from '@/lib/theme';

type IconName = 'home' | 'search' | 'chatbubbles' | 'person';

/** Icône d'onglet : bulle dégradée lumineuse qui jaillit quand l'onglet est actif. */
function TabIcon({ name, color, focused }: { name: IconName; color: ColorValue; focused: boolean }) {
  const v = useState(() => new Animated.Value(focused ? 1 : 0))[0];
  useEffect(() => {
    Animated.spring(v, { toValue: focused ? 1 : 0, useNativeDriver: true, speed: 14, bounciness: 12 }).start();
  }, [focused, v]);
  const scale = v.interpolate({ inputRange: [0, 1], outputRange: [0.6, 1] });
  const lift = v.interpolate({ inputRange: [0, 1], outputRange: [0, -6] });
  return (
    <View style={{ width: 52, height: 40, alignItems: 'center', justifyContent: 'center' }}>
      <Animated.View
        style={{
          position: 'absolute',
          opacity: v,
          transform: [{ translateY: lift }, { scale }],
          shadowColor: '#4F9BFF',
          shadowOpacity: 0.9,
          shadowRadius: 12,
          shadowOffset: { width: 0, height: 0 },
          elevation: 8,
        }}>
        <LinearGradient colors={['#5AB2FF', C.primary, '#5B3DF5']} start={{ x: 0, y: 0 }} end={{ x: 1, y: 1 }} style={{ width: 46, height: 46, borderRadius: 23 }} />
      </Animated.View>
      <Animated.View style={{ transform: [{ translateY: lift }] }}>
        <Ionicons name={focused ? name : `${name}-outline`} size={focused ? 23 : 22} color={focused ? '#fff' : (color as string)} />
      </Animated.View>
    </View>
  );
}

/** Barre du bas flottante, bleu nuit, bulle lumineuse sur l'onglet actif : Accueil · Recherche · Messages · Profil. */
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
        tabBarActiveTintColor: '#FFFFFF',
        tabBarInactiveTintColor: 'rgba(203,213,245,0.7)',
        tabBarLabelStyle: { fontFamily: F.bold, fontSize: 10.5, letterSpacing: 0.3 },
        tabBarStyle: {
          position: 'absolute',
          left: 14,
          right: 14,
          bottom: Platform.OS === 'ios' ? 24 : 12,
          height: 72,
          borderRadius: 36,
          paddingTop: 8,
          paddingBottom: 8,
          backgroundColor: '#0B1636',
          borderTopWidth: 0,
          borderWidth: 1,
          borderColor: 'rgba(120,160,255,0.18)',
          shadowColor: '#0B1636',
          shadowOpacity: 0.35,
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
