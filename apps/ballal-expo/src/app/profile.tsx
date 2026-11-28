import { Ionicons } from '@expo/vector-icons';
import { LinearGradient } from 'expo-linear-gradient';
import { router, useFocusEffect } from 'expo-router';
import { useCallback, useState } from 'react';
import { ScrollView, Text, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

import { ProPhoto } from '@/components/ProTile';
import { Card, FadeIn, Pressy, styles } from '@/components/ui';
import { useSession } from '@/lib/session';
import { supabase } from '@/lib/supabase';
import { C, F, brandGradient, shadow } from '@/lib/theme';

type IconName = keyof typeof Ionicons.glyphMap;
type ProState = { verified: boolean; pending: boolean; sponsoredUntil: string | null };

/** Profil : carte d'identité dégradée, actions rapides du pro, menus regroupés. */
export default function Profile() {
  const insets = useSafeAreaInsets();
  const { session, profile } = useSession();
  const isPro = !!profile?.roles.includes('professional');
  const uid = session?.user.id ?? '';
  const [pro, setPro] = useState<ProState | null>(null);

  useFocusEffect(
    useCallback(() => {
      if (!isPro || !uid) return;
      let alive = true;
      Promise.all([
        supabase.from('professional_profiles').select('identity_verified, company_verified, featured_until').eq('user_id', uid).maybeSingle(),
        supabase.from('verification_documents').select('id').eq('user_id', uid).eq('status', 'pending').limit(1),
      ])
        .then(([{ data: p }, { data: d }]) => {
          if (!alive) return;
          setPro({
            verified: !!(p?.identity_verified || p?.company_verified),
            pending: (d?.length ?? 0) > 0,
            sponsoredUntil: p?.featured_until && new Date(p.featured_until) > new Date() ? p.featured_until : null,
          });
        })
        .catch(() => undefined);
      return () => {
        alive = false;
      };
    }, [isPro, uid]),
  );

  const sections: { title: string; rows: { icon: IconName; color: string; label: string; sub?: string; onPress: () => void }[] }[] = [
    {
      title: 'Mon activité',
      rows: [
        isPro
          ? { icon: 'storefront-outline', color: C.accent, label: 'Mes annonces', sub: 'Marketplace', onPress: () => router.push('/market') }
          : { icon: 'storefront-outline', color: C.accent, label: 'Marketplace', sub: 'Commander auprès des pros', onPress: () => router.push('/market') },
        { icon: 'chatbubbles-outline', color: C.primary, label: 'Mes messages', onPress: () => router.push('/messages') },
      ],
    },
    {
      title: 'Compte',
      rows: [
        { icon: 'lock-closed-outline', color: '#7C3AED', label: 'Changer mon mot de passe', onPress: () => router.push('/new-password') },
        { icon: 'settings-outline', color: '#475569', label: 'Paramètres', onPress: () => router.push('/settings') },
        { icon: 'help-buoy-outline', color: '#0E9F6E', label: 'Aide & Support', sub: 'WhatsApp, téléphone, e-mail', onPress: () => router.push('/support') },
      ],
    },
  ];

  return (
    <View style={{ flex: 1, backgroundColor: C.bg }}>
      <ScrollView contentContainerStyle={{ paddingBottom: insets.bottom + 40 }} showsVerticalScrollIndicator={false}>
        {/* Carte d'identité */}
        <LinearGradient colors={brandGradient} start={{ x: 0, y: 0 }} end={{ x: 1, y: 1 }} style={{ paddingTop: insets.top + 6, paddingBottom: 54, paddingHorizontal: 20, borderBottomLeftRadius: 34, borderBottomRightRadius: 34 }}>
          <View style={{ position: 'absolute', right: -50, top: -40, width: 200, height: 200, borderRadius: 100, backgroundColor: 'rgba(255,255,255,0.10)' }} />
          <View style={{ position: 'absolute', left: -30, bottom: -50, width: 140, height: 140, borderRadius: 70, backgroundColor: 'rgba(255,122,26,0.25)' }} />
          <Pressy onPress={() => router.back()} style={{ alignSelf: 'flex-start', marginBottom: 14, marginLeft: -6, padding: 6 }}>
            <Ionicons name="chevron-back" size={26} color="#fff" />
          </Pressy>
          <FadeIn style={[styles.row]}>
            <View style={{ padding: 3, borderRadius: 50, backgroundColor: 'rgba(255,255,255,0.35)' }}>
              <ProPhoto path={null} name={profile?.fullName ?? ''} size={78} radius={39} />
            </View>
            <View style={{ flex: 1, marginLeft: 14 }}>
              <View style={styles.row}>
                <Text numberOfLines={1} style={{ color: '#fff', fontFamily: F.displayHeavy, fontSize: 21, flexShrink: 1 }}>
                  {profile?.fullName}
                </Text>
                {pro?.verified ? <Ionicons name="checkmark-circle" size={20} color="#7CF0B8" style={{ marginLeft: 6 }} /> : null}
              </View>
              <Text numberOfLines={1} style={{ color: 'rgba(255,255,255,0.85)', fontFamily: F.medium, fontSize: 13, marginTop: 2 }}>
                {session?.user.email}
              </Text>
              <View style={[styles.row, { marginTop: 8, gap: 6 }]}>
                <View style={{ backgroundColor: 'rgba(255,255,255,0.2)', paddingHorizontal: 10, paddingVertical: 3, borderRadius: 12 }}>
                  <Text style={{ color: '#fff', fontFamily: F.bold, fontSize: 12 }}>{isPro ? 'Professionnel' : 'Client'}</Text>
                </View>
                {pro?.sponsoredUntil ? (
                  <View style={{ backgroundColor: C.accent, paddingHorizontal: 10, paddingVertical: 3, borderRadius: 12 }}>
                    <Text style={{ color: '#fff', fontFamily: F.bold, fontSize: 12 }}>Sponsorisé</Text>
                  </View>
                ) : null}
              </View>
            </View>
          </FadeIn>
        </LinearGradient>

        {/* Actions rapides du professionnel */}
        {isPro ? (
          <View style={{ flexDirection: 'row', gap: 12, marginHorizontal: 16, marginTop: -34 }}>
            <QuickTile
              icon={pro?.verified ? 'shield-checkmark' : 'shield-outline'}
              colors={['#10B981', '#057A55']}
              title={pro?.verified ? 'Compte vérifié' : pro?.pending ? 'En examen' : 'Vérifier mon compte'}
              sub={pro?.verified ? 'Badge actif' : pro?.pending ? 'Réponse sous 48 h' : 'Être recommandé'}
              onPress={() => router.push('/verification')}
            />
            <QuickTile
              icon="rocket"
              colors={['#FF9A3D', '#F25C05']}
              title="Sponsoriser"
              sub={pro?.sponsoredUntil ? `Jusqu’au ${new Date(pro.sponsoredUntil).toLocaleDateString('fr-FR', { day: 'numeric', month: 'short' })}` : 'Être vu en premier'}
              onPress={() => router.push('/boost')}
            />
          </View>
        ) : null}

        {sections.map((sec, si) => (
          <View key={sec.title} style={{ marginHorizontal: 16, marginTop: si === 0 ? 22 : 16 }}>
            <Text style={{ fontFamily: F.bold, fontSize: 12.5, color: C.muted, letterSpacing: 0.6, marginLeft: 6, marginBottom: 8 }}>{sec.title.toUpperCase()}</Text>
            <Card style={{ padding: 6 }}>
              {sec.rows.map((r, i) => (
                <FadeIn key={r.label} index={i}>
                  <Pressy onPress={r.onPress} style={[styles.row, { padding: 10, borderRadius: 16 }]}>
                    <View style={{ width: 40, height: 40, borderRadius: 13, backgroundColor: r.color + '18', alignItems: 'center', justifyContent: 'center' }}>
                      <Ionicons name={r.icon} size={20} color={r.color} />
                    </View>
                    <View style={{ flex: 1, marginLeft: 12 }}>
                      <Text style={{ fontFamily: F.semibold, fontSize: 14.5, color: C.text }}>{r.label}</Text>
                      {r.sub ? <Text style={[styles.muted, { fontSize: 12 }]}>{r.sub}</Text> : null}
                    </View>
                    <Ionicons name="chevron-forward" size={18} color={C.border} />
                  </Pressy>
                  {i < sec.rows.length - 1 ? <View style={{ height: 1, backgroundColor: C.border, marginLeft: 62, opacity: 0.6 }} /> : null}
                </FadeIn>
              ))}
            </Card>
          </View>
        ))}
      </ScrollView>
    </View>
  );
}

function QuickTile({ icon, colors, title, sub, onPress }: { icon: IconName; colors: [string, string]; title: string; sub: string; onPress: () => void }) {
  return (
    <Pressy onPress={onPress} style={{ flex: 1 }}>
      <View style={{ backgroundColor: '#fff', borderRadius: 22, padding: 14, ...shadow }}>
        <LinearGradient colors={colors} style={{ width: 44, height: 44, borderRadius: 15, alignItems: 'center', justifyContent: 'center' }}>
          <Ionicons name={icon} size={22} color="#fff" />
        </LinearGradient>
        <Text numberOfLines={1} style={{ fontFamily: F.display, fontSize: 14.5, color: C.text, marginTop: 10 }}>{title}</Text>
        <Text numberOfLines={1} style={[styles.muted, { fontSize: 12, marginTop: 1 }]}>{sub}</Text>
      </View>
    </Pressy>
  );
}
