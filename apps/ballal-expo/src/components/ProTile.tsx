import { Ionicons } from '@expo/vector-icons';
import { Image } from 'expo-image';
import { LinearGradient } from 'expo-linear-gradient';
import { router } from 'expo-router';
import { Text, View } from 'react-native';

import type { ProCard } from '@/lib/api';
import { publicUrl } from '@/lib/supabase';
import { C, F, brandGradient } from '@/lib/theme';

import { Card, FadeIn, Stars, styles } from './ui';

export function ProPhoto({ path, name, size, radius = 14 }: { path: string | null; name: string; size: number; radius?: number }) {
  const url = publicUrl('pro-media', path);
  const initials = name.trim().split(/\s+/).slice(0, 2).map((w) => w[0]?.toUpperCase() ?? '').join('') || '?';
  if (url) return <Image source={url} style={{ width: size, height: size, borderRadius: radius }} contentFit="cover" transition={250} />;
  return (
    <LinearGradient colors={[C.primary, C.primaryDark]} style={{ width: size, height: size, borderRadius: radius, alignItems: 'center', justifyContent: 'center' }}>
      <Text style={{ color: '#fff', fontFamily: F.heavy, fontSize: size / 3.2 }}>{initials}</Text>
    </LinearGradient>
  );
}

const availability: Record<string, [string, string]> = {
  available: ['Disponible', C.success],
  busy: ['Occupé', '#F59E0B'],
  by_appointment: ['Sur rendez-vous', C.primary],
  unavailable: ['Indisponible', C.muted],
};

export function ProTile({ pro, index = 0, compact = false }: { pro: ProCard; index?: number; compact?: boolean }) {
  const [label, color] = availability[pro.availability] ?? availability.available;
  if (compact) {
    return (
      <FadeIn index={index % 10}>
        <Card onPress={() => router.push(`/pro/${pro.id}`)} style={{ marginHorizontal: 16, marginVertical: 4, padding: 8, flexDirection: 'row', alignItems: 'center' }}>
          <ProPhoto path={pro.logoPath} name={pro.displayName} size={54} />
          <View style={{ flex: 1, marginLeft: 10 }}>
            <View style={styles.row}>
              <Text numberOfLines={1} style={{ fontFamily: F.display, fontSize: 14.5, color: C.text, flexShrink: 1 }}>
                {pro.displayName}
              </Text>
              {pro.verified ? <Ionicons name="checkmark-circle" size={15} color={C.primary} style={{ marginLeft: 4 }} /> : null}
            </View>
            <Text numberOfLines={1} style={[styles.muted, { fontSize: 12.5, marginTop: 1 }]}>
              {pro.headline || 'Professionnel BALLAL'}
            </Text>
            <View style={[styles.row, { marginTop: 3, gap: 8 }]}>
              <Ionicons name="star" size={12} color={C.star} />
              <Text style={{ fontSize: 12, fontFamily: F.bold, color: C.text, marginLeft: -5 }}>
                {pro.ratingCount > 0 ? pro.ratingAvg.toFixed(1) : 'Nouveau'}
              </Text>
              <View style={{ width: 6, height: 6, borderRadius: 3, backgroundColor: color }} />
              <Text style={{ fontSize: 11.5, color, fontFamily: F.semibold, marginLeft: -4 }}>{label}</Text>
              {pro.locationName ? (
                <Text numberOfLines={1} style={{ fontSize: 11.5, color: C.muted, fontFamily: F.body, flexShrink: 1 }}>· {pro.locationName}</Text>
              ) : null}
            </View>
          </View>
          <Ionicons name="chevron-forward" size={18} color={C.border} />
        </Card>
      </FadeIn>
    );
  }
  return (
    <FadeIn index={index % 10}>
      <Card onPress={() => router.push(`/pro/${pro.id}`)} style={{ marginHorizontal: 16, marginVertical: 6, padding: 10, flexDirection: 'row' }}>
        <ProPhoto path={pro.logoPath} name={pro.displayName} size={88} />
        <View style={{ flex: 1, marginLeft: 12 }}>
          <View style={styles.row}>
            <Text numberOfLines={1} style={{ fontFamily: F.display, fontSize: 15, color: C.text, flexShrink: 1 }}>
              {pro.displayName}
            </Text>
            {pro.verified ? <Ionicons name="checkmark-circle" size={16} color={C.primary} style={{ marginLeft: 4 }} /> : null}
          </View>
          {pro.isFeatured ? (
            <Text style={{ color: C.accent, fontFamily: F.heavy, fontSize: 10.5, marginTop: 2 }}>MIS EN AVANT</Text>
          ) : null}
          <Text numberOfLines={1} style={[styles.muted, { fontSize: 13, marginTop: 2 }]}>
            {pro.headline}
          </Text>
          <View style={{ marginTop: 6 }}>
            <Stars rating={pro.ratingAvg} count={pro.ratingCount} />
          </View>
          <View style={[styles.row, { marginTop: 6, gap: 10, flexWrap: 'wrap' }]}>
            <View style={styles.row}>
              <View style={{ width: 7, height: 7, borderRadius: 4, backgroundColor: color, marginRight: 4 }} />
              <Text style={{ fontSize: 12, color, fontFamily: F.semibold }}>{label}</Text>
            </View>
            {pro.locationName ? (
              <View style={styles.row}>
                <Ionicons name="location-outline" size={13} color={C.muted} />
                <Text style={{ fontSize: 12, color: C.muted, fontFamily: F.body }}>{pro.locationName}</Text>
              </View>
            ) : null}
          </View>
        </View>
        <View style={{ justifyContent: 'flex-end' }}>
          <LinearGradient colors={brandGradient} style={{ borderRadius: 20, paddingHorizontal: 10, paddingVertical: 6 }}>
            <Text style={{ color: '#fff', fontSize: 11, fontFamily: F.heavy }}>Voir</Text>
          </LinearGradient>
        </View>
      </Card>
    </FadeIn>
  );
}

/** Grande carte verticale du carrousel d'accueil (photo en haut, infos en bas). */
export function ProCardBig({ pro, width, height }: { pro: ProCard; width: number; height: number }) {
  const [label, color] = availability[pro.availability] ?? availability.available;
  const url = publicUrl('pro-media', pro.logoPath);
  const initials = pro.displayName.trim().split(/\s+/).slice(0, 2).map((w) => w[0]?.toUpperCase() ?? '').join('') || '?';
  return (
    <Card onPress={() => router.push(`/pro/${pro.id}`)} style={{ width, height, padding: 0, overflow: 'hidden' }}>
      <View style={{ flex: 1, minHeight: 60 }}>
        {url ? (
          <Image source={url} style={{ flex: 1 }} contentFit="cover" contentPosition="top" transition={250} />
        ) : (
          <LinearGradient colors={brandGradient} style={{ flex: 1, alignItems: 'center', justifyContent: 'center' }}>
            <Text style={{ color: '#fff', fontFamily: F.displayHeavy, fontSize: 38 }}>{initials}</Text>
          </LinearGradient>
        )}
        <View style={[styles.row, { position: 'absolute', left: 10, top: 10, backgroundColor: 'rgba(255,255,255,0.95)', borderRadius: 20, paddingHorizontal: 9, paddingVertical: 4 }]}>
          <View style={{ width: 7, height: 7, borderRadius: 4, backgroundColor: color, marginRight: 5 }} />
          <Text style={{ fontSize: 11, color: C.text, fontFamily: F.bold }}>{label}</Text>
        </View>
        {pro.isFeatured ? (
          <LinearGradient colors={['#FF9A3D', C.accent]} style={{ position: 'absolute', right: 10, top: 10, borderRadius: 20, paddingHorizontal: 9, paddingVertical: 4 }}>
            <Text style={{ fontSize: 10.5, color: '#fff', fontFamily: F.heavy }}>★ À LA UNE</Text>
          </LinearGradient>
        ) : null}
      </View>
      <View style={{ padding: 12 }}>
        <View style={styles.row}>
          <Text numberOfLines={1} style={{ fontFamily: F.display, fontSize: 15, color: C.text, flexShrink: 1 }}>
            {pro.displayName}
          </Text>
          {pro.verified ? <Ionicons name="checkmark-circle" size={16} color={C.primary} style={{ marginLeft: 4 }} /> : null}
        </View>
        <Text numberOfLines={1} style={[styles.muted, { fontSize: 12.5, marginTop: 1 }]}>
          {pro.headline || 'Professionnel BALLAL'}
        </Text>
        <View style={[styles.row, { marginTop: 8, justifyContent: 'space-between' }]}>
          <View style={styles.row}>
            <Ionicons name="star" size={13} color={C.star} />
            <Text style={{ fontFamily: F.bold, fontSize: 12.5, marginLeft: 3, color: C.text }}>{pro.ratingCount > 0 ? pro.ratingAvg.toFixed(1) : 'Nouveau'}</Text>
          </View>
          {pro.locationName ? (
            <View style={[styles.row, { flexShrink: 1, marginLeft: 8 }]}>
              <Ionicons name="location" size={12} color={C.primary} />
              <Text numberOfLines={1} style={{ fontSize: 12, color: C.muted, fontFamily: F.medium, marginLeft: 2, flexShrink: 1 }}>
                {pro.locationName}
              </Text>
            </View>
          ) : null}
        </View>
      </View>
    </Card>
  );
}

/** Carte fine du carrousel d'accueil : photo à gauche, infos à droite (hauteur 96). */
export function ProCardSlim({ pro, width }: { pro: ProCard; width: number }) {
  const [label, color] = availability[pro.availability] ?? availability.available;
  return (
    <Card onPress={() => router.push(`/pro/${pro.id}`)} style={{ width, height: 96, padding: 8, flexDirection: 'row', alignItems: 'center' }}>
      <View>
        <ProPhoto path={pro.logoPath} name={pro.displayName} size={80} radius={16} />
        {pro.isFeatured ? (
          <LinearGradient colors={['#FF9A3D', C.accent]} style={{ position: 'absolute', left: 4, top: 4, borderRadius: 8, paddingHorizontal: 5, paddingVertical: 1 }}>
            <Text style={{ fontSize: 9, color: '#fff', fontFamily: F.heavy }}>★ UNE</Text>
          </LinearGradient>
        ) : null}
      </View>
      <View style={{ flex: 1, marginLeft: 10 }}>
        <View style={styles.row}>
          <Text numberOfLines={1} style={{ fontFamily: F.display, fontSize: 14, color: C.text, flexShrink: 1 }}>
            {pro.displayName}
          </Text>
          {pro.verified ? <Ionicons name="checkmark-circle" size={14} color={C.primary} style={{ marginLeft: 3 }} /> : null}
        </View>
        <Text numberOfLines={1} style={[styles.muted, { fontSize: 12, marginTop: 1 }]}>
          {pro.headline || 'Professionnel BALLAL'}
        </Text>
        <View style={[styles.row, { marginTop: 6, gap: 8 }]}>
          <View style={styles.row}>
            <Ionicons name="star" size={12} color={C.star} />
            <Text style={{ fontFamily: F.bold, fontSize: 12, marginLeft: 2, color: C.text }}>{pro.ratingCount > 0 ? pro.ratingAvg.toFixed(1) : 'Nouveau'}</Text>
          </View>
          <View style={styles.row}>
            <View style={{ width: 6, height: 6, borderRadius: 3, backgroundColor: color, marginRight: 3 }} />
            <Text numberOfLines={1} style={{ fontSize: 11.5, color, fontFamily: F.semibold }}>{label}</Text>
          </View>
        </View>
        {pro.locationName ? (
          <View style={[styles.row, { marginTop: 2 }]}>
            <Ionicons name="location" size={11} color={C.primary} />
            <Text numberOfLines={1} style={{ fontSize: 11.5, color: C.muted, fontFamily: F.medium, marginLeft: 2 }}>{pro.locationName}</Text>
          </View>
        ) : null}
      </View>
    </Card>
  );
}
