import { useFonts } from 'expo-font';
import { Stack, useRouter, useSegments } from 'expo-router';
import { StatusBar } from 'expo-status-bar';
import { useEffect } from 'react';
import { ActivityIndicator, View } from 'react-native';
import { SafeAreaProvider } from 'react-native-safe-area-context';

import { Logo } from '@/components/ui';
import { SessionProvider, useSession } from '@/lib/session';
import { C, fontAssets } from '@/lib/theme';

/** Garde de navigation : compte obligatoire, profil à compléter, sinon l'accueil. */
function Guard() {
  const { ready, session, needsSetup, onboardingSeen, profile } = useSession();
  const segments = useSegments() as string[];
  const router = useRouter();

  useEffect(() => {
    if (!ready) return;
    const group = segments[0];
    const inAuth = group === '(auth)';
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
    if (inAuth && segments[1] !== 'new-password') router.replace('/');
  }, [ready, session, needsSetup, onboardingSeen, profile, segments, router]);

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
    </Stack>
  );
}

export default function RootLayout() {
  const [loaded] = useFonts(fontAssets);
  if (!loaded) {
    return (
      <View style={{ flex: 1, alignItems: 'center', justifyContent: 'center', backgroundColor: '#fff' }}>
        <Logo height={48} />
        <ActivityIndicator color={C.primary} style={{ marginTop: 24 }} />
      </View>
    );
  }
  return (
    <SafeAreaProvider>
      <SessionProvider>
        <StatusBar style="dark" />
        <Guard />
      </SessionProvider>
    </SafeAreaProvider>
  );
}
