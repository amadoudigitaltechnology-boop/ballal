import { Ionicons } from '@expo/vector-icons';
import { Image } from 'expo-image';
import { LinearGradient } from 'expo-linear-gradient';
import { router } from 'expo-router';
import { Text, View } from 'react-native';

import { timeAgo } from '@/lib/api';
import { gnf, gnfShort, marketPhoto, type Listing } from '@/lib/market';
import { C, F } from '@/lib/theme';

import { Card, styles } from './ui';

/** Carte d'article : photo carrée, prix en orange, titre, quartier et date. */
export function ListingCard({ item, width, photoHeight }: { item: Listing; width: number; photoHeight?: number }) {
  const url = marketPhoto(item.photos[0]);
  return (
    <Card onPress={() => router.push(`/market/${item.id}`)} style={{ width, padding: 0, overflow: 'hidden' }}>
      <View style={{ height: photoHeight ?? width, backgroundColor: C.field }}>
        {url ? (
          <Image source={url} style={{ flex: 1 }} contentFit="cover" transition={250} />
        ) : (
          <LinearGradient colors={['#E8F0FF', '#FFE7D3']} style={{ flex: 1, alignItems: 'center', justifyContent: 'center' }}>
            <Ionicons name="image-outline" size={30} color={C.muted} />
          </LinearGradient>
        )}
        {item.status === 'sold' ? (
          <View style={{ position: 'absolute', inset: 0, backgroundColor: 'rgba(15,23,42,0.45)', alignItems: 'center', justifyContent: 'center' }}>
            <Text style={{ color: '#fff', fontFamily: F.heavy, fontSize: 15, letterSpacing: 1 }}>VENDU</Text>
          </View>
        ) : item.condition === 'new' ? (
          <View style={{ position: 'absolute', left: 8, top: 8, backgroundColor: C.success, borderRadius: 10, paddingHorizontal: 7, paddingVertical: 2 }}>
            <Text style={{ color: '#fff', fontFamily: F.heavy, fontSize: 10 }}>NEUF</Text>
          </View>
        ) : null}
      </View>
      <View style={{ padding: 9 }}>
        <Text numberOfLines={1} style={{ fontFamily: F.display, fontSize: 14, color: C.accent }}>
          {width < 150 ? gnfShort(item.priceGnf) : gnf(item.priceGnf)}
        </Text>
        <Text numberOfLines={1} style={{ fontFamily: F.semibold, fontSize: 12.5, color: C.text, marginTop: 1 }}>
          {item.title}
        </Text>
        <View style={[styles.row, { marginTop: 3 }]}>
          <Ionicons name="location-outline" size={11} color={C.muted} />
          <Text numberOfLines={1} style={{ fontFamily: F.body, fontSize: 11, color: C.muted, marginLeft: 2, flexShrink: 1 }}>
            {item.locationName || 'Conakry'} · {timeAgo(item.createdAt)}
          </Text>
        </View>
      </View>
    </Card>
  );
}
