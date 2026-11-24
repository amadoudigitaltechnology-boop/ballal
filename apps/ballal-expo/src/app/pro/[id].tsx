import { Ionicons } from '@expo/vector-icons';
import { Image } from 'expo-image';
import { LinearGradient } from 'expo-linear-gradient';
import { router, useLocalSearchParams } from 'expo-router';
import { useEffect, useState } from 'react';
import { ActivityIndicator, Alert, Pressable, ScrollView, Text, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

import { ProPhoto } from '@/components/ProTile';
import { Button, Card, Empty, FadeIn, Stars, styles } from '@/components/ui';
import { proDetail, type ProDetail } from '@/lib/api';
import { publicUrl, supabase } from '@/lib/supabase';
import { C, F, brandGradient } from '@/lib/theme';

/** Fiche d'un professionnel : couverture, photo, note, à propos, métiers, contact. */
export default function ProProfile() {
  const { id } = useLocalSearchParams<{ id: string }>();
  const insets = useSafeAreaInsets();
  const [pro, setPro] = useState<ProDetail | null | undefined>(undefined);

  useEffect(() => {
    proDetail(id).then(setPro).catch(() => setPro(null));
    supabase.rpc('record_profile_view', { p_pro: id }).then(() => undefined);
  }, [id]);

  const contact = async () => {
    const { data, error } = await supabase.rpc('start_conversation', { p_professional: id, p_request: null });
    if (error) return Alert.alert('BALLAL', 'Impossible de démarrer la discussion pour le moment.');
    Alert.alert('BALLAL', 'Discussion créée ✅ Retrouvez-la dans l’onglet Messages.', [{ text: 'OK', onPress: () => router.push('/messages') }]);
    return data;
  };

  if (pro === undefined) return <ActivityIndicator color={C.primary} style={{ flex: 1 }} />;
  if (pro === null) return <Empty icon="person-remove-outline" title="Profil introuvable" />;
  const cover = publicUrl('pro-media', pro.coverPath);

  return (
    <View style={{ flex: 1, backgroundColor: C.bg }}>
      <ScrollView contentContainerStyle={{ paddingBottom: 120 }}>
        <View style={{ height: 210 }}>
          {cover ? (
            <Image source={cover} style={{ flex: 1 }} contentFit="cover" transition={300} />
          ) : (
            <LinearGradient colors={brandGradient} style={{ flex: 1 }} />
          )}
          <Pressable onPress={() => router.back()} style={{ position: 'absolute', top: insets.top + 8, left: 14, backgroundColor: 'rgba(0,0,0,0.35)', borderRadius: 20, padding: 8 }}>
            <Ionicons name="arrow-back" size={22} color="#fff" />
          </Pressable>
        </View>
        <FadeIn>
          <Card style={{ marginHorizontal: 16, marginTop: -40, flexDirection: 'row', alignItems: 'center' }}>
            <ProPhoto path={pro.logoPath} name={pro.displayName} size={76} radius={38} />
            <View style={{ flex: 1, marginLeft: 14 }}>
              <View style={styles.row}>
                <Text style={{ fontFamily: F.display, fontSize: 18, color: C.text, flexShrink: 1 }}>{pro.displayName}</Text>
                {pro.verified ? <Ionicons name="checkmark-circle" size={18} color={C.primary} style={{ marginLeft: 4 }} /> : null}
              </View>
              <Text style={styles.muted}>{pro.headline}</Text>
              <View style={{ marginTop: 6 }}>
                <Stars rating={pro.ratingAvg} count={pro.ratingCount} />
              </View>
              {pro.locationName ? (
                <View style={[styles.row, { marginTop: 4 }]}>
                  <Ionicons name="location" size={14} color={C.primary} />
                  <Text style={{ fontFamily: F.semibold, marginLeft: 3 }}>{pro.locationName}</Text>
                </View>
              ) : null}
            </View>
          </Card>
        </FadeIn>

        <FadeIn index={1}>
          <Card style={{ marginHorizontal: 16, marginTop: 12, flexDirection: 'row' }}>
            {[
              [String(pro.ratingCount), 'Avis'],
              [pro.profileViews >= 1000 ? `${(pro.profileViews / 1000).toFixed(1)}k` : String(pro.profileViews), 'Vues'],
              [pro.experienceYears != null ? `${pro.experienceYears} ans` : '–', 'Expérience'],
            ].map(([v, l]) => (
              <View key={l} style={{ flex: 1, alignItems: 'center' }}>
                <Text style={{ fontFamily: F.display, fontSize: 18, color: C.text }}>{v}</Text>
                <Text style={[styles.muted, { fontSize: 12 }]}>{l}</Text>
              </View>
            ))}
          </Card>
        </FadeIn>

        {pro.description ? (
          <FadeIn index={2}>
            <Card style={{ marginHorizontal: 16, marginTop: 12 }}>
              <Text style={styles.h3}>À propos</Text>
              <Text style={[styles.body, { marginTop: 6, lineHeight: 22 }]}>{pro.description}</Text>
            </Card>
          </FadeIn>
        ) : null}

        {pro.categories.length || pro.skills.length ? (
          <FadeIn index={3}>
            <Card style={{ marginHorizontal: 16, marginTop: 12 }}>
              <Text style={styles.h3}>Métiers et spécialités</Text>
              <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: 8, marginTop: 10 }}>
                {[...pro.categories, ...pro.skills].map((t) => (
                  <View key={t} style={{ backgroundColor: C.primarySoft, borderRadius: 20, paddingHorizontal: 12, paddingVertical: 6 }}>
                    <Text style={{ color: C.primary, fontFamily: F.semibold }}>{t}</Text>
                  </View>
                ))}
              </View>
            </Card>
          </FadeIn>
        ) : null}
      </ScrollView>

      <View style={{ position: 'absolute', left: 0, right: 0, bottom: 0, padding: 16, paddingBottom: insets.bottom + 12, backgroundColor: '#fff' }}>
        <Button label="Contacter" icon="chatbubble-ellipses-outline" variant="accent" onPress={contact} />
      </View>
    </View>
  );
}
