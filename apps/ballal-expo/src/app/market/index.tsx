import { Ionicons } from '@expo/vector-icons';
import { LinearGradient } from 'expo-linear-gradient';
import { router, useFocusEffect } from 'expo-router';
import { useCallback, useEffect, useRef, useState } from 'react';
import { ActivityIndicator, Dimensions, FlatList, Pressable, RefreshControl, ScrollView, Text, TextInput, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

import { ListingCard } from '@/components/ListingCard';
import { Empty, FadeIn, Pressy, styles } from '@/components/ui';
import { MARKET_CATEGORIES, marketFeed, type Listing } from '@/lib/market';
import { useSession } from '@/lib/session';
import { C, F, shadow } from '@/lib/theme';

const W = Dimensions.get('window').width;
const COL = (W - 16 * 2 - 12) / 2;

/** Marketplace : les pros publient leurs articles ; tout le monde consulte et commande auprès du vendeur. */
export default function Market() {
  const { session, profile } = useSession();
  const insets = useSafeAreaInsets();
  const uid = session?.user.id;
  const isPro = !!profile?.roles.includes('professional');
  const [cat, setCat] = useState<string | null>(null);
  const [q, setQ] = useState('');
  const [mine, setMine] = useState(false);
  const [items, setItems] = useState<Listing[] | null>(null);
  const [refreshing, setRefreshing] = useState(false);
  const seq = useRef(0);

  const load = useCallback(async () => {
    const id = ++seq.current;
    try {
      const res = await marketFeed({ category: cat, query: q, seller: mine ? uid : undefined });
      if (id === seq.current) setItems(res);
    } catch {
      if (id === seq.current) setItems((v) => v ?? []);
    }
  }, [cat, q, mine, uid]);

  useEffect(() => {
    const t = setTimeout(load, 280);
    return () => clearTimeout(t);
  }, [load]);

  useFocusEffect(
    useCallback(() => {
      load();
    }, [load]),
  );

  return (
    <View style={{ flex: 1, backgroundColor: C.bg }}>
      {/* En-tête dégradé orange : retour, titre, « Mes annonces », recherche */}
      <LinearGradient colors={['#FF9A3D', C.accent, '#F25C05']} start={{ x: 0, y: 0 }} end={{ x: 1, y: 1 }} style={{ paddingTop: insets.top + 6, paddingBottom: 18, borderBottomLeftRadius: 28, borderBottomRightRadius: 28 }}>
        <View style={{ position: 'absolute', right: -40, top: -30, width: 160, height: 160, borderRadius: 80, backgroundColor: 'rgba(255,255,255,0.12)' }} />
        <View style={[styles.row, { paddingHorizontal: 12 }]}>
          <Pressable onPress={() => router.back()} hitSlop={10} style={{ padding: 6 }}>
            <Ionicons name="chevron-back" size={26} color="#fff" />
          </Pressable>
          <View style={{ flex: 1, marginLeft: 4 }}>
            <Text style={{ color: '#fff', fontFamily: F.displayHeavy, fontSize: 24 }}>Marketplace</Text>
            <Text style={{ color: 'rgba(255,255,255,0.88)', fontFamily: F.medium, fontSize: 12.5 }} numberOfLines={1}>Commandez auprès des pros près de vous</Text>
          </View>
          {isPro ? (
          <Pressy onPress={() => setMine(!mine)} style={[styles.row, { backgroundColor: mine ? '#fff' : 'rgba(255,255,255,0.18)', borderRadius: 18, paddingHorizontal: 12, height: 36 }]}>
            <Ionicons name="pricetags-outline" size={15} color={mine ? C.accent : '#fff'} />
            <Text style={{ marginLeft: 5, fontFamily: F.bold, fontSize: 12.5, color: mine ? C.accent : '#fff' }}>Mes annonces</Text>
          </Pressy>
          ) : null}
        </View>

      <View style={[styles.row, { marginHorizontal: 16, marginTop: 14, backgroundColor: '#fff', borderRadius: 22, height: 46, paddingHorizontal: 16, ...shadow }]}>
        <Ionicons name="search" size={18} color={C.muted} />
        <TextInput
          value={q}
          onChangeText={setQ}
          placeholder="Téléphone, chaussures, frigo…"
          placeholderTextColor="#94A3B8"
          style={{ flex: 1, marginLeft: 10, fontFamily: F.body, fontSize: 14.5, color: C.text }}
        />
      </View>
      </LinearGradient>

      <ScrollView horizontal showsHorizontalScrollIndicator={false} overScrollMode="never" style={{ flexGrow: 0, height: 46, marginTop: 8 }} contentContainerStyle={{ paddingHorizontal: 16, gap: 8, alignItems: 'center' }}>
        {[{ key: null, label: 'Tout', icon: 'apps' } as const, ...MARKET_CATEGORIES].map((c) => {
          const on = cat === c.key;
          return (
            <Pressable key={c.key ?? 'all'} onPress={() => setCat(c.key)}>
              <View style={[styles.row, { height: 34, paddingHorizontal: 12, borderRadius: 17, backgroundColor: on ? C.primary : '#fff', borderWidth: 1, borderColor: on ? C.primary : C.border }]}>
                <Ionicons name={c.icon as keyof typeof Ionicons.glyphMap} size={14} color={on ? '#fff' : C.primary} />
                <Text style={{ marginLeft: 5, fontFamily: F.semibold, fontSize: 12.5, color: on ? '#fff' : C.text }}>{c.label}</Text>
              </View>
            </Pressable>
          );
        })}
      </ScrollView>

      {items === null ? (
        <ActivityIndicator color={C.primary} style={{ marginTop: 40 }} />
      ) : (
        <FlatList
          data={items}
          keyExtractor={(l) => l.id}
          numColumns={2}
          columnWrapperStyle={{ gap: 12, paddingHorizontal: 16 }}
          contentContainerStyle={{ gap: 12, paddingTop: 14, paddingBottom: 110 }}
          overScrollMode="never"
          refreshControl={
            <RefreshControl
              refreshing={refreshing}
              tintColor={C.primary}
              onRefresh={async () => {
                setRefreshing(true);
                await load();
                setRefreshing(false);
              }}
            />
          }
          ListEmptyComponent={
            <Empty
              icon="storefront-outline"
              title={mine ? 'Vous n’avez encore rien publié' : 'Aucun article pour le moment'}
              text={isPro ? 'Touchez « Vendre » pour publier votre premier article.' : 'Les professionnels publient ici leurs articles. Revenez bientôt.'}
            />
          }
          renderItem={({ item, index }) => (
            <FadeIn index={index % 8}>
              <ListingCard item={item} width={COL} />
            </FadeIn>
          )}
        />
      )}

      {/* Bouton flottant « Vendre » */}
      {isPro ? (
      <Pressy onPress={() => router.push('/market/new')} style={{ position: 'absolute', right: 18, bottom: insets.bottom + 24 }}>
        <LinearGradient colors={['#FF9A3D', C.accent, '#FF5A00']} style={[styles.row, { height: 52, borderRadius: 26, paddingHorizontal: 20, shadowColor: C.accent, shadowOpacity: 0.4, shadowRadius: 14, shadowOffset: { width: 0, height: 6 }, elevation: 8 }]}>
          <Ionicons name="add-circle" size={22} color="#fff" />
          <Text style={{ color: '#fff', fontFamily: F.heavy, fontSize: 15, marginLeft: 6 }}>Vendre</Text>
        </LinearGradient>
      </Pressy>
      ) : null}
    </View>
  );
}

