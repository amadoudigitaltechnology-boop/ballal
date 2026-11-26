import { Ionicons } from '@expo/vector-icons';
import { Image } from 'expo-image';
import { LinearGradient } from 'expo-linear-gradient';
import { router, useLocalSearchParams } from 'expo-router';
import { useEffect, useState } from 'react';
import { ActivityIndicator, Alert, Dimensions, FlatList, Pressable, ScrollView, Text, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

import { ProPhoto } from '@/components/ProTile';
import { Button, Card, Empty, FadeIn, styles } from '@/components/ui';
import { timeAgo } from '@/lib/api';
import { categoryLabel, contactSeller, deleteListing, getListing, gnf, marketPhoto, setListingStatus, type Listing } from '@/lib/market';
import { useSession } from '@/lib/session';
import { friendlyError, supabase } from '@/lib/supabase';
import { C, F } from '@/lib/theme';

const W = Dimensions.get('window').width;

/** Fiche d'un article : photos à faire glisser, prix, état, vendeur, description, contact. */
export default function ListingScreen() {
  const { id } = useLocalSearchParams<{ id: string }>();
  const insets = useSafeAreaInsets();
  const { session } = useSession();
  const [item, setItem] = useState<Listing | null | undefined>(undefined);
  const [page, setPage] = useState(0);
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    getListing(id).then(setItem).catch(() => setItem(null));
    supabase.rpc('record_listing_view', { p_listing: id }).then(() => undefined);
  }, [id]);

  if (item === undefined) return <ActivityIndicator color={C.primary} style={{ flex: 1 }} />;
  if (item === null) return <Empty icon="cube-outline" title="Article introuvable" text="Il a peut-être été vendu ou retiré." />;
  const mine = item.sellerId === session?.user.id;
  const photos = item.photos.length ? item.photos : [null];

  const contact = async () => {
    setBusy(true);
    try {
      const conv = await contactSeller(item.id);
      router.push({ pathname: '/chat/[id]', params: { id: conv, name: item.sellerName, avatar: item.sellerAvatar ?? '', pro: '0', other: item.sellerId } });
    } catch (e) {
      Alert.alert('BALLAL', friendlyError(e));
    } finally {
      setBusy(false);
    }
  };

  const toggleSold = async () => {
    const next = item.status === 'sold' ? 'active' : 'sold';
    try {
      await setListingStatus(item.id, next);
      setItem({ ...item, status: next });
    } catch (e) {
      Alert.alert('BALLAL', friendlyError(e));
    }
  };

  const remove = () =>
    Alert.alert('Supprimer l’annonce', 'Cette annonce et ses photos seront effacées.', [
      { text: 'Annuler', style: 'cancel' },
      {
        text: 'Supprimer',
        style: 'destructive',
        onPress: async () => {
          try {
            await deleteListing(item);
            router.back();
          } catch (e) {
            Alert.alert('BALLAL', friendlyError(e));
          }
        },
      },
    ]);

  return (
    <View style={{ flex: 1, backgroundColor: C.bg }}>
      <ScrollView contentContainerStyle={{ paddingBottom: 130 }} overScrollMode="never" bounces={false}>
        <View style={{ height: W * 0.9, backgroundColor: C.field }}>
          <FlatList
            data={photos}
            horizontal
            pagingEnabled
            showsHorizontalScrollIndicator={false}
            keyExtractor={(p, i) => p ?? String(i)}
            onMomentumScrollEnd={(e) => setPage(Math.round(e.nativeEvent.contentOffset.x / W))}
            renderItem={({ item: p }) => {
              const url = marketPhoto(p);
              return url ? (
                <Image source={url} style={{ width: W, height: W * 0.9 }} contentFit="cover" transition={250} />
              ) : (
                <LinearGradient colors={['#E8F0FF', '#FFE7D3']} style={{ width: W, height: W * 0.9, alignItems: 'center', justifyContent: 'center' }}>
                  <Ionicons name="image-outline" size={48} color={C.muted} />
                </LinearGradient>
              );
            }}
          />
          {photos.length > 1 ? (
            <View style={[styles.row, { position: 'absolute', bottom: 14, alignSelf: 'center', gap: 5 }]}>
              {photos.map((_, i) => (
                <View key={i} style={{ width: i === page ? 18 : 7, height: 7, borderRadius: 4, backgroundColor: i === page ? '#fff' : 'rgba(255,255,255,0.55)' }} />
              ))}
            </View>
          ) : null}
          <Pressable onPress={() => router.back()} style={{ position: 'absolute', top: insets.top + 8, left: 14, backgroundColor: 'rgba(0,0,0,0.35)', borderRadius: 20, padding: 8 }}>
            <Ionicons name="arrow-back" size={22} color="#fff" />
          </Pressable>
        </View>

        <FadeIn>
          <Card style={{ marginHorizontal: 16, marginTop: -26 }}>
            <View style={styles.row}>
              <Text style={{ fontFamily: F.displayHeavy, fontSize: 22, color: C.accent, flex: 1 }}>{gnf(item.priceGnf)}</Text>
              <View style={{ backgroundColor: item.condition === 'new' ? '#DCFCE7' : C.primarySoft, borderRadius: 10, paddingHorizontal: 9, paddingVertical: 3 }}>
                <Text style={{ fontFamily: F.heavy, fontSize: 11, color: item.condition === 'new' ? C.success : C.primary }}>{item.condition === 'new' ? 'NEUF' : 'OCCASION'}</Text>
              </View>
            </View>
            <Text style={[styles.h2, { fontSize: 19, marginTop: 4 }]}>{item.title}</Text>
            <View style={[styles.row, { marginTop: 8, gap: 14, flexWrap: 'wrap' }]}>
              <Meta icon="location-outline" text={item.locationName || 'Conakry'} />
              <Meta icon="pricetag-outline" text={categoryLabel(item.category)} />
              <Meta icon="time-outline" text={timeAgo(item.createdAt)} />
              <Meta icon="eye-outline" text={`${item.views} vues`} />
            </View>
            {item.status === 'sold' ? (
              <View style={{ marginTop: 10, backgroundColor: '#FEF3C7', borderRadius: 12, padding: 10 }}>
                <Text style={{ fontFamily: F.bold, color: '#92400E' }}>Cet article est marqué comme vendu.</Text>
              </View>
            ) : null}
          </Card>
        </FadeIn>

        {item.description ? (
          <FadeIn index={1}>
            <Card style={{ marginHorizontal: 16, marginTop: 12 }}>
              <Text style={styles.h3}>Description</Text>
              <Text style={[styles.body, { marginTop: 6, lineHeight: 22 }]}>{item.description}</Text>
            </Card>
          </FadeIn>
        ) : null}

        <FadeIn index={2}>
          <Card style={[styles.row, { marginHorizontal: 16, marginTop: 12 }]}>
            <ProPhoto path={item.sellerAvatar} name={item.sellerName} size={48} radius={24} />
            <View style={{ flex: 1, marginLeft: 12 }}>
              <Text style={[styles.muted, { fontSize: 12 }]}>Vendeur</Text>
              <Text style={{ fontFamily: F.display, fontSize: 15, color: C.text }}>{mine ? 'Vous' : item.sellerName}</Text>
            </View>
            <Ionicons name="shield-checkmark-outline" size={20} color={C.success} />
          </Card>
          <Text style={[styles.muted, { fontSize: 12, marginHorizontal: 20, marginTop: 10 }]}>
            Conseil : rencontrez le vendeur dans un lieu public et vérifiez l’article avant de payer.
          </Text>
        </FadeIn>
      </ScrollView>

      <View style={{ position: 'absolute', left: 0, right: 0, bottom: 0, padding: 16, paddingBottom: Math.max(insets.bottom, 14), backgroundColor: 'rgba(243,246,253,0.96)' }}>
        {mine ? (
          <View style={{ flexDirection: 'row', gap: 10 }}>
            <Button label={item.status === 'sold' ? 'Remettre en vente' : 'Marquer vendu'} icon="checkmark-done" onPress={toggleSold} style={{ flex: 1 }} />
            <Button label="Supprimer" variant="danger" onPress={remove} style={{ flex: 0.6 }} />
          </View>
        ) : (
          <Button label="Contacter le vendeur" icon="chatbubble-ellipses" variant="accent" onPress={contact} loading={busy} />
        )}
      </View>
    </View>
  );
}

function Meta({ icon, text }: { icon: keyof typeof Ionicons.glyphMap; text: string }) {
  return (
    <View style={styles.row}>
      <Ionicons name={icon} size={14} color={C.muted} />
      <Text style={{ fontFamily: F.medium, fontSize: 12.5, color: C.muted, marginLeft: 3 }}>{text}</Text>
    </View>
  );
}
