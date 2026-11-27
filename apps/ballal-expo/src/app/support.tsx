import { Ionicons } from '@expo/vector-icons';
import { LinearGradient } from 'expo-linear-gradient';
import { router } from 'expo-router';
import { Linking, Pressable, ScrollView, Text, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

import { Card, FadeIn, styles } from '@/components/ui';
import { C, F, brandGradient } from '@/lib/theme';

const WHATSAPP = '224620657693';
const PHONE_LABEL = '+224 620 65 76 93';
const EMAIL = 'amadoudigitaltechnology@gmail.com';

/** Aide & Support : WhatsApp Business, téléphone et e-mail d'Amadou Technology. */
export default function Support() {
  const insets = useSafeAreaInsets();
  const items: { icon: keyof typeof Ionicons.glyphMap; color: string; title: string; value: string; action: string; url: string }[] = [
    {
      icon: 'logo-whatsapp',
      color: '#25D366',
      title: 'WhatsApp Business',
      value: PHONE_LABEL,
      action: 'Écrire sur WhatsApp',
      url: `https://wa.me/${WHATSAPP}?text=${encodeURIComponent('Bonjour, j’ai besoin d’aide sur Ballal.')}`,
    },
    { icon: 'call', color: C.primary, title: 'Téléphone', value: PHONE_LABEL, action: 'Appeler', url: `tel:+${WHATSAPP}` },
    {
      icon: 'mail',
      color: C.accent,
      title: 'E-mail',
      value: EMAIL,
      action: 'Envoyer un e-mail',
      url: `mailto:${EMAIL}?subject=${encodeURIComponent('Aide Ballal')}`,
    },
  ];
  return (
    <View style={{ flex: 1, backgroundColor: C.bg }}>
      <LinearGradient colors={brandGradient} start={{ x: 0, y: 0 }} end={{ x: 1, y: 1 }} style={{ paddingTop: insets.top + 6, paddingBottom: 26, paddingHorizontal: 12, borderBottomLeftRadius: 28, borderBottomRightRadius: 28 }}>
        <View style={styles.row}>
          <Pressable onPress={() => router.back()} hitSlop={10} style={{ padding: 6 }}>
            <Ionicons name="chevron-back" size={26} color="#fff" />
          </Pressable>
          <View style={{ flex: 1, marginLeft: 4 }}>
            <Text style={{ color: '#fff', fontFamily: F.displayHeavy, fontSize: 22 }}>Aide & Support</Text>
            <Text style={{ color: 'rgba(255,255,255,0.85)', fontFamily: F.medium, fontSize: 13 }}>Notre équipe vous répond rapidement</Text>
          </View>
        </View>
      </LinearGradient>
      <ScrollView contentContainerStyle={{ padding: 16, gap: 12, paddingBottom: insets.bottom + 30 }}>
        {items.map((it, i) => (
          <FadeIn key={it.title} index={i}>
            <Card onPress={() => Linking.openURL(it.url)} style={{ flexDirection: 'row', alignItems: 'center', padding: 16 }}>
              <View style={{ width: 52, height: 52, borderRadius: 18, backgroundColor: it.color + '1A', alignItems: 'center', justifyContent: 'center' }}>
                <Ionicons name={it.icon} size={26} color={it.color} />
              </View>
              <View style={{ flex: 1, marginLeft: 14 }}>
                <Text style={{ fontFamily: F.display, fontSize: 15.5, color: C.text }}>{it.title}</Text>
                <Text selectable style={{ fontFamily: F.semibold, fontSize: 14, color: C.text, marginTop: 2 }}>{it.value}</Text>
                <Text style={{ fontFamily: F.bold, fontSize: 12.5, color: it.color, marginTop: 4 }}>{it.action}</Text>
              </View>
              <Ionicons name="chevron-forward" size={18} color={C.muted} />
            </Card>
          </FadeIn>
        ))}
        <Text style={[styles.muted, { textAlign: 'center', fontSize: 12.5, marginTop: 8 }]}>Ballal est une application d’Amadou Technology, Conakry.</Text>
      </ScrollView>
    </View>
  );
}
