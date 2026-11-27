import { Ionicons } from '@expo/vector-icons';
import { LinearGradient } from 'expo-linear-gradient';
import { router, useLocalSearchParams } from 'expo-router';
import { useState } from 'react';
import { Alert, KeyboardAvoidingView, Pressable, ScrollView, Text, TextInput, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

import { Button, FadeIn, Input, styles } from '@/components/ui';
import { useSession } from '@/lib/session';
import { friendlyError, supabase } from '@/lib/supabase';
import { C, F, brandGradient } from '@/lib/theme';

const WHEN: { key: string; label: string; days: number | null }[] = [
  { key: 'asap', label: 'Dès que possible', days: 0 },
  { key: 'week', label: 'Cette semaine', days: 7 },
  { key: 'month', label: 'Ce mois-ci', days: 30 },
  { key: 'flex', label: 'Pas pressé', days: null },
];

/** Demande de service envoyée à un professionnel (il l'accepte ou la refuse depuis son espace). */
export default function RequestScreen() {
  const { pro, name } = useLocalSearchParams<{ pro: string; name?: string }>();
  const insets = useSafeAreaInsets();
  const { session } = useSession();
  const [title, setTitle] = useState('');
  const [description, setDescription] = useState('');
  const [when, setWhen] = useState('asap');
  const [budget, setBudget] = useState('');
  const [address, setAddress] = useState('');
  const [loading, setLoading] = useState(false);

  const valid = title.trim().length >= 2 && description.trim().length >= 5;

  const send = async () => {
    if (!valid || !session) return;
    setLoading(true);
    try {
      const days = WHEN.find((w) => w.key === when)?.days;
      const date = days == null ? null : new Date(Date.now() + days * 86400000).toISOString().slice(0, 10);
      const amount = parseInt(budget.replace(/\D/g, ''), 10);
      const { error } = await supabase.from('service_requests').insert({
        client_id: session.user.id,
        professional_id: pro,
        title: title.trim().slice(0, 120),
        description: description.trim().slice(0, 2000),
        desired_date: date,
        budget_max: Number.isFinite(amount) ? amount : null,
        address_hint: address.trim() ? address.trim().slice(0, 200) : null,
      });
      if (error) throw error;
      Alert.alert('Demande envoyée', `${name || 'Le professionnel'} va recevoir votre demande et vous répondre.`);
      router.back();
    } catch (e) {
      Alert.alert('Ballal', friendlyError(e));
    } finally {
      setLoading(false);
    }
  };

  return (
    <KeyboardAvoidingView style={{ flex: 1, backgroundColor: C.bg }} behavior="padding">
      <LinearGradient colors={brandGradient} start={{ x: 0, y: 0 }} end={{ x: 1, y: 1 }} style={{ paddingTop: insets.top + 6, paddingBottom: 18, paddingHorizontal: 12, borderBottomLeftRadius: 28, borderBottomRightRadius: 28 }}>
        <View style={styles.row}>
          <Pressable onPress={() => router.back()} hitSlop={10} style={{ padding: 6 }}>
            <Ionicons name="chevron-back" size={26} color="#fff" />
          </Pressable>
          <View style={{ flex: 1, marginLeft: 4 }}>
            <Text style={{ color: '#fff', fontFamily: F.displayHeavy, fontSize: 22 }}>Envoyer une demande</Text>
            <Text numberOfLines={1} style={{ color: 'rgba(255,255,255,0.85)', fontFamily: F.medium, fontSize: 13 }}>
              à {name || 'ce professionnel'}
            </Text>
          </View>
        </View>
      </LinearGradient>

      <ScrollView contentContainerStyle={{ padding: 20, gap: 12, paddingBottom: insets.bottom + 30 }} keyboardShouldPersistTaps="handled">
        <FadeIn style={{ gap: 12 }}>
          <Text style={{ fontFamily: F.bold, color: C.text }}>De quoi avez-vous besoin ?</Text>
          <Input icon="create-outline" placeholder="Ex. : Carrelage d'un salon de 25 m²" value={title} onChangeText={setTitle} maxLength={120} />

          <Text style={{ fontFamily: F.bold, color: C.text, marginTop: 4 }}>Détails</Text>
          <View style={{ backgroundColor: C.field, borderRadius: 18, padding: 14, minHeight: 120 }}>
            <TextInput
              value={description}
              onChangeText={setDescription}
              placeholder="Décrivez le travail, les dimensions, le matériel…"
              placeholderTextColor="#94A3B8"
              multiline
              maxLength={2000}
              style={{ fontFamily: F.body, fontSize: 15, color: C.text, minHeight: 92, textAlignVertical: 'top' }}
            />
          </View>

          <Text style={{ fontFamily: F.bold, color: C.text, marginTop: 4 }}>Quand ?</Text>
          <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: 8 }}>
            {WHEN.map((w) => {
              const on = when === w.key;
              return (
                <Pressable
                  key={w.key}
                  onPress={() => setWhen(w.key)}
                  style={{ borderRadius: 18, paddingHorizontal: 14, paddingVertical: 9, borderWidth: 1.5, borderColor: on ? C.primary : C.border, backgroundColor: on ? C.primarySoft : '#fff' }}>
                  <Text style={{ fontFamily: on ? F.bold : F.semibold, fontSize: 13, color: on ? C.primary : C.text }}>{w.label}</Text>
                </Pressable>
              );
            })}
          </View>

          <Text style={{ fontFamily: F.bold, color: C.text, marginTop: 4 }}>Budget (facultatif)</Text>
          <Input icon="cash-outline" placeholder="Ex. : 500 000 GNF" value={budget} onChangeText={setBudget} keyboardType="number-pad" />

          <Text style={{ fontFamily: F.bold, color: C.text, marginTop: 4 }}>Repère du lieu (facultatif)</Text>
          <Input icon="location-outline" placeholder="Ex. : Lambanyi, près du rond-point" value={address} onChangeText={setAddress} maxLength={200} />
          <Text style={[styles.muted, { fontSize: 12 }]}>Le repère n’est visible que par ce professionnel.</Text>

          <Button label="Envoyer la demande" icon="send" onPress={send} loading={loading} style={{ marginTop: 10, opacity: valid ? 1 : 0.5 }} />
        </FadeIn>
      </ScrollView>
    </KeyboardAvoidingView>
  );
}
