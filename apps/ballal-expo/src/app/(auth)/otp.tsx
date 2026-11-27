import { Ionicons } from '@expo/vector-icons';
import { router, useLocalSearchParams } from 'expo-router';
import { useEffect, useRef, useState, type ComponentRef } from 'react';
import { Alert, Pressable, Text, TextInput, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

import { Button, FadeIn, styles } from '@/components/ui';
import { friendlyError, supabase } from '@/lib/supabase';
import { C, F } from '@/lib/theme';

/** Code à 6 chiffres reçu par e-mail : confirmation d'inscription ou mot de passe oublié. */
export default function Otp() {
  const { email = '', mode = 'signup' } = useLocalSearchParams<{ email: string; mode: string }>();
  const [code, setCode] = useState('');
  const [loading, setLoading] = useState(false);
  const [cooldown, setCooldown] = useState(60);
  const input = useRef<ComponentRef<typeof TextInput>>(null);

  useEffect(() => {
    const t = setInterval(() => setCooldown((c) => (c > 0 ? c - 1 : 0)), 1000);
    return () => clearInterval(t);
  }, []);

  const verify = async (value = code) => {
    if (value.length < 6 || loading) return;
    setLoading(true);
    try {
      const { error } = await supabase.auth.verifyOtp({ email, token: value, type: mode === 'recovery' ? 'recovery' : 'signup' });
      if (error) throw error;
      if (mode === 'recovery') router.replace('/new-password');
    } catch (e) {
      setCode('');
      const m = String((e as Error).message).toLowerCase();
      Alert.alert('BALLAL', m.includes('user not found') ? 'Aucun compte n’existe avec cet e-mail.' : friendlyError(e));
    } finally {
      setLoading(false);
    }
  };

  const resend = async () => {
    if (!email) return router.replace('/login');
    try {
      if (mode === 'recovery') await supabase.auth.resetPasswordForEmail(email);
      else await supabase.auth.resend({ type: 'signup', email });
      setCooldown(60);
      Alert.alert('BALLAL', 'Nouveau code envoyé.');
    } catch (e) {
      Alert.alert('BALLAL', friendlyError(e));
    }
  };

  return (
    <SafeAreaView style={{ flex: 1, backgroundColor: '#fff', padding: 24 }}>
      <Pressable onPress={() => router.back()} hitSlop={10}>
        <Ionicons name="arrow-back" size={24} color={C.text} />
      </Pressable>
      <FadeIn style={{ marginTop: 16 }}>
        <View style={{ width: 72, height: 72, borderRadius: 36, backgroundColor: C.primarySoft, alignItems: 'center', justifyContent: 'center' }}>
          <Ionicons name="mail-open-outline" size={34} color={C.primary} />
        </View>
        <Text style={[styles.h1, { marginTop: 18, fontSize: 26 }]}>Vérification</Text>
        <Text style={[styles.muted, { fontSize: 15, marginTop: 6 }]}>Entrez le code à 6 chiffres envoyé à {email}</Text>
      </FadeIn>

      <Pressable onPress={() => input.current?.focus()} style={{ flexDirection: 'row', gap: 8, marginTop: 28 }}>
        {Array.from({ length: 6 }).map((_, i) => (
          <View
            key={i}
            style={{
              flex: 1,
              height: 58,
              borderRadius: 14,
              alignItems: 'center',
              justifyContent: 'center',
              backgroundColor: i < code.length ? C.primarySoft : C.field,
              borderWidth: 1.6,
              borderColor: i === code.length ? C.primary : 'transparent',
            }}>
            <Text style={{ fontFamily: F.heavy, fontSize: 24, color: C.primaryDark }}>{code[i] ?? ''}</Text>
          </View>
        ))}
      </Pressable>
      <TextInput
        ref={input}
        value={code}
        autoFocus
        keyboardType="number-pad"
        textContentType="oneTimeCode"
        autoComplete="one-time-code"
        maxLength={6}
        onChangeText={(v) => {
          const digits = v.replace(/\D/g, '').slice(0, 6);
          setCode(digits);
          if (digits.length === 6) verify(digits);
        }}
        style={{ position: 'absolute', opacity: 0, height: 1, width: 1 }}
      />
      <Text style={[styles.muted, { textAlign: 'center', fontSize: 12, marginTop: 10 }]}>Pensez à regarder dans les spams.</Text>
      <Button label="Vérifier" onPress={() => verify()} loading={loading} style={{ marginTop: 20 }} />
      <Pressable onPress={cooldown === 0 ? resend : undefined} style={{ padding: 14 }}>
        <Text style={{ textAlign: 'center', fontFamily: F.bold, color: cooldown === 0 ? C.primary : C.muted }}>
          {cooldown === 0 ? 'Renvoyer le code' : `Renvoyer le code dans ${cooldown} s`}
        </Text>
      </Pressable>
    </SafeAreaView>
  );
}
