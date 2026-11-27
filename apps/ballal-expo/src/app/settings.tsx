import { Ionicons } from '@expo/vector-icons';
import { router } from 'expo-router';
import { Alert, Linking, Pressable, ScrollView, Text, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

import { Button, Card, styles } from '@/components/ui';
import { useSession } from '@/lib/session';
import { C, F } from '@/lib/theme';

const LEGAL = 'https://amadoudigitaltechnology-boop.github.io/ballal';

export default function Settings() {
  const { signOut } = useSession();
  const rows: { icon: keyof typeof Ionicons.glyphMap; label: string; onPress: () => void }[] = [
    { icon: 'lock-closed-outline', label: 'Mot de passe', onPress: () => router.push('/new-password') },
    { icon: 'shield-checkmark-outline', label: 'Politique de confidentialité', onPress: () => Linking.openURL(`${LEGAL}/confidentialite.html`) },
    { icon: 'document-text-outline', label: 'Conditions d’utilisation', onPress: () => Linking.openURL(`${LEGAL}/conditions.html`) },
    { icon: 'help-buoy-outline', label: 'Aide & Support', onPress: () => router.push('/support') },
  ];
  return (
    <SafeAreaView style={{ flex: 1, backgroundColor: C.bg }}>
      <View style={[styles.row, { padding: 16 }]}>
        <Pressable onPress={() => router.back()} hitSlop={10}>
          <Ionicons name="arrow-back" size={24} color={C.text} />
        </Pressable>
        <Text style={[styles.h3, { marginLeft: 12 }]}>Paramètres</Text>
      </View>
      <ScrollView contentContainerStyle={{ padding: 16 }}>
        <Card style={{ padding: 4 }}>
          {rows.map((r) => (
            <Card key={r.label} onPress={r.onPress} style={{ shadowOpacity: 0, elevation: 0, flexDirection: 'row', alignItems: 'center', padding: 14 }}>
              <Ionicons name={r.icon} size={22} color={C.text} />
              <Text style={{ flex: 1, marginLeft: 12, fontFamily: F.semibold, color: C.text }}>{r.label}</Text>
              <Ionicons name="chevron-forward" size={18} color={C.muted} />
            </Card>
          ))}
        </Card>
        <Button label="Se déconnecter" icon="log-out-outline" variant="danger" onPress={() =>
            Alert.alert('Déconnexion', 'Voulez-vous vous déconnecter ?', [
              { text: 'Annuler', style: 'cancel' },
              { text: 'Se déconnecter', style: 'destructive', onPress: signOut },
            ])
          }
          style={{ marginTop: 24 }}
        />
      </ScrollView>
    </SafeAreaView>
  );
}
