import { Ionicons } from '@expo/vector-icons';
import { Image } from 'expo-image';
import { LinearGradient } from 'expo-linear-gradient';
import { router, useFocusEffect } from 'expo-router';
import { useCallback, useEffect, useState } from 'react';
import { ActivityIndicator, Animated, Dimensions, FlatList, Pressable, ScrollView, Text, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

import { ProTile } from '@/components/ProTile';
import { Button, FadeIn, Logo, Pressy, Rise, styles } from '@/components/ui';
import { categoryIcon, families, searchPros, type Category, type ProCard } from '@/lib/api';
import { useSession } from '@/lib/session';
import { supabase } from '@/lib/supabase';
import { C, F, brandGradient, people, shadow } from '@/lib/theme';

const { height: H } = Dimensions.get('window');
const BANNER = Math.round(Math.min(Math.max(H * 0.16, 128), 150));

/**
 * Accueil « application mobile » : l'écran est fixe et tient en entier (aucun défilement vertical).
 * En-tête (chariot Marketplace, réglages) · recherche · bannière · catégories · pros en liste compacte.
 */
export default function Home() {
  const { profile, session } = useSession();
  const isPro = !!profile?.roles.includes('professional');
  const [needVerify, setNeedVerify] = useState(false);

  // Pro non vérifié (et sans demande en cours) : bandeau d'invitation à chaque ouverture.
  useFocusEffect(
    useCallback(() => {
      const uid = session?.user.id;
      if (!isPro || !uid) return;
      let alive = true;
      Promise.all([
        supabase.from('professional_profiles').select('identity_verified, company_verified').eq('user_id', uid).maybeSingle(),
        supabase.from('verification_documents').select('id').eq('user_id', uid).eq('status', 'pending').limit(1),
      ])
        .then(([{ data: p }, { data: d }]) => alive && setNeedVerify(!!p && !p.identity_verified && !p.company_verified && !(d?.length ?? 0)))
        .catch(() => undefined);
      return () => {
        alive = false;
      };
    }, [isPro, session?.user.id]),
  );
  const [cats, setCats] = useState<Category[]>([]);
  const [pros, setPros] = useState<ProCard[] | null>(null);
  const [error, setError] = useState(false);

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
          <Text style={{ fontFamily: F.medium, color: C.muted, fontSize: 13 }}>{hello}{first ? ` ${first}` : ''} </Text>
          <Logo height={24} />
        </View>
        <Pressy onPress={() => router.push('/market')} style={{ marginRight: 10 }}>
          <LinearGradient colors={['#FF9A3D', C.accent]} style={{ width: 42, height: 42, borderRadius: 21, alignItems: 'center', justifyContent: 'center', ...shadow }}>
            <Ionicons name="cart" size={21} color="#fff" />
          </LinearGradient>
        </Pressy>
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

      {needVerify ? (
        <Pressy onPress={() => router.push('/verification')} style={{ marginHorizontal: 16, marginTop: 10 }}>
          <LinearGradient colors={['#10B981', '#057A55']} start={{ x: 0, y: 0 }} end={{ x: 1, y: 0 }} style={[styles.row, { borderRadius: 16, paddingHorizontal: 14, paddingVertical: 10 }]}>
            <Ionicons name="shield-checkmark" size={20} color="#fff" />
            <Text numberOfLines={1} style={{ flex: 1, marginLeft: 10, color: '#fff', fontFamily: F.bold, fontSize: 13 }}>
              Vérifiez votre compte pour être recommandé
            </Text>
            <Ionicons name="chevron-forward" size={18} color="#fff" />
          </LinearGradient>
        </Pressy>
      ) : null}

      {/* Bannière : homme détouré, jamais rogné */}
      <FadeIn index={1}>
        <LinearGradient
          colors={brandGradient}
          start={{ x: 0, y: 0 }}
          end={{ x: 1, y: 1 }}
          style={{ height: BANNER, marginHorizontal: 16, marginTop: 14, borderRadius: 24, overflow: 'hidden', paddingLeft: 18, paddingVertical: 14 }}>
          <View style={{ position: 'absolute', right: -24, bottom: -60, width: BANNER * 1.25, height: BANNER * 1.25, borderRadius: 999, backgroundColor: 'rgba(255,255,255,0.12)' }} />
          <View style={{ position: 'absolute', right: 70, top: -30, width: 70, height: 70, borderRadius: 35, backgroundColor: 'rgba(255,122,26,0.55)' }} />
          <Rise style={{ position: 'absolute', right: 4, top: 10, bottom: 0, width: '44%' }}>
            <Image source={people.business} style={{ flex: 1 }} contentFit="contain" contentPosition="bottom" />
          </Rise>
          <View style={{ width: '56%', flex: 1, justifyContent: 'space-between' }}>
            <Text style={{ color: '#fff', fontFamily: F.displayHeavy, fontSize: 17, lineHeight: 22 }}>Le bon pro,{'\n'}près de chez vous</Text>
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

      {/* Professionnels : liste compacte (cartes fines) dans l'espace restant */}
      <SectionTitle title="Professionnels" action="Voir tout" onAction={() => router.push('/search')} />
      <View style={{ flex: 1 }}>
        {pros === null ? (
          error ? (
            <Text style={[styles.muted, { marginLeft: 20 }]}>Connexion impossible. Vérifiez internet.</Text>
          ) : (
            <ActivityIndicator color={C.primary} style={{ marginTop: 30 }} />
          )
        ) : pros.length === 0 ? (
          <Text style={[styles.muted, { marginLeft: 20 }]}>Aucun professionnel publié pour le moment.</Text>
        ) : (
          <FlatList
            data={pros}
            keyExtractor={(p) => p.id}
            showsVerticalScrollIndicator={false}
            overScrollMode="never"
            bounces={false}
            contentContainerStyle={{ paddingBottom: 100 }}
            renderItem={({ item, index }) => <ProTile pro={item} index={index} compact />}
          />
        )}
      </View>

      {/* Assistant Ballal : bulle flottante au-dessus de la barre du bas */}
      <AssistantBubble />
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

/** Bulle flottante qui ouvre l'assistant, avec une légère pulsation pour attirer l'œil. */
function AssistantBubble() {
  const pulse = useState(() => new Animated.Value(0))[0];
  useEffect(() => {
    const loop = Animated.loop(
      Animated.sequence([
        Animated.timing(pulse, { toValue: 1, duration: 1400, useNativeDriver: true }),
        Animated.timing(pulse, { toValue: 0, duration: 0, useNativeDriver: true }),
        Animated.delay(1800),
      ]),
    );
    loop.start();
    return () => loop.stop();
  }, [pulse]);
  return (
    <View pointerEvents="box-none" style={{ position: 'absolute', right: 18, bottom: 104 }}>
      <Animated.View
        pointerEvents="none"
        style={{
          position: 'absolute',
          width: 58,
          height: 58,
          borderRadius: 29,
          backgroundColor: C.primary,
          opacity: pulse.interpolate({ inputRange: [0, 1], outputRange: [0.35, 0] }),
          transform: [{ scale: pulse.interpolate({ inputRange: [0, 1], outputRange: [1, 1.7] }) }],
        }}
      />
      <Pressy onPress={() => router.push('/assistant')}>
        <LinearGradient colors={brandGradient} start={{ x: 0, y: 0 }} end={{ x: 1, y: 1 }} style={{ width: 58, height: 58, borderRadius: 29, alignItems: 'center', justifyContent: 'center', ...shadow }}>
          <Ionicons name="chatbubble-ellipses" size={26} color="#fff" />
        </LinearGradient>
      </Pressy>
    </View>
  );
}
