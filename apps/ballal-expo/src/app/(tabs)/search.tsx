import { router, useLocalSearchParams } from 'expo-router';
import { useEffect, useRef, useState } from 'react';
import { ActivityIndicator, FlatList, Pressable, Text, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

import { ProTile } from '@/components/ProTile';
import { Empty, Input, styles } from '@/components/ui';
import { searchPros, type ProCard } from '@/lib/api';
import { C, F } from '@/lib/theme';

export default function Search() {
  const params = useLocalSearchParams<{ category?: string; name?: string }>();
  const [query, setQuery] = useState('');
  const category = params.category ? { id: params.category, name: params.name ?? 'Catégorie' } : null;
  const categoryId = category?.id;
  const [items, setItems] = useState<ProCard[]>([]);
  const [loading, setLoading] = useState(false);
  const seq = useRef(0);

  useEffect(() => {
    const id = ++seq.current;
    const t = setTimeout(async () => {
      setLoading(true);
      try {
        const res = await searchPros({ query, categoryId });
        if (id === seq.current) setItems(res);
      } catch {
        if (id === seq.current) setItems([]);
      } finally {
        if (id === seq.current) setLoading(false);
      }
    }, 300);
    return () => clearTimeout(t);
  }, [query, categoryId]);

  return (
    <SafeAreaView style={{ flex: 1, backgroundColor: C.bg }} edges={['top']}>
      <Text style={[styles.h2, { paddingHorizontal: 20, paddingTop: 8 }]}>Recherche</Text>
      <View style={{ paddingHorizontal: 16, paddingTop: 12 }}>
        <Input icon="search" placeholder="Plombier, électricien, coiffeuse…" value={query} onChangeText={setQuery} autoCorrect={false} />
      </View>
      {category ? (
        <Pressable
          onPress={() => router.setParams({ category: undefined, name: undefined })}
          style={{ alignSelf: 'flex-start', marginLeft: 16, marginTop: 10 }}>
          <View style={[styles.row, { backgroundColor: C.primarySoft, paddingHorizontal: 12, paddingVertical: 6, borderRadius: 20 }]}>
            <Text style={{ color: C.primary, fontFamily: F.bold }}>{category.name}  ✕</Text>
          </View>
        </Pressable>
      ) : null}
      <FlatList
        data={items}
        keyExtractor={(p) => p.id}
        renderItem={({ item, index }) => <ProTile pro={item} index={index} />}
        ListEmptyComponent={
          loading ? (
            <ActivityIndicator color={C.primary} style={{ marginTop: 30 }} />
          ) : (
            <Empty icon="search-outline" title="Aucun résultat" text="Essayez un autre mot ou une autre catégorie." />
          )
        }
        contentContainerStyle={{ paddingTop: 8, paddingBottom: 110 }}
        keyboardShouldPersistTaps="handled"
      />
    </SafeAreaView>
  );
}
