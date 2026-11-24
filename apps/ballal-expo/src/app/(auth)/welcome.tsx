import { Image } from 'expo-image';
import { LinearGradient } from 'expo-linear-gradient';
import { router } from 'expo-router';
import { useRef, useState } from 'react';
import { Animated, Dimensions, FlatList, Pressable, Text, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

import { Button, FadeIn, Logo, styles } from '@/components/ui';
import { useSession } from '@/lib/session';
import { C, F, people } from '@/lib/theme';

const W = Dimensions.get('window').width;

const slides = [
  { photos: ['business'] as const, title: 'Trouvez facilement des services près de vous', text: 'Rapide · Fiable · Proche de vous' },
  { photos: ['plumber', 'builder'] as const, title: 'Des professionnels de confiance', text: 'Plombiers, électriciens, maçons… Comparez les avis et discutez directement dans BALLAL.' },
  { photos: ['beauty', 'chef', 'doctor', 'delivery'] as const, title: 'Tous les métiers, près de chez vous', text: 'Beauté, cuisine, santé, livraison… Créez votre compte et trouvez le bon pro en quelques secondes.' },
];

function Photo({ name, style }: { name: keyof typeof people; style?: object }) {
  return (
    <View style={[{ flex: 1, borderRadius: 24, overflow: 'hidden', shadowColor: C.primary, shadowOpacity: 0.18, shadowRadius: 18, elevation: 4 }, style]}>
      <Image source={people[name]} style={{ flex: 1 }} contentFit="cover" contentPosition="top" transition={400} />
      <LinearGradient colors={['transparent', 'rgba(11,42,111,0.2)']} style={{ position: 'absolute', left: 0, right: 0, bottom: 0, height: '40%' }} />
    </View>
  );
}

/** Écrans de présentation (identiques à la version Flutter v16) : photos en cadres arrondis. */
export default function Welcome() {
  const { markOnboardingSeen } = useSession();
  const [page, setPage] = useState(0);
  const list = useRef<FlatList>(null);
  const x = useState(() => new Animated.Value(0))[0];
  const last = page === slides.length - 1;

  const finish = async () => {
    await markOnboardingSeen();
    router.replace('/login');
  };

  return (
    <SafeAreaView style={{ flex: 1, backgroundColor: '#fff' }}>
      <View style={[styles.row, { paddingHorizontal: 24, paddingTop: 8, height: 48 }]}>
        <Logo height={30} />
        <View style={{ flex: 1 }} />
        {!last ? (
          <Pressable onPress={finish} hitSlop={10}>
            <Text style={{ color: C.primary, fontFamily: F.bold }}>Passer</Text>
          </Pressable>
        ) : null}
      </View>
      <Animated.FlatList
        ref={list}
        data={slides}
        horizontal
        pagingEnabled
        showsHorizontalScrollIndicator={false}
        keyExtractor={(_, i) => String(i)}
        onScroll={Animated.event([{ nativeEvent: { contentOffset: { x } } }], { useNativeDriver: true })}
        onMomentumScrollEnd={(e) => setPage(Math.round(e.nativeEvent.contentOffset.x / W))}
        renderItem={({ item, index }) => {
          const opacity = x.interpolate({ inputRange: [(index - 1) * W, index * W, (index + 1) * W], outputRange: [0, 1, 0] });
          return (
            <Animated.View style={{ width: W, paddingHorizontal: 24, opacity }}>
              <FadeIn>
                <Text style={[styles.h1, { marginTop: 16 }]}>{item.title}</Text>
                <Text style={{ color: C.primary, fontFamily: F.semibold, fontSize: 15, marginTop: 10, lineHeight: 21 }}>{item.text}</Text>
              </FadeIn>
              <View style={{ flex: 1, marginTop: 20, marginBottom: 8 }}>
                {item.photos.length === 1 ? (
                  <FadeIn index={1} style={{ flex: 1 }}>
                    <Photo name={item.photos[0]} />
                  </FadeIn>
                ) : item.photos.length === 2 ? (
                  <View style={{ flex: 1, flexDirection: 'row', gap: 12 }}>
                    <FadeIn index={1} style={{ flex: 1 }}>
                      <Photo name={item.photos[0]} />
                    </FadeIn>
                    <FadeIn index={2} style={{ flex: 1, paddingTop: 36 }}>
                      <Photo name={item.photos[1]} />
                    </FadeIn>
                  </View>
                ) : (
                  <View style={{ flex: 1, gap: 12 }}>
                    {[0, 2].map((r) => (
                      <View key={r} style={{ flex: 1, flexDirection: 'row', gap: 12 }}>
                        <FadeIn index={r + 1} style={{ flex: 1 }}>
                          <Photo name={item.photos[r]} />
                        </FadeIn>
                        <FadeIn index={r + 2} style={{ flex: 1 }}>
                          <Photo name={item.photos[r + 1]} />
                        </FadeIn>
                      </View>
                    ))}
                  </View>
                )}
              </View>
            </Animated.View>
          );
        }}
      />
      <View style={[styles.row, { justifyContent: 'center', marginTop: 8 }]}>
        {slides.map((_, i) => (
          <View
            key={i}
            style={{ width: i === page ? 24 : 8, height: 8, borderRadius: 8, marginHorizontal: 4, backgroundColor: i === page ? C.primary : C.border }}
          />
        ))}
      </View>
      <View style={{ padding: 24, paddingTop: 18 }}>
        <Button
          label={last ? 'Commencer' : 'Suivant'}
          icon="arrow-forward"
          onPress={() => (last ? finish() : list.current?.scrollToIndex({ index: page + 1, animated: true }))}
        />
      </View>
    </SafeAreaView>
  );
}
