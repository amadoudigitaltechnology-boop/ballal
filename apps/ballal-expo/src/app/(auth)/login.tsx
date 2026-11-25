import AsyncStorage from '@react-native-async-storage/async-storage';
import { Image } from 'expo-image';
import { LinearGradient } from 'expo-linear-gradient';
import * as Linking from 'expo-linking';
import { router } from 'expo-router';
import * as WebBrowser from 'expo-web-browser';
import { useEffect, useState } from 'react';
import { Alert, KeyboardAvoidingView, Pressable, ScrollView, Text, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

import { Button, FadeIn, Input, Logo, Pressy, Rise, styles } from '@/components/ui';
import { friendlyError, supabase } from '@/lib/supabase';
import { C, F, people } from '@/lib/theme';

WebBrowser.maybeCompleteAuthSession();

/** Connexion / création de compte : écran fixe qui tient sur l'écran (pas de défilement façon page web). */
export default function Login() {
  const insets = useSafeAreaInsets();
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
    <KeyboardAvoidingView style={{ flex: 1, backgroundColor: '#fff' }} behavior="padding">
      <ScrollView
        keyboardShouldPersistTaps="handled"
        bounces={false}
        overScrollMode="never"
        showsVerticalScrollIndicator={false}
        contentContainerStyle={{ flexGrow: 1, paddingBottom: insets.bottom + 12 }}>
        {/* Haut d'écran : la dame détourée (sans fond, non rognée) entourée du disque bleu, logo à droite */}
        <View style={{ flex: 1, minHeight: 150, maxHeight: 340 }}>
          <LinearGradient colors={['#E8F0FF', '#D6E4FF']} style={{ position: 'absolute', inset: 0, borderBottomLeftRadius: 48, borderBottomRightRadius: 120 }} />
          <View style={{ position: 'absolute', right: -60, top: -40, width: 220, height: 220, borderRadius: 110, backgroundColor: C.primary }} />
          <View style={{ position: 'absolute', right: 46, bottom: 40, width: 54, height: 54, borderRadius: 27, backgroundColor: C.accent, opacity: 0.9 }} />
          <View style={{ position: 'absolute', left: 10, bottom: 0, top: insets.top + 30, width: '62%', alignItems: 'center', justifyContent: 'flex-end' }}>
            <View style={{ position: 'absolute', bottom: 0, width: '92%', aspectRatio: 1, maxHeight: '88%', borderRadius: 999, backgroundColor: 'rgba(26,86,219,0.14)', borderWidth: 3, borderColor: '#fff' }} />
            <Rise style={{ width: '100%', height: '100%' }}>
              <Image source={people.woman_phone} style={{ flex: 1 }} contentFit="contain" contentPosition="bottom" />
            </Rise>
          </View>
          <View style={{ position: 'absolute', right: 16, top: insets.top + 54, backgroundColor: '#fff', borderRadius: 14, paddingHorizontal: 10, paddingVertical: 6 }}>
            <Logo height={22} />
          </View>
        </View>

        <FadeIn index={1} style={{ paddingHorizontal: 24, paddingTop: 10 }}>
          <Text style={[styles.h1, { fontSize: 28 }]}>Bienvenue !</Text>
          <Text style={[styles.muted, { fontSize: 14, marginTop: 2 }]}>
            {signup ? 'Créez votre compte en 1 minute.' : 'Connectez-vous pour continuer.'}
          </Text>

          {/* Bascule Se connecter / Créer un compte */}
          <View style={{ flexDirection: 'row', backgroundColor: C.field, borderRadius: 16, padding: 4, marginTop: 14 }}>
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

          <View style={{ gap: 10, marginTop: 14 }}>
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
              placeholder={signup ? 'Mot de passe (8 caractères min.)' : 'Mot de passe'}
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
            <Pressable onPress={() => router.push({ pathname: '/forgot', params: { email } })} style={{ alignSelf: 'flex-end', paddingVertical: 10 }}>
              <Text style={{ color: C.primary, fontFamily: F.bold }}>Mot de passe oublié ?</Text>
            </Pressable>
          ) : (
            <View style={{ height: 14 }} />
          )}

          <Button label={signup ? 'Créer un compte' : 'Se connecter'} icon="arrow-forward" onPress={submit} loading={loading} />

          <View style={[styles.row, { marginVertical: 12 }]}>
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
