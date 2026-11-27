import { Ionicons } from '@expo/vector-icons';
import { Image } from 'expo-image';
import { LinearGradient } from 'expo-linear-gradient';
import { router, useFocusEffect } from 'expo-router';
import { useCallback, useEffect, useState } from 'react';
import { ActivityIndicator, FlatList, ScrollView, Text, TextInput, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

import { ProPhoto } from '@/components/ProTile';
import { Empty, FadeIn, Pressy, styles } from '@/components/ui';
import { conversations, timeAgo, type Conversation } from '@/lib/api';
import { gnf, marketPhoto } from '@/lib/market';
import { supabase } from '@/lib/supabase';
import { C, F, brandGradient, shadow } from '@/lib/theme';

function openChat(c: Conversation) {
  router.push({
    pathname: '/chat/[id]',
    params: { id: c.id, name: c.otherName, avatar: c.otherAvatar ?? '', pro: c.otherIsPro ? '1' : '0', other: c.otherUserId },
  });
}

/** Avatar entouré d'un anneau dégradé (orange si message non lu). */
function RingAvatar({ c, size = 54 }: { c: Conversation; size?: number }) {
  return (
    <LinearGradient
      colors={c.unread ? ['#FFB066', C.accent] : brandGradient}
      style={{ width: size + 6, height: size + 6, borderRadius: (size + 6) / 2, alignItems: 'center', justifyContent: 'center' }}>
      <View style={{ backgroundColor: '#fff', borderRadius: (size + 2) / 2, padding: 2 }}>
        <ProPhoto path={c.otherAvatar} name={c.otherName} size={size - 2} radius={(size - 2) / 2} />
      </View>
    </LinearGradient>
  );
}

/** Messagerie : recherche, contacts récents, conversations en temps réel. */
export default function Messages() {
  const [items, setItems] = useState<Conversation[] | null>(null);
  const [q, setQ] = useState('');

  const reload = useCallback(() => {
    conversations().then(setItems).catch(() => setItems((v) => v ?? []));
  }, []);

  useFocusEffect(reload);

  // Mise à jour instantanée à chaque nouveau message
  useEffect(() => {
    const ch = supabase
      .channel('inbox')
      .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'messages' }, () => reload())
      .subscribe();
    return () => {
      supabase.removeChannel(ch);
    };
  }, [reload]);

  const list = (items ?? []).filter((c) => c.otherName.toLowerCase().includes(q.trim().toLowerCase()));
  const unreadTotal = (items ?? []).reduce((n, c) => n + c.unread, 0);

  return (
    <SafeAreaView style={{ flex: 1, backgroundColor: C.bg }} edges={['top']}>
      <View style={[styles.row, { paddingHorizontal: 20, paddingTop: 8 }]}>
        <View style={{ flex: 1 }}>
          <Text style={[styles.h1, { fontSize: 26 }]}>Messages</Text>
          <Text style={[styles.muted, { fontSize: 13 }]}>
            {unreadTotal ? `${unreadTotal} message${unreadTotal > 1 ? 's' : ''} non lu${unreadTotal > 1 ? 's' : ''}` : 'Vous êtes à jour'}
          </Text>
        </View>
      </View>

      <View style={[styles.row, { marginHorizontal: 16, marginTop: 14, backgroundColor: '#fff', borderRadius: 22, height: 46, paddingHorizontal: 16, ...shadow }]}>
        <Ionicons name="search" size={18} color={C.muted} />
        <TextInput
          value={q}
          onChangeText={setQ}
          placeholder="Rechercher une discussion"
          placeholderTextColor="#94A3B8"
          style={{ flex: 1, marginLeft: 10, fontFamily: F.body, fontSize: 14.5, color: C.text }}
        />
      </View>

      {items === null ? (
        <ActivityIndicator color={C.primary} style={{ marginTop: 40 }} />
      ) : (
        <FlatList
          data={list}
          keyExtractor={(c) => c.id}
          overScrollMode="never"
          contentContainerStyle={{ paddingBottom: 110, paddingTop: 4 }}
          ListHeaderComponent={
            items.length > 1 && !q ? (
              <View>
                <Text style={[styles.h3, { fontSize: 15, marginLeft: 20, marginTop: 14, marginBottom: 10 }]}>Récents</Text>
                <ScrollView horizontal showsHorizontalScrollIndicator={false} overScrollMode="never" contentContainerStyle={{ paddingHorizontal: 14, gap: 12 }}>
                  {items.slice(0, 10).map((c, i) => (
                    <FadeIn key={c.id} index={i}>
                      <Pressy onPress={() => openChat(c)} style={{ alignItems: 'center', width: 66 }}>
                        <RingAvatar c={c} size={56} />
                        <Text numberOfLines={1} style={{ fontFamily: F.semibold, fontSize: 11.5, color: C.text, marginTop: 5 }}>
                          {c.otherName.split(' ')[0]}
                        </Text>
                      </Pressy>
                    </FadeIn>
                  ))}
                </ScrollView>
                <Text style={[styles.h3, { fontSize: 15, marginLeft: 20, marginTop: 18, marginBottom: 4 }]}>Discussions</Text>
              </View>
            ) : undefined
          }
          ListEmptyComponent={
            <Empty icon="chatbubbles-outline" title={q ? 'Aucun résultat' : 'Aucune conversation'} text={q ? undefined : 'Ouvrez la fiche d’un professionnel et touchez « Contacter ».'} />
          }
          renderItem={({ item, index }) => (
            <FadeIn index={index}>
              <Pressy onPress={() => openChat(item)} style={[styles.row, { marginHorizontal: 14, marginTop: 8, padding: 12, backgroundColor: '#fff', borderRadius: 22, ...shadow }]}>
                <RingAvatar c={item} size={50} />
                <View style={{ flex: 1, marginLeft: 12 }}>
                  <View style={styles.row}>
                    <Text numberOfLines={1} style={{ fontFamily: F.display, fontSize: 15, color: C.text, flexShrink: 1 }}>
                      {item.otherName}
                    </Text>
                    {item.otherIsPro ? (
                      <View style={{ backgroundColor: C.primarySoft, borderRadius: 8, paddingHorizontal: 6, paddingVertical: 1, marginLeft: 6 }}>
                        <Text style={{ color: C.primary, fontFamily: F.heavy, fontSize: 9.5 }}>PRO</Text>
                      </View>
                    ) : null}
                  </View>
                  {item.listingId ? (
                    <View style={[styles.row, { marginTop: 3 }]}>
                      {item.listingPhoto ? (
                        <Image source={marketPhoto(item.listingPhoto)} style={{ width: 18, height: 18, borderRadius: 5, marginRight: 5 }} contentFit="cover" />
                      ) : (
                        <Ionicons name="pricetag" size={13} color={C.accent} style={{ marginRight: 4 }} />
                      )}
                      <Text numberOfLines={1} style={{ fontFamily: F.semibold, fontSize: 12, color: C.accent, flexShrink: 1 }}>
                        {item.listingTitle ?? 'Article'}{item.listingPrice != null ? ` · ${gnf(item.listingPrice)}` : ''}
                      </Text>
                    </View>
                  ) : null}
                  <Text numberOfLines={1} style={{ fontFamily: item.unread ? F.bold : F.body, fontSize: 13.5, color: item.unread ? C.text : C.muted, marginTop: 3 }}>
                    {item.preview ?? 'Démarrez la discussion'}
                  </Text>
                </View>
                <View style={{ alignItems: 'flex-end', gap: 6, marginLeft: 8 }}>
                  <Text style={{ fontFamily: item.unread ? F.bold : F.medium, fontSize: 11.5, color: item.unread ? C.accent : C.muted }}>
                    {timeAgo(item.lastMessageAt)}
                  </Text>
                  {item.unread ? (
                    <LinearGradient colors={['#FFB066', C.accent]} style={{ minWidth: 22, height: 22, borderRadius: 11, alignItems: 'center', justifyContent: 'center', paddingHorizontal: 6 }}>
                      <Text style={{ color: '#fff', fontSize: 11, fontFamily: F.heavy }}>{item.unread}</Text>
                    </LinearGradient>
                  ) : (
                    <Ionicons name="chevron-forward" size={16} color={C.border} />
                  )}
                </View>
              </Pressy>
            </FadeIn>
          )}
        />
      )}
    </SafeAreaView>
  );
}
