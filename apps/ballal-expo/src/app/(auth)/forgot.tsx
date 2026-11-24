import { Ionicons } from '@expo/vector-icons';
import { router, useLocalSearchParams } from 'expo-router';
import { useState } from 'react';
import { Alert, Pressable, Text, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

import { Button, FadeIn, Input, styles } from '@/components/ui';
import { friendlyError, supabase } from '@/lib/supabase';
import { C } from '@/lib/theme';

export default function Forgot() {
  const params = useLocalSearchParams<{ email?: string }>();
  const [email, setEmail] = useState(params.email ?? '');
  const [loading, setLoading] = useState(false);

  const send = async () => {
    const mail = email.trim().toLowerCase();
    if (!/^\S+@\S+\.\S+$/.test(mail)) return Alert.alert('E-mail invalide', 'Vérifiez votre adresse e-mail.');
    setLoading(true);
    try {
      const { error } = await supabase.auth.resetPasswordForEmail(mail);
      if (error) throw error;
      router.push({ pathname: '/otp', params: { email: mail, mode: 'recovery' } });
    } catch (e) {
      Alert.alert('BALLAL', friendlyError(e));
    } finally {
      setLoading(false);
    }
  };

  return (
    <SafeAreaView style={{ flex: 1, backgroundColor: '#fff', padding: 24 }}>
      <Pressable onPress={() => router.back()} hitSlop={10}>
        <Ionicons name="arrow-back" size={24} color={C.text} />
      </Pressable>
      <FadeIn style={{ marginTop: 16, gap: 8 }}>
        <View style={{ width: 72, height: 72, borderRadius: 36, backgroundColor: C.accentSoft, alignItems: 'center', justifyContent: 'center' }}>
          <Ionicons name="key" size={32} color={C.accent} />
        </View>
        <Text style={[styles.h1, { marginTop: 10, fontSize: 26 }]}>Mot de passe oublié</Text>
        <Text style={[styles.muted, { fontSize: 15 }]}>
          Entrez l’e-mail de votre compte : nous vous envoyons un code à 6 chiffres pour choisir un nouveau mot de passe.
        </Text>
        <Input icon="at" placeholder="Adresse e-mail" value={email} onChangeText={setEmail} keyboardType="email-address" autoCapitalize="none" style={{ marginTop: 16 }} />
        <Button label="Envoyer le code" onPress={send} loading={loading} style={{ marginTop: 12 }} />
      </FadeIn>
    </SafeAreaView>
  );
}
