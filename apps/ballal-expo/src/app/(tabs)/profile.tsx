import { Ionicons } from '@expo/vector-icons';
import { router } from 'expo-router';
import { Alert, Linking, ScrollView, Text, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

import { ProPhoto } from '@/components/ProTile';
import { Button, Card, FadeIn, styles } from '@/components/ui';
import { useSession } from '@/lib/session';
import { C, F } from '@/lib/theme';

export default function Profile() {
  const { session, profile, signOut } = useSession();
  const isPro = profile?.roles.includes('professional');

  const rows: { icon: keyof typeof Ionicons.glyphMap; label: string; onPress: () => void }[] = [
    { icon: 'storefront-outline', label: 'Mes annonces (Marketplace)', onPress: () => router.push('/market') },
    { icon: 'lock-closed-outline', label: 'Changer mon mot de passe', onPress: () => router.push('/new-password') },
    { icon: 'settings-outline', label: 'Paramètres', onPress: () => router.push('/settings') },
    {
      icon: 'logo-whatsapp',
      label: 'Aide & Support',
      onPress: () => Linking.openURL('https://wa.me/224620657693?text=' + encodeURIComponent('Bonjour, j’ai besoin d’aide sur BALLAL.')),
    },
  ];

  return (
    <SafeAreaView style={{ flex: 1, backgroundColor: C.bg }} edges={['top']}>
      <ScrollView contentContainerStyle={{ padding: 16, paddingBottom: 120 }}>
        <FadeIn style={{ alignItems: 'center', marginTop: 8 }}>
          <ProPhoto path={null} name={profile?.fullName ?? ''} size={92} radius={46} />
          <Text style={[styles.h2, { marginTop: 10 }]}>{profile?.fullName}</Text>
          <Text style={styles.muted}>{session?.user.email}</Text>
          <View style={{ marginTop: 8, backgroundColor: isPro ? C.accentSoft : C.primarySoft, paddingHorizontal: 12, paddingVertical: 4, borderRadius: 20 }}>
            <Text style={{ fontFamily: F.bold, color: isPro ? C.accent : C.primary }}>{isPro ? 'Professionnel' : 'Client'}</Text>
          </View>
        </FadeIn>

        <Card style={{ marginTop: 20, padding: 4 }}>
          {rows.map((r, i) => (
            <FadeIn key={r.label} index={i}>
              <Card onPress={r.onPress} style={{ shadowOpacity: 0, elevation: 0, flexDirection: 'row', alignItems: 'center', padding: 12 }}>
                <View style={{ width: 38, height: 38, borderRadius: 12, backgroundColor: C.primarySoft, alignItems: 'center', justifyContent: 'center' }}>
                  <Ionicons name={r.icon} size={20} color={C.primary} />
                </View>
                <Text style={{ flex: 1, marginLeft: 12, fontFamily: F.semibold, color: C.text }}>{r.label}</Text>
                <Ionicons name="chevron-forward" size={18} color={C.muted} />
              </Card>
            </FadeIn>
          ))}
        </Card>

        {isPro ? (
          <Text style={[styles.muted, { textAlign: 'center', marginTop: 16, fontSize: 12 }]}>
            La gestion du profil pro (services, photos, zones) est disponible dans l’application Android en attendant la version complète.
          </Text>
        ) : null}

        <Button
          label="Se déconnecter"
          icon="log-out-outline"
          variant="danger"
          style={{ marginTop: 24 }}
          onPress={() =>
            Alert.alert('Déconnexion', 'Voulez-vous vous déconnecter ?', [
              { text: 'Annuler', style: 'cancel' },
              { text: 'Se déconnecter', style: 'destructive', onPress: signOut },
            ])
          }
        />
      </ScrollView>
    </SafeAreaView>
  );
}
