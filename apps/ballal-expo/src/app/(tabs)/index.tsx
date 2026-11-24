import { Ionicons } from '@expo/vector-icons';
import { Image } from 'expo-image';
import { LinearGradient } from 'expo-linear-gradient';
import { router } from 'expo-router';
import { useCallback, useEffect, useState } from 'react';
import { ActivityIndicator, FlatList, Pressable, RefreshControl, Text, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

import { ProTile } from '@/components/ProTile';
import { Button, Card, Empty, FadeIn, Logo, SectionHeader, styles } from '@/components/ui';
import { categoryIcon, families, searchPros, type Category, type ProCard } from '@/lib/api';
import { C, F, brandGradient, people } from '@/lib/theme';

/** Accueil : bannière, catégories, tous les professionnels publiés (comme la version Flutter v16). */
export default function Home() {
  const [cats, setCats] = useState<Category[]>([]);
  const [pros, setPros] = useState<ProCard[]>([]);
  const [loading, setLoading] = useState(true);
  const [more, setMore] = useState(true);
  const [error, setError] = useState(false);

  const load = useCallback(async (reset = false) => {
    try {
      const [c, page] = await Promise.all([reset || cats.length === 0 ? families() : Promise.resolve(cats), searchPros({ sort: 'rating', offset: reset ? 0 : pros.length })]);
      setError(false);
      setCats(c);
      setPros((prev) => (reset ? page : [...prev, ...page.filter((p) => !prev.some((x) => x.id === p.id))]));
      setMore(page.length >= 20);
    } catch {
      setError(true);
    } finally {
      setLoading(false);
    }
  }, [cats, pros.length]);

  // Premier chargement (déclenché hors du rendu)
  useEffect(() => {
    const t = setTimeout(() => load(true), 0);
    return () => clearTimeout(t);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const header = (
    <View>
      <View style={[styles.row, { paddingHorizontal: 20, paddingTop: 8 }]}>
        <Logo height={30} />
        <View style={{ flex: 1 }} />
        <Pressable onPress={() => router.push('/settings')} hitSlop={10}>
          <Ionicons name="settings-outline" size={25} color={C.text} />
        </Pressable>
      </View>

      <Pressable onPress={() => router.push('/search')} style={{ marginHorizontal: 16, marginTop: 14 }}>
        <View style={[styles.input, { pointerEvents: 'none' }]}>
          <Ionicons name="search" size={20} color={C.muted} style={{ marginRight: 10 }} />
          <Text style={{ color: '#94A3B8', fontFamily: F.body, fontSize: 15 }}>Rechercher un service…</Text>
        </View>
      </Pressable>

      {/* Bannière bleue avec l'homme au pouce levé */}
      <FadeIn>
        <LinearGradient
          colors={brandGradient}
          start={{ x: 0, y: 0 }}
          end={{ x: 1, y: 1 }}
          style={{ height: 168, marginHorizontal: 16, marginTop: 16, borderRadius: 22, overflow: 'hidden', padding: 20 }}>
          <View style={{ position: 'absolute', right: -30, bottom: -50, width: 190, height: 190, borderRadius: 95, backgroundColor: 'rgba(255,255,255,0.08)' }} />
          <View style={{ position: 'absolute', right: 14, top: 14, bottom: 14, aspectRatio: 0.82, borderRadius: 20, borderWidth: 3, borderColor: 'rgba(255,255,255,0.9)', overflow: 'hidden' }}>
            <Image source={people.business} style={{ flex: 1 }} contentFit="cover" contentPosition="top" />
          </View>
          <View style={{ width: '50%', flex: 1, justifyContent: 'space-between' }}>
            <Text style={{ color: '#fff', fontFamily: F.displayHeavy, fontSize: 19, lineHeight: 24 }}>Trouvez le meilleur service près de vous</Text>
            <Button label="Découvrir" icon="arrow-forward" variant="accent" onPress={() => router.push('/search')} style={{ alignSelf: 'flex-start' }} />
          </View>
        </LinearGradient>
      </FadeIn>

      <SectionHeader title="Catégories" />
      <View style={{ flexDirection: 'row', flexWrap: 'wrap', paddingHorizontal: 12 }}>
        {cats.slice(0, 6).map((c, i) => (
          <View key={c.id} style={{ width: '33.33%', padding: 4 }}>
            <FadeIn index={i}>
              <Card onPress={() => router.push({ pathname: '/search', params: { category: c.id, name: c.name } })} style={{ alignItems: 'center', paddingVertical: 14, paddingHorizontal: 6 }}>
                <View style={{ backgroundColor: i % 2 ? C.primarySoft : C.accentSoft, width: 48, height: 48, borderRadius: 24, alignItems: 'center', justifyContent: 'center' }}>
                  <Ionicons name={categoryIcon(c.icon) as keyof typeof Ionicons.glyphMap} size={24} color={i % 2 ? C.primary : C.accent} />
                </View>
                <Text numberOfLines={2} style={{ fontFamily: F.semibold, fontSize: 12, marginTop: 6, textAlign: 'center', color: C.text }}>
                  {c.name}
                </Text>
              </Card>
            </FadeIn>
          </View>
        ))}
      </View>

      <SectionHeader title="Tous les professionnels" action="Voir tout" onAction={() => router.push('/search')} />
    </View>
  );

  return (
    <SafeAreaView style={{ flex: 1, backgroundColor: C.bg }} edges={['top']}>
      <FlatList
        data={pros}
        keyExtractor={(p) => p.id}
        renderItem={({ item, index }) => <ProTile pro={item} index={index} />}
        ListHeaderComponent={header}
        ListEmptyComponent={
          loading ? (
            <ActivityIndicator color={C.primary} style={{ marginTop: 24 }} />
          ) : error ? (
            <Empty icon="cloud-offline-outline" title="Connexion impossible" text="Vérifiez votre connexion puis tirez vers le bas." />
          ) : (
            <Empty icon="people-outline" title="Aucun professionnel publié pour le moment." />
          )
        }
        onEndReached={() => more && !loading && load()}
        onEndReachedThreshold={0.4}
        refreshControl={<RefreshControl refreshing={false} onRefresh={() => load(true)} tintColor={C.primary} />}
        contentContainerStyle={{ paddingBottom: 110 }}
      />
    </SafeAreaView>
  );
}
