import AsyncStorage from '@react-native-async-storage/async-storage';
import { Image } from 'expo-image';
import { LinearGradient } from 'expo-linear-gradient';
import Constants from 'expo-constants';
import * as Linking from 'expo-linking';
import { router } from 'expo-router';
import * as WebBrowser from 'expo-web-browser';
import { useEffect, useState } from 'react';
import { Alert, KeyboardAvoidingView, Pressable, ScrollView, Text, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

import { Button, FadeIn, Input, Logo, Pressy, Rise, styles } from '@/components/ui';
import { friendlyError, strongPassword, supabase } from '@/lib/supabase';
import { C, F, people } from '@/lib/theme';

WebBrowser.maybeCompleteAuthSession();

/** Connexion / création de compte : écran fixe qui tient sur l'écran (pas de défilement façon page web). */
export default function Login() {
  const insets = useSafeAreaInsets();
  const [signup, setSignup] = useState(false);
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [loading, setLoading] = useState(false);
  const [google, setGoogle] = useState(false);

  useEffect(() => {
    AsyncStorage.getItem('last_email').then((e) => e && setEmail(e));
  }, []);

  const submit = async () => {
    const mail = email.trim().toLowerCase();
    if (!/^\S+@\S+\.\S+$/.test(mail)) return Alert.alert('E-mail invalide', 'Vérifiez votre adresse e-mail.');
    if (password.length < 8 || (signup && !strongPassword(password)))
      return Alert.alert('Mot de passe', '8 caractères minimum, avec au moins une lettre et un chiffre.');
    setLoading(true);
    try {
      await AsyncStorage.setItem('last_email', mail);
      if (signup) {
        const { data, error } = await supabase.auth.signUp({ email: mail, password, options: { data: { password_set: true } } });
        if (error) throw error;
        if (data.user && data.user.identities?.length === 0) throw new Error('already_registered');
        // Comptes confirmés automatiquement par le serveur : on entre directement, sans code e-mail.
        if (!data.session) {
          const { error: e2 } = await supabase.auth.signInWithPassword({ email: mail, password });
          if (e2) throw e2;
        }
      } else {
        const { error } = await supabase.auth.signInWithPassword({ email: mail, password });
        if (error) {
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
      // Dans l'APK : adresse de retour déjà autorisée dans Supabase (sinon Supabase renvoie vers « localhost »).
      const redirectTo =
        Constants.executionEnvironment === 'storeClient' ? Linking.createURL('login-callback') : 'com.amadoutechnology.ballal://login-callback';
      const { data, error } = await supabase.auth.signInWithOAuth({ provider: 'google', options: { redirectTo, skipBrowserRedirect: true } });
      if (error || !data.url) throw error ?? new Error('oauth');
      const res = await WebBrowser.openAuthSessionAsync(data.url, redirectTo);
      if (res.type === 'success') {
        const code = new URL(res.url).searchParams.get('code');
        if (code) {
          const { error: e2 } = await supabase.auth.exchangeCodeForSession(code);
          if (e2 && !(await supabase.auth.getSession()).data.session) throw e2;
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

        <FadeIn index={1} style={{ paddingHorizontal: 24, paddingTop: 12 }}>
          <Text style={[styles.h1, { fontSize: 28 }]}>{signup ? 'Créez votre compte' : 'Bon retour !'}</Text>
          <Text style={[styles.muted, { fontSize: 14, marginTop: 2 }]}>
            {signup ? 'Gratuit, en moins d’une minute.' : 'Connectez-vous pour continuer.'}
          </Text>

          {/* 1 toucher : Google */}
          <Pressy onPress={withGoogle} disabled={google} style={{ marginTop: 16 }}>
            <View style={[styles.row, { justifyContent: 'center', height: 54, borderRadius: 27, backgroundColor: '#fff', borderWidth: 1.5, borderColor: C.border, shadowColor: '#0B2A6F', shadowOpacity: 0.08, shadowRadius: 10, shadowOffset: { width: 0, height: 4 }, elevation: 3 }]}>
              <Image source={require('../../../assets/google-g.png')} style={{ width: 22, height: 22, marginRight: 12 }} />
              <Text style={{ fontFamily: F.bold, fontSize: 15.5, color: C.text }}>{google ? 'Ouverture…' : 'Continuer avec Google'}</Text>
            </View>
          </Pressy>

          <View style={[styles.row, { marginVertical: 14 }]}>
            <View style={{ flex: 1, height: 1, backgroundColor: C.border }} />
            <Text style={[styles.muted, { marginHorizontal: 12, fontSize: 13 }]}>ou avec votre e-mail</Text>
            <View style={{ flex: 1, height: 1, backgroundColor: C.border }} />
          </View>

          <View style={{ gap: 10 }}>
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
              placeholder={signup ? 'Créez un mot de passe (8 caractères min.)' : 'Mot de passe'}
              value={password}
              onChangeText={setPassword}
              secure
              autoComplete={signup ? 'new-password' : 'current-password'}
              textContentType={signup ? 'newPassword' : 'password'}
            />
          </View>

          {!signup ? (
            <Pressable onPress={() => router.push({ pathname: '/forgot', params: { email } })} style={{ alignSelf: 'flex-end', paddingVertical: 10 }}>
              <Text style={{ color: C.primary, fontFamily: F.bold }}>Mot de passe oublié ?</Text>
            </Pressable>
          ) : (
            <Text style={[styles.muted, { fontSize: 12, marginTop: 6, marginBottom: 10 }]}>Au moins une lettre et un chiffre.</Text>
          )}

          <Button label={signup ? 'Créer mon compte' : 'Se connecter'} icon="arrow-forward" onPress={submit} loading={loading} />

          <Pressable onPress={() => setSignup(!signup)} style={{ alignSelf: 'center', paddingVertical: 14 }}>
            <Text style={{ fontFamily: F.medium, color: C.muted, fontSize: 14 }}>
              {signup ? 'Déjà un compte ? ' : 'Pas encore de compte ? '}
              <Text style={{ color: C.primary, fontFamily: F.heavy }}>{signup ? 'Se connecter' : 'Créer un compte'}</Text>
            </Text>
          </Pressable>

          <Text style={[styles.muted, { fontSize: 11.5, textAlign: 'center' }]}>
            En continuant, vous acceptez les conditions d’utilisation et la politique de confidentialité de Ballal.
          </Text>
        </FadeIn>
      </ScrollView>
    </KeyboardAvoidingView>
  );
}
