import { Ionicons } from '@expo/vector-icons';
import { Image } from 'expo-image';
import { LinearGradient } from 'expo-linear-gradient';
import { router, useFocusEffect } from 'expo-router';
import { useCallback, useState } from 'react';
import { ActivityIndicator, Animated, Dimensions, Pressable, ScrollView, Text, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

import { ProCardBig } from '@/components/ProTile';
import { Button, Empty, FadeIn, Logo, Pressy, Rise, styles, tap } from '@/components/ui';
import { categoryIcon, families, searchPros, type Category, type ProCard } from '@/lib/api';
import { useSession } from '@/lib/session';
import { C, F, brandGradient, people, shadow } from '@/lib/theme';

const { width: W, height: H } = Dimensions.get('window');
const CARD = Math.round(W * 0.6);
const GAP = 14;
const BANNER = Math.round(Math.min(Math.max(H * 0.19, 128), 168));

/**
 * Accueil « application mobile » : l'écran est fixe et tient en entier (aucun défilement vertical).
 * En-tête · recherche · bannière · catégories (glisser à l'horizontale) · carrousel des pros.
 */
export default function Home() {
  const { profile } = useSession();
  const [cats, setCats] = useState<Category[]>([]);
  const [pros, setPros] = useState<ProCard[] | null>(null);
  const [error, setError] = useState(false);
  const x = useState(() => new Animated.Value(0))[0];

  useFocusEffect(
    useCallback(() => {
      let alive = true;
      Promise.all([families(), searchPros({ sort: 'rating' })])
        .then(([c, p]) => {
          if (!alive) return;
          setCats(c);
          setPros(p);
          setError(false);
        })
        .catch(() => alive && setError(true));
      return () => {
        alive = false;
      };
    }, []),
  );

  const first = (profile?.fullName ?? '').trim().split(/\s+/)[0];
  const hour = new Date().getHours();
  const hello = hour < 18 ? 'Bonjour' : 'Bonsoir';

  return (
    <SafeAreaView style={{ flex: 1, backgroundColor: C.bg }} edges={['top']}>
      {/* En-tête */}
      <View style={[styles.row, { paddingHorizontal: 20, paddingTop: 6, height: 52 }]}>
        <View style={{ flex: 1 }}>
          <Text style={{ fontFamily: F.medium, color: C.muted, fontSize: 13 }}>{hello}{first ? ` ${first}` : ''} 👋</Text>
          <Logo height={24} />
        </View>
        <Pressy onPress={() => router.push('/settings')} style={headerBtn}>
          <Ionicons name="settings-outline" size={21} color={C.text} />
        </Pressy>
      </View>

      {/* Recherche */}
      <Pressy onPress={() => router.push('/search')} style={{ marginHorizontal: 16, marginTop: 10 }}>
        <View style={[styles.row, { backgroundColor: '#fff', height: 50, borderRadius: 25, paddingLeft: 18, paddingRight: 6, ...shadow }]}>
          <Ionicons name="search" size={19} color={C.muted} />
          <Text style={{ flex: 1, marginLeft: 10, color: '#94A3B8', fontFamily: F.body, fontSize: 14.5 }}>Plombier, coiffeuse, électricien…</Text>
          <LinearGradient colors={brandGradient} style={{ width: 38, height: 38, borderRadius: 19, alignItems: 'center', justifyContent: 'center' }}>
            <Ionicons name="arrow-forward" size={18} color="#fff" />
          </LinearGradient>
        </View>
      </Pressy>

      {/* Bannière : homme détouré, jamais rogné */}
      <FadeIn index={1}>
        <LinearGradient
          colors={brandGradient}
          start={{ x: 0, y: 0 }}
          end={{ x: 1, y: 1 }}
          style={{ height: BANNER, marginHorizontal: 16, marginTop: 14, borderRadius: 24, overflow: 'hidden', paddingLeft: 18, paddingVertical: 16 }}>
          <View style={{ position: 'absolute', right: -24, bottom: -60, width: BANNER * 1.25, height: BANNER * 1.25, borderRadius: 999, backgroundColor: 'rgba(255,255,255,0.12)' }} />
          <View style={{ position: 'absolute', right: 70, top: -30, width: 70, height: 70, borderRadius: 35, backgroundColor: 'rgba(255,122,26,0.55)' }} />
          <Rise style={{ position: 'absolute', right: 4, top: 10, bottom: 0, width: '44%' }}>
            <Image source={people.business} style={{ flex: 1 }} contentFit="contain" contentPosition="bottom" />
          </Rise>
          <View style={{ width: '56%', flex: 1, justifyContent: 'space-between' }}>
            <Text style={{ color: '#fff', fontFamily: F.displayHeavy, fontSize: 18, lineHeight: 23 }}>Trouvez le meilleur service près de vous</Text>
            <Button label="Découvrir" icon="arrow-forward" variant="accent" onPress={() => router.push('/search')} style={{ alignSelf: 'flex-start' }} />
          </View>
        </LinearGradient>
      </FadeIn>

      {/* Catégories : une seule ligne qui glisse */}
      <SectionTitle title="Catégories" />
      <ScrollView
        horizontal
        showsHorizontalScrollIndicator={false}
        overScrollMode="never"
        contentContainerStyle={{ paddingHorizontal: 12 }}
        style={{ flexGrow: 0 }}>
        {cats.map((c, i) => (
          <FadeIn key={c.id} index={i} style={{ width: 78, alignItems: 'center' }}>
            <Pressy onPress={() => router.push({ pathname: '/search', params: { category: c.id, name: c.name } })} style={{ alignItems: 'center' }}>
              <LinearGradient
                colors={i % 2 ? ['#FFB066', C.accent] : ['#4F86FF', C.primary]}
                style={{ width: 54, height: 54, borderRadius: 18, alignItems: 'center', justifyContent: 'center', transform: [{ rotate: '-6deg' }] }}>
                <Ionicons name={categoryIcon(c.icon) as keyof typeof Ionicons.glyphMap} size={25} color="#fff" style={{ transform: [{ rotate: '6deg' }] }} />
              </LinearGradient>
              <Text numberOfLines={1} style={{ fontFamily: F.semibold, fontSize: 11.5, marginTop: 6, color: C.text, maxWidth: 74 }}>
                {c.name}
              </Text>
            </Pressy>
          </FadeIn>
        ))}
      </ScrollView>

      {/* Carrousel des professionnels : prend toute la place restante */}
      <SectionTitle title="Professionnels" action="Voir tout" onAction={() => router.push('/search')} />
      <View style={{ flex: 1, paddingBottom: 86 }}>
        {pros === null ? (
          error ? (
            <Empty icon="cloud-offline-outline" title="Connexion impossible" text="Vérifiez votre connexion internet." />
          ) : (
            <ActivityIndicator color={C.primary} style={{ marginTop: 30 }} />
          )
        ) : pros.length === 0 ? (
          <Empty icon="people-outline" title="Aucun professionnel publié pour le moment." />
        ) : (
          <Animated.FlatList
            data={pros}
            horizontal
            keyExtractor={(p) => p.id}
            showsHorizontalScrollIndicator={false}
            overScrollMode="never"
            snapToInterval={CARD + GAP}
            decelerationRate="fast"
            onMomentumScrollEnd={tap}
            contentContainerStyle={{ paddingHorizontal: 16, paddingBottom: 8, gap: GAP }}
            onScroll={Animated.event([{ nativeEvent: { contentOffset: { x } } }], { useNativeDriver: true })}
            scrollEventThrottle={16}
            renderItem={({ item, index }) => {
              const pos = index * (CARD + GAP);
              const scale = x.interpolate({ inputRange: [pos - CARD, pos, pos + CARD], outputRange: [0.92, 1, 0.92], extrapolate: 'clamp' });
              return (
                <Rise index={Math.min(index, 3)} style={{ flex: 1 }}>
                  <Animated.View style={{ flex: 1, transform: [{ scale }] }}>
                    <ProCardBig pro={item} width={CARD} />
                  </Animated.View>
                </Rise>
              );
            }}
          />
        )}
      </View>
    </SafeAreaView>
  );
}

const headerBtn = { width: 42, height: 42, borderRadius: 21, backgroundColor: '#fff', alignItems: 'center', justifyContent: 'center', ...shadow } as const;

function SectionTitle({ title, action, onAction }: { title: string; action?: string; onAction?: () => void }) {
  return (
    <View style={[styles.row, { paddingHorizontal: 20, marginTop: 14, marginBottom: 10 }]}>
      <Text style={[styles.h3, { flex: 1 }]}>{title}</Text>
      {action ? (
        <Pressable onPress={onAction} hitSlop={8} style={styles.row}>
          <Text style={{ color: C.primary, fontFamily: F.bold, fontSize: 13 }}>{action}</Text>
          <Ionicons name="chevron-forward" size={15} color={C.primary} />
        </Pressable>
      ) : null}
    </View>
  );
}
