import { router, useLocalSearchParams } from 'expo-router';
import { useEffect } from 'react';
import { ActivityIndicator, Alert, Text, View } from 'react-native';

import { Logo, styles } from '@/components/ui';
import { friendlyError, supabase } from '@/lib/supabase';
import { C } from '@/lib/theme';

/**
 * Retour de « Continuer avec Google » : Google renvoie ici avec ?code=…
 * On échange le code contre une session, puis on laisse le garde de navigation
 * diriger (création du mot de passe, profil, ou accueil).
 */
export default function LoginCallback() {
  const { code, error_description } = useLocalSearchParams<{ code?: string; error_description?: string }>();

  useEffect(() => {
    let alive = true;
    (async () => {
      try {
        if (error_description) throw new Error(String(error_description));
        if (code) {
          const { data } = await supabase.auth.getSession();
          if (!data.session) {
            const { error } = await supabase.auth.exchangeCodeForSession(String(code));
            if (error) throw error;
          }
        }
        if (alive) router.replace('/');
      } catch (e) {
        if (!alive) return;
        // Le code a peut-être déjà été utilisé par l'écran de connexion : si la session existe, tout va bien.
        const { data } = await supabase.auth.getSession();
        if (data.session) return router.replace('/');
        Alert.alert('Ballal', friendlyError(e));
        router.replace('/login');
      }
    })();
    return () => {
      alive = false;
    };
  }, [code, error_description]);

  return (
    <View style={{ flex: 1, alignItems: 'center', justifyContent: 'center', backgroundColor: '#fff', gap: 18 }}>
      <Logo height={34} />
      <ActivityIndicator color={C.primary} />
      <Text style={styles.muted}>Connexion en cours…</Text>
    </View>
  );
}
