import { Ionicons } from '@expo/vector-icons';
import Constants from 'expo-constants';
import { LinearGradient } from 'expo-linear-gradient';
import { router } from 'expo-router';
import { Alert, Linking, Pressable, ScrollView, Text, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

import { Card, FadeIn, Logo, Pressy, styles } from '@/components/ui';
import { useSession } from '@/lib/session';
import { C, F, brandGradient } from '@/lib/theme';

const LEGAL = 'https://amadoudigitaltechnology-boop.github.io/ballal';
type IconName = keyof typeof Ionicons.glyphMap;

/** Paramètres : sections regroupées, icônes colorées, déconnexion confirmée en bas. */
export default function Settings() {
  const insets = useSafeAreaInsets();
  const { signOut } = useSession();
  const sections: { title: string; rows: { icon: IconName; color: string; label: string; onPress: () => void }[] }[] = [
    {
      title: 'Sécurité',
      rows: [{ icon: 'lock-closed-outline', color: '#7C3AED', label: 'Mot de passe', onPress: () => router.push('/new-password') }],
    },
    {
      title: 'Aide',
      rows: [{ icon: 'help-buoy-outline', color: '#0E9F6E', label: 'Aide & Support', onPress: () => router.push('/support') }],
    },
    {
      title: 'Informations légales',
      rows: [
        { icon: 'shield-checkmark-outline', color: C.primary, label: 'Politique de confidentialité', onPress: () => Linking.openURL(`${LEGAL}/confidentialite.html`) },
        { icon: 'document-text-outline', color: '#475569', label: 'Conditions d’utilisation', onPress: () => Linking.openURL(`${LEGAL}/conditions.html`) },
      ],
    },
  ];

  const logout = () =>
    Alert.alert('Déconnexion', 'Voulez-vous vous déconnecter ?', [
      { text: 'Annuler', style: 'cancel' },
      { text: 'Se déconnecter', style: 'destructive', onPress: signOut },
    ]);

  return (
    <View style={{ flex: 1, backgroundColor: C.bg }}>
      <LinearGradient colors={brandGradient} start={{ x: 0, y: 0 }} end={{ x: 1, y: 1 }} style={{ paddingTop: insets.top + 6, paddingBottom: 22, paddingHorizontal: 12, borderBottomLeftRadius: 28, borderBottomRightRadius: 28 }}>
        <View style={styles.row}>
          <Pressable onPress={() => router.back()} hitSlop={10} style={{ padding: 6 }}>
            <Ionicons name="chevron-back" size={26} color="#fff" />
          </Pressable>
          <Text style={{ color: '#fff', fontFamily: F.displayHeavy, fontSize: 22, marginLeft: 4 }}>Paramètres</Text>
        </View>
      </LinearGradient>

      <ScrollView contentContainerStyle={{ padding: 16, paddingBottom: insets.bottom + 30 }} showsVerticalScrollIndicator={false}>
        {sections.map((sec, si) => (
          <FadeIn key={sec.title} index={si} style={{ marginTop: si === 0 ? 4 : 16 }}>
            <Text style={{ fontFamily: F.bold, fontSize: 12.5, color: C.muted, letterSpacing: 0.6, marginLeft: 6, marginBottom: 8 }}>{sec.title.toUpperCase()}</Text>
            <Card style={{ padding: 6 }}>
              {sec.rows.map((r, i) => (
                <View key={r.label}>
                  <Pressy onPress={r.onPress} style={[styles.row, { padding: 10, borderRadius: 16 }]}>
                    <View style={{ width: 40, height: 40, borderRadius: 13, backgroundColor: r.color + '18', alignItems: 'center', justifyContent: 'center' }}>
                      <Ionicons name={r.icon} size={20} color={r.color} />
                    </View>
                    <Text style={{ flex: 1, marginLeft: 12, fontFamily: F.semibold, fontSize: 14.5, color: C.text }}>{r.label}</Text>
                    <Ionicons name="chevron-forward" size={18} color={C.border} />
                  </Pressy>
                  {i < sec.rows.length - 1 ? <View style={{ height: 1, backgroundColor: C.border, marginLeft: 62, opacity: 0.6 }} /> : null}
                </View>
              ))}
            </Card>
          </FadeIn>
        ))}

        <Pressy onPress={logout} style={[styles.row, { marginTop: 24, justifyContent: 'center', backgroundColor: '#FEF2F2', borderRadius: 20, paddingVertical: 15, borderWidth: 1, borderColor: '#FECACA' }]}>
          <Ionicons name="log-out-outline" size={20} color={C.danger} />
          <Text style={{ marginLeft: 8, fontFamily: F.bold, fontSize: 15, color: C.danger }}>Se déconnecter</Text>
        </Pressy>

        <View style={{ alignItems: 'center', marginTop: 28, opacity: 0.8 }}>
          <Logo height={22} />
          <Text style={[styles.muted, { fontSize: 12, marginTop: 6 }]}>Version {Constants.expoConfig?.version ?? '1.0.0'} · Amadou Technology</Text>
        </View>
      </ScrollView>
    </View>
  );
}
