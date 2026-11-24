import { Ionicons } from '@expo/vector-icons';
import { useState } from 'react';
import { Alert, Animated, Modal, Pressable, ScrollView, Switch, Text, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

import { Button, FadeIn, Input, styles } from '@/components/ui';
import { useSession } from '@/lib/session';
import { friendlyError, supabase } from '@/lib/supabase';
import { C, F } from '@/lib/theme';

const TERMS_VERSION = '2026-11';

/** Première connexion : nom, client ou professionnel, conditions — puis « Compte créé avec succès ». */
export default function Setup() {
  const { session, profile, refresh } = useSession();
  const [name, setName] = useState(profile?.fullName ?? (session?.user.user_metadata?.full_name as string) ?? '');
  const [role, setRole] = useState<'client' | 'professional' | null>(null);
  const [accepted, setAccepted] = useState(false);
  const [loading, setLoading] = useState(false);
  const [done, setDone] = useState(false);
  const scale = useState(() => new Animated.Value(0))[0];

  const valid = name.trim().length >= 2 && role && accepted;

  const submit = async () => {
    if (!valid || !session) return;
    setLoading(true);
    try {
      const uid = session.user.id;
      const e1 = (await supabase.from('profiles').update({ full_name: name.trim() }).eq('id', uid)).error;
      if (e1) throw e1;
      await supabase.from('user_consents').insert([
        { user_id: uid, consent_type: 'terms', policy_version: TERMS_VERSION, granted: true },
        { user_id: uid, consent_type: 'privacy', policy_version: TERMS_VERSION, granted: true },
      ]);
      const e3 = (await supabase.rpc('activate_role', { p_role: role })).error;
      if (e3) throw e3;
      setDone(true);
      Animated.spring(scale, { toValue: 1, useNativeDriver: true, bounciness: 12 }).start();
      setTimeout(() => refresh(), 2600);
    } catch (e) {
      Alert.alert('BALLAL', friendlyError(e));
    } finally {
      setLoading(false);
    }
  };

  return (
    <SafeAreaView style={{ flex: 1, backgroundColor: '#fff' }}>
      <ScrollView contentContainerStyle={{ padding: 24, gap: 14 }}>
        <FadeIn>
          <Text style={[styles.h1, { fontSize: 28 }]}>Complétez votre profil</Text>
          <Text style={[styles.muted, { marginTop: 6 }]}>Encore une étape et c’est prêt.</Text>
        </FadeIn>
        <Text style={{ fontFamily: F.bold, marginTop: 8 }}>Nom complet</Text>
        <Input icon="person-outline" placeholder="Ex. : Mamadou Diallo" value={name} onChangeText={setName} autoCapitalize="words" />
        <Text style={{ fontFamily: F.bold, marginTop: 8 }}>Vous êtes…</Text>
        <RoleCard role={role} setRole={setRole} value="client" icon="search" title="Client" text="Je cherche des professionnels" />
        <RoleCard role={role} setRole={setRole} value="professional" icon="construct" title="Professionnel" text="Je propose mes services" />
        <View style={[styles.row, { marginTop: 6 }]}>
          <Switch value={accepted} onValueChange={setAccepted} trackColor={{ true: C.primary }} />
          <Text style={[styles.muted, { flex: 1, marginLeft: 10 }]}>J’accepte les conditions d’utilisation et la politique de confidentialité.</Text>
        </View>
        <Button label="Continuer" icon="arrow-forward" onPress={submit} loading={loading} style={{ marginTop: 8, opacity: valid ? 1 : 0.5 }} />
      </ScrollView>

      <Modal visible={done} transparent animationType="fade">
        <View style={{ flex: 1, backgroundColor: 'rgba(11,42,111,0.55)', alignItems: 'center', justifyContent: 'center', padding: 32 }}>
          <Animated.View style={{ backgroundColor: '#fff', borderRadius: 32, padding: 28, alignItems: 'center', width: '100%', transform: [{ scale }] }}>
            <View style={{ width: 110, height: 110, borderRadius: 55, backgroundColor: '#DCFCE7', alignItems: 'center', justifyContent: 'center' }}>
              <Ionicons name="checkmark-circle" size={96} color={C.success} />
            </View>
            <Text style={[styles.h2, { textAlign: 'center', marginTop: 16 }]}>Votre compte a été créé avec succès 🎉</Text>
            <Text style={[styles.muted, { textAlign: 'center', marginTop: 8 }]}>Bienvenue sur BALLAL, {name.split(' ')[0]} ! Tout est prêt.</Text>
          </Animated.View>
        </View>
      </Modal>
    </SafeAreaView>
  );
}

function RoleCard({
  value,
  icon,
  title,
  text,
  role,
  setRole,
}: {
  value: 'client' | 'professional';
  icon: keyof typeof Ionicons.glyphMap;
  title: string;
  text: string;
  role: 'client' | 'professional' | null;
  setRole: (r: 'client' | 'professional') => void;
}) {
    const sel = role === value;
    return (
      <Pressable onPress={() => setRole(value)}>
        <View style={{ flexDirection: 'row', alignItems: 'center', padding: 16, borderRadius: 20, borderWidth: 2, borderColor: sel ? C.primary : C.border, backgroundColor: sel ? C.primarySoft : '#fff' }}>
          <View style={{ backgroundColor: sel ? C.primary : C.field, padding: 10, borderRadius: 14 }}>
            <Ionicons name={icon} size={24} color={sel ? '#fff' : C.muted} />
          </View>
          <View style={{ flex: 1, marginLeft: 12 }}>
            <Text style={{ fontFamily: F.heavy, color: C.text }}>{title}</Text>
            <Text style={styles.muted}>{text}</Text>
          </View>
          <Ionicons name={sel ? 'checkmark-circle' : 'ellipse-outline'} size={24} color={sel ? C.primary : C.border} />
        </View>
      </Pressable>
    );
  }
