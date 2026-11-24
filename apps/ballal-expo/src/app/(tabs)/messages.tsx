import { useFocusEffect } from 'expo-router';
import { useCallback, useState } from 'react';
import { ActivityIndicator, FlatList, Text, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

import { ProPhoto } from '@/components/ProTile';
import { Empty, FadeIn, styles } from '@/components/ui';
import { conversations, timeAgo, type Conversation } from '@/lib/api';
import { C, F } from '@/lib/theme';

/** Liste des conversations (démo : lecture ; l'envoi de messages arrive dans la version complète). */
export default function Messages() {
  const [items, setItems] = useState<Conversation[] | null>(null);

  useFocusEffect(
    useCallback(() => {
      conversations().then(setItems).catch(() => setItems([]));
    }, []),
  );

  return (
    <SafeAreaView style={{ flex: 1, backgroundColor: C.bg }} edges={['top']}>
      <Text style={[styles.h2, { paddingHorizontal: 20, paddingTop: 8, paddingBottom: 8 }]}>Messages</Text>
      {items === null ? (
        <ActivityIndicator color={C.primary} style={{ marginTop: 30 }} />
      ) : (
        <FlatList
          data={items}
          keyExtractor={(c) => c.id}
          ListEmptyComponent={<Empty icon="chatbubbles-outline" title="Aucune conversation" text="Contactez un professionnel pour démarrer une discussion." />}
          contentContainerStyle={{ paddingBottom: 110 }}
          renderItem={({ item, index }) => (
            <FadeIn index={index}>
              <View style={[styles.row, { paddingHorizontal: 16, paddingVertical: 12, backgroundColor: '#fff', borderBottomWidth: 1, borderColor: C.border }]}>
                <ProPhoto path={item.otherIsPro ? item.otherAvatar : null} name={item.otherName} size={52} radius={26} />
                <View style={{ flex: 1, marginLeft: 12 }}>
                  <Text numberOfLines={1} style={{ fontFamily: item.unread ? F.heavy : F.semibold, color: C.text }}>
                    {item.otherName}
                  </Text>
                  <Text numberOfLines={1} style={[styles.muted, item.unread ? { color: C.text } : null]}>
                    {item.preview ?? 'Nouvelle conversation'}
                  </Text>
                </View>
                <View style={{ alignItems: 'flex-end', gap: 4 }}>
                  <Text style={[styles.muted, { fontSize: 12 }]}>{timeAgo(item.lastMessageAt)}</Text>
                  {item.unread ? (
                    <View style={{ backgroundColor: C.primary, borderRadius: 10, paddingHorizontal: 7, paddingVertical: 2 }}>
                      <Text style={{ color: '#fff', fontSize: 11, fontFamily: F.bold }}>{item.unread}</Text>
                    </View>
                  ) : null}
                </View>
              </View>
            </FadeIn>
          )}
        />
      )}
    </SafeAreaView>
  );
}
