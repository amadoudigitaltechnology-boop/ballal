import AsyncStorage from '@react-native-async-storage/async-storage';
import { Image } from 'expo-image';
import { LinearGradient } from 'expo-linear-gradient';
import * as Linking from 'expo-linking';
import { router } from 'expo-router';
import * as WebBrowser from 'expo-web-browser';
import { useEffect, useState } from 'react';
import { Alert, Dimensions, KeyboardAvoidingView, Platform, Pressable, ScrollView, Text, View } from 'react-native';

import { Button, FadeIn, Input, Logo, Pressy, styles } from '@/components/ui';
import { friendlyError, supabase } from '@/lib/supabase';
import { C, F, people } from '@/lib/theme';

WebBrowser.maybeCompleteAuthSession();

const H = Dimensions.get('window').height;

/** Connexion / création de compte (même écran que la version Flutter v16). */
export default function Login() {
  const [signup, setSignup] = useState(false);
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [confirm, setConfirm] = useState('');
  const [loading, setLoading] = useState(false);
  const [google, setGoogle] = useState(false);

  useEffect(() => {
    AsyncStorage.getItem('last_email').then((e) => e && setEmail(e));
  }, []);

  const submit = async () => {
    const mail = email.trim().toLowerCase();
    if (!/^\S+@\S+\.\S+$/.test(mail)) return Alert.alert('E-mail invalide', 'Vérifiez votre adresse e-mail.');
    if (password.length < 8) return Alert.alert('Mot de passe', 'Le mot de passe doit contenir au moins 8 caractères.');
    if (signup && password !== confirm) return Alert.alert('Mot de passe', 'Les deux mots de passe ne sont pas identiques.');
    setLoading(true);
    try {
      await AsyncStorage.setItem('last_email', mail);
      if (signup) {
        const { data, error } = await supabase.auth.signUp({ email: mail, password });
        if (error) throw error;
        if (data.user && data.user.identities?.length === 0) throw new Error('already_registered');
        if (!data.session) router.push({ pathname: '/otp', params: { email: mail, mode: 'signup' } });
      } else {
        const { error } = await supabase.auth.signInWithPassword({ email: mail, password });
        if (error) {
          if (error.message.toLowerCase().includes('not confirmed')) {
            await supabase.auth.resend({ type: 'signup', email: mail });
            router.push({ pathname: '/otp', params: { email: mail, mode: 'signup' } });
            return;
          }
          throw error;
        }
      }
    } catch (e) {
      Alert.alert('BALLAL', friendlyError(e));
    } finally {
      setLoading(false);
    }
  };

  /** « Continuer avec Google » : navigateur intégré puis retour automatique dans l'application. */
  const withGoogle = async () => {
    setGoogle(true);
    try {
      const redirectTo = Linking.createURL('login-callback');
      const { data, error } = await supabase.auth.signInWithOAuth({ provider: 'google', options: { redirectTo, skipBrowserRedirect: true } });
      if (error || !data.url) throw error ?? new Error('oauth');
      const res = await WebBrowser.openAuthSessionAsync(data.url, redirectTo);
      if (res.type === 'success') {
        const code = new URL(res.url).searchParams.get('code');
        if (code) {
          const { error: e2 } = await supabase.auth.exchangeCodeForSession(code);
          if (e2) throw e2;
        }
      }
    } catch (e) {
      Alert.alert('BALLAL', friendlyError(e));
    } finally {
      setGoogle(false);
    }
  };

  return (
    <KeyboardAvoidingView style={{ flex: 1, backgroundColor: '#fff' }} behavior={Platform.OS === 'ios' ? 'padding' : undefined}>
      <ScrollView keyboardShouldPersistTaps="handled" contentContainerStyle={{ paddingBottom: 32 }}>
        {/* Photo d'accueil sur la vague bleue, logo à droite */}
        <View style={{ height: Math.min(Math.max(H * 0.42, 280), 380) }}>
          <LinearGradient colors={['#E8F0FF', '#D6E4FF']} style={{ position: 'absolute', inset: 0, borderBottomLeftRadius: 48, borderBottomRightRadius: 120 }} />
          <View style={{ position: 'absolute', right: -60, top: -40, width: 220, height: 220, borderRadius: 110, backgroundColor: C.primary }} />
          <View style={{ position: 'absolute', right: 40, top: 120, width: 70, height: 70, borderRadius: 35, backgroundColor: C.accent, opacity: 0.9 }} />
          <FadeIn style={{ position: 'absolute', left: 24, top: 56, bottom: 34, aspectRatio: 0.92 }}>
            <View style={{ flex: 1, borderRadius: 28, borderWidth: 4, borderColor: '#fff', overflow: 'hidden', backgroundColor: '#fff' }}>
              <Image source={people.woman_phone} style={{ flex: 1 }} contentFit="cover" contentPosition="top" />
            </View>
          </FadeIn>
          <View style={{ position: 'absolute', right: 16, top: 70, backgroundColor: '#fff', borderRadius: 14, paddingHorizontal: 10, paddingVertical: 6 }}>
            <Logo height={22} />
          </View>
        </View>

        <FadeIn index={1} style={{ paddingHorizontal: 24, paddingTop: 12 }}>
          <Text style={[styles.h1, { fontSize: 30 }]}>Bienvenue !</Text>
          <Text style={[styles.muted, { fontSize: 15, marginTop: 4 }]}>
            {signup ? 'Créez votre compte en 1 minute.' : 'Connectez-vous ou créez votre compte pour continuer.'}
          </Text>

          {/* Bascule Se connecter / Créer un compte */}
          <View style={{ flexDirection: 'row', backgroundColor: C.field, borderRadius: 16, padding: 4, marginTop: 18 }}>
            {[false, true].map((s) => (
              <Pressable key={String(s)} style={{ flex: 1 }} onPress={() => setSignup(s)}>
                <View style={{ paddingVertical: 11, borderRadius: 12, backgroundColor: signup === s ? '#fff' : 'transparent' }}>
                  <Text style={{ textAlign: 'center', fontFamily: F.heavy, color: signup === s ? C.primary : C.muted }}>
                    {s ? 'Créer un compte' : 'Se connecter'}
                  </Text>
                </View>
              </Pressable>
            ))}
          </View>

          <View style={{ gap: 12, marginTop: 18 }}>
            <Input
              icon="at"
              placeholder="Adresse e-mail"
              value={email}
              onChangeText={setEmail}
              keyboardType="email-address"
              autoCapitalize="none"
              autoComplete="email"
              textContentType="username"
            />
            <Input
              icon="lock-closed-outline"
              placeholder={signup ? 'Mot de passe (8 caractères minimum)' : 'Mot de passe'}
              value={password}
              onChangeText={setPassword}
              secure
              autoComplete={signup ? 'new-password' : 'current-password'}
              textContentType={signup ? 'newPassword' : 'password'}
            />
            {signup ? (
              <Input icon="lock-open-outline" placeholder="Confirmer le mot de passe" value={confirm} onChangeText={setConfirm} secure />
            ) : null}
          </View>

          {!signup ? (
            <Pressable onPress={() => router.push({ pathname: '/forgot', params: { email } })} style={{ alignSelf: 'flex-end', paddingVertical: 12 }}>
              <Text style={{ color: C.primary, fontFamily: F.bold }}>Mot de passe oublié ?</Text>
            </Pressable>
          ) : (
            <View style={{ height: 16 }} />
          )}

          <Button label={signup ? 'Créer un compte' : 'Se connecter'} icon="arrow-forward" onPress={submit} loading={loading} />

          <View style={[styles.row, { marginVertical: 18 }]}>
            <View style={{ flex: 1, height: 1, backgroundColor: C.border }} />
            <Text style={[styles.muted, { marginHorizontal: 12 }]}>ou</Text>
            <View style={{ flex: 1, height: 1, backgroundColor: C.border }} />
          </View>

          <Pressy onPress={withGoogle} disabled={google} style={[styles.btn, styles.outline]}>
            <View style={styles.row}>
              <Text style={{ fontFamily: F.heavy, fontSize: 18, color: '#4285F4', marginRight: 10 }}>G</Text>
              <Text style={{ fontFamily: F.bold, fontSize: 15, color: C.text }}>{google ? 'Ouverture…' : 'Continuer avec Google'}</Text>
            </View>
          </Pressy>

          <Text style={[styles.muted, { fontSize: 12, textAlign: 'center', marginTop: 18 }]}>
            En continuant, vous acceptez les conditions d’utilisation et la politique de confidentialité de BALLAL.
          </Text>
        </FadeIn>
      </ScrollView>
    </KeyboardAvoidingView>
  );
}
