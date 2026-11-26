import { router } from 'expo-router';
import { useState } from 'react';
import { Alert, Text } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

import { Button, FadeIn, Input, styles } from '@/components/ui';
import { useSession } from '@/lib/session';
import { friendlyError, needsPassword, strongPassword, supabase } from '@/lib/supabase';

export default function NewPassword() {
  const { session } = useSession();
  const creating = needsPassword(session?.user);
  const [password, setPassword] = useState('');
  const [confirm, setConfirm] = useState('');
  const [loading, setLoading] = useState(false);

  const save = async () => {
    if (password.length < 8 || !strongPassword(password))
      return Alert.alert('Mot de passe', '8 caractères minimum, avec au moins une lettre et un chiffre.');
    if (password !== confirm) return Alert.alert('Mot de passe', 'Les deux mots de passe ne sont pas identiques.');
    setLoading(true);
    try {
      const { error } = await supabase.auth.updateUser({ password, data: { password_set: true } });
      if (error) throw error;
      if (!creating) Alert.alert('Ballal', 'Mot de passe enregistré ✅');
      router.replace('/');
    } catch (e) {
      Alert.alert('BALLAL', friendlyError(e));
    } finally {
      setLoading(false);
    }
  };

  return (
    <SafeAreaView style={{ flex: 1, backgroundColor: '#fff', padding: 24 }}>
      <FadeIn style={{ gap: 12, marginTop: 24 }}>
        <Text style={[styles.h1, { fontSize: 26 }]}>{creating ? 'Créez votre mot de passe' : 'Nouveau mot de passe'}</Text>
        <Text style={styles.muted}>
          {creating
            ? 'Il vous permettra aussi de vous connecter avec votre e-mail. 8 caractères minimum, une lettre et un chiffre.'
            : '8 caractères minimum, avec au moins une lettre et un chiffre.'}
        </Text>
        <Input icon="lock-closed-outline" placeholder="Mot de passe" value={password} onChangeText={setPassword} secure />
        <Input icon="lock-open-outline" placeholder="Confirmer le mot de passe" value={confirm} onChangeText={setConfirm} secure />
        <Button label={creating ? 'Continuer' : 'Enregistrer'} onPress={save} loading={loading} />
      </FadeIn>
    </SafeAreaView>
  );
}
