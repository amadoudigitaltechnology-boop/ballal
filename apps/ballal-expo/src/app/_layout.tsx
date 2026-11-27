import { useFonts } from 'expo-font';
import { Stack, useRootNavigationState, useRouter, useSegments } from 'expo-router';
import * as SplashScreen from 'expo-splash-screen';
import { StatusBar } from 'expo-status-bar';
import { useEffect } from 'react';
import { Pressable, Text, View } from 'react-native';
import { SafeAreaProvider } from 'react-native-safe-area-context';

import { SessionProvider, useSession } from '@/lib/session';
import { needsPassword } from '@/lib/supabase';
import { C, fontAssets } from '@/lib/theme';

// Garde l'écran de démarrage natif affiché pendant le chargement des polices.
SplashScreen.preventAutoHideAsync();
SplashScreen.setOptions({ duration: 400, fade: true });

/** Garde de navigation : compte obligatoire, profil à compléter, sinon l'accueil. */
function Guard() {
  const { ready, session, needsSetup, onboardingSeen, profile } = useSession();
  const segments = useSegments() as string[];
  const router = useRouter();
  const nav = useRootNavigationState();
  const navReady = !!nav?.key;

  useEffect(() => {
    // On attend que la navigation soit montée avant toute redirection.
    if (!ready || !navReady) return;
    const group = segments[0];
    const inAuth = group === '(auth)';
    // Retour de Google : l'écran login-callback finalise la connexion lui-même.
    if (group === 'login-callback' || group === 'payment-return') return;
    if (!session) {
      const target = onboardingSeen ? '/login' : '/welcome';
      if (!inAuth) router.replace(target);
      return;
    }
    if (!profile) return; // profil en cours de chargement
    if (needsSetup) {
      if (segments[1] !== 'setup') router.replace('/setup');
      return;
    }
    // Compte Google sans mot de passe : création du mot de passe obligatoire.
    if (needsPassword(session.user)) {
      if (segments[1] !== 'new-password') router.replace('/new-password');
      return;
    }
    if (inAuth && segments[1] !== 'new-password') router.replace('/');
  }, [ready, navReady, session, needsSetup, onboardingSeen, profile, segments, router]);

  return (
    <Stack
      screenOptions={{
        headerShown: false,
        contentStyle: { backgroundColor: C.bg },
        animation: 'slide_from_right',
      }}>
      <Stack.Screen name="(tabs)" options={{ animation: 'fade' }} />
      <Stack.Screen name="(auth)" options={{ animation: 'fade' }} />
      <Stack.Screen name="pro/[id]" options={{ animation: 'fade_from_bottom' }} />
      <Stack.Screen name="market/[id]" options={{ animation: 'fade_from_bottom' }} />
      <Stack.Screen name="market/new" options={{ animation: 'slide_from_bottom' }} />
      <Stack.Screen name="chat/[id]" options={{ animation: 'slide_from_right', contentStyle: { backgroundColor: '#EEF3FC' } }} />
    </Stack>
  );
}

export default function RootLayout() {
  const [loaded, fontError] = useFonts(fontAssets);
  const ok = loaded || !!fontError;
  useEffect(() => {
    if (ok) SplashScreen.hide();
  }, [ok]);
  if (!ok) return null;
  return (
    <SafeAreaProvider>
      <SessionProvider>
        <StatusBar style="dark" />
        <Guard />
      </SessionProvider>
    </SafeAreaProvider>
  );
}

/** Filet de sécurité : une erreur affiche cet écran au lieu de fermer l'application. */
export function ErrorBoundary({ error, retry }: { error: Error; retry: () => Promise<void> }) {
  return (
    <View style={{ flex: 1, alignItems: 'center', justifyContent: 'center', padding: 28, backgroundColor: '#fff' }}>
      <Text style={{ fontSize: 20, fontWeight: '800', color: '#0F172A', textAlign: 'center' }}>Oups, un souci est survenu</Text>
      <Text style={{ marginTop: 10, color: '#64748B', textAlign: 'center' }}>Touchez « Réessayer ». Si le problème revient, envoyez une capture de cet écran au support.</Text>
      <Text selectable style={{ marginTop: 14, color: '#94A3B8', fontSize: 12, textAlign: 'center' }}>{String(error?.message ?? error).slice(0, 300)}</Text>
      <Pressable onPress={retry} style={{ marginTop: 22, backgroundColor: '#1A56DB', paddingHorizontal: 28, paddingVertical: 14, borderRadius: 24 }}>
        <Text style={{ color: '#fff', fontWeight: '800' }}>Réessayer</Text>
      </Pressable>
    </View>
  );
}
