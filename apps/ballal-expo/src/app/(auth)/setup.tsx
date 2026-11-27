import { Ionicons } from '@expo/vector-icons';
import { useState } from 'react';
import { Alert, Animated, Modal, Pressable, ScrollView, Text, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

import { Button, FadeIn, Input, styles } from '@/components/ui';
import { useSession } from '@/lib/session';
import { friendlyError, supabase } from '@/lib/supabase';
import { C, F } from '@/lib/theme';

const TERMS_VERSION = '2026-11';

/** « Où avez-vous entendu parler de Ballal ? » */
const SOURCES: { key: string; label: string; icon: keyof typeof Ionicons.glyphMap; color: string }[] = [
  { key: 'facebook', label: 'Facebook', icon: 'logo-facebook', color: '#1877F2' },
  { key: 'tiktok', label: 'TikTok', icon: 'logo-tiktok', color: '#111111' },
  { key: 'instagram', label: 'Instagram', icon: 'logo-instagram', color: '#E1306C' },
  { key: 'whatsapp', label: 'WhatsApp', icon: 'logo-whatsapp', color: '#25D366' },
  { key: 'youtube', label: 'YouTube', icon: 'logo-youtube', color: '#FF0000' },
  { key: 'snapchat', label: 'Snapchat', icon: 'logo-snapchat', color: '#F7C600' },
  { key: 'linkedin', label: 'LinkedIn', icon: 'logo-linkedin', color: '#0A66C2' },
  { key: 'x', label: 'X (Twitter)', icon: 'logo-twitter', color: '#111111' },
  { key: 'friend', label: 'Un proche', icon: 'people', color: C.primary },
  { key: 'other', label: 'Autre', icon: 'ellipsis-horizontal-circle', color: C.muted },
];

/** Première connexion : nom, client ou professionnel, conditions — puis « Compte créé avec succès ». */
export default function Setup() {
  const { session, profile, refresh } = useSession();
  const [name, setName] = useState(profile?.fullName ?? (session?.user.user_metadata?.full_name as string) ?? '');
  const [role, setRole] = useState<'client' | 'professional' | null>(null);
  const [accepted, setAccepted] = useState(false);
  const [source, setSource] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const [done, setDone] = useState(false);
  const [step, setStep] = useState<1 | 2>(1);
  const scale = useState(() => new Animated.Value(0))[0];

  const step1Ok = name.trim().length >= 2 && !!role;
  const valid = step1Ok && accepted && source;

  const submit = async () => {
    if (!valid || !session) return;
    setLoading(true);
    try {
      const uid = session.user.id;
      const e1 = (await supabase.from('profiles').update({ full_name: name.trim(), referral_source: source }).eq('id', uid)).error;
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
      <ScrollView contentContainerStyle={{ padding: 24, gap: 14 }} keyboardShouldPersistTaps="handled">
        {/* Barre de progression : étape 1 sur 2 */}
        <View style={[styles.row, { gap: 8 }]}>
          {step === 2 ? (
            <Pressable onPress={() => setStep(1)} hitSlop={10} style={{ marginRight: 4 }}>
              <Ionicons name="chevron-back" size={24} color={C.text} />
            </Pressable>
          ) : null}
          {[1, 2].map((n) => (
            <View key={n} style={{ flex: 1, height: 6, borderRadius: 3, backgroundColor: n <= step ? C.primary : C.border }} />
          ))}
          <Text style={{ fontFamily: F.bold, color: C.muted, fontSize: 12.5, marginLeft: 4 }}>{step}/2</Text>
        </View>

        {step === 1 ? (
          <FadeIn key="s1" style={{ gap: 14 }}>
            <View>
              <Text style={[styles.h1, { fontSize: 28 }]}>Complétez votre profil</Text>
              <Text style={[styles.muted, { marginTop: 6 }]}>Dites-nous qui vous êtes.</Text>
            </View>
            <Text style={{ fontFamily: F.bold, marginTop: 4 }}>Nom complet</Text>
            <Input icon="person-outline" placeholder="Ex. : Mamadou Diallo" value={name} onChangeText={setName} autoCapitalize="words" />
            <Text style={{ fontFamily: F.bold, marginTop: 4 }}>Vous êtes…</Text>
            <RoleCard role={role} setRole={setRole} value="client" icon="search" title="Client" text="Je cherche des professionnels" />
            <RoleCard role={role} setRole={setRole} value="professional" icon="construct" title="Professionnel" text="Je propose mes services" />
            <Button label="Continuer" icon="arrow-forward" onPress={() => step1Ok && setStep(2)} style={{ marginTop: 8, opacity: step1Ok ? 1 : 0.5 }} />
          </FadeIn>
        ) : (
          <FadeIn key="s2" style={{ gap: 14 }}>
            <View>
              <Text style={[styles.h1, { fontSize: 28 }]}>Dernière étape</Text>
              <Text style={[styles.muted, { marginTop: 6 }]}>Où avez-vous entendu parler de Ballal ?</Text>
            </View>
            <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: 10 }}>
              {SOURCES.map((o) => {
                const on = source === o.key;
                return (
                  <Pressable
                    key={o.key}
                    onPress={() => setSource(o.key)}
                    style={[styles.row, { width: '47.5%', borderRadius: 16, paddingHorizontal: 12, paddingVertical: 12, borderWidth: 1.5, borderColor: on ? o.color : C.border, backgroundColor: on ? o.color + '14' : '#fff' }]}>
                    <Ionicons name={o.icon} size={20} color={o.color} />
                    <Text style={{ marginLeft: 8, flex: 1, fontFamily: on ? F.bold : F.semibold, fontSize: 13.5, color: C.text }}>{o.label}</Text>
                    {on ? <Ionicons name="checkmark-circle" size={18} color={o.color} /> : null}
                  </Pressable>
                );
              })}
            </View>
            <Pressable onPress={() => setAccepted(!accepted)} style={[styles.row, { marginTop: 6 }]}>
              <View style={{ width: 24, height: 24, borderRadius: 7, borderWidth: 2, borderColor: accepted ? C.primary : C.border, backgroundColor: accepted ? C.primary : '#fff', alignItems: 'center', justifyContent: 'center' }}>
                {accepted ? <Ionicons name="checkmark" size={16} color="#fff" /> : null}
              </View>
              <Text style={[styles.muted, { flex: 1, marginLeft: 10 }]}>J’accepte les conditions d’utilisation et la politique de confidentialité.</Text>
            </Pressable>
            <Button label="Continuer" icon="arrow-forward" onPress={submit} loading={loading} style={{ marginTop: 8, opacity: valid ? 1 : 0.5 }} />
          </FadeIn>
        )}
      </ScrollView>

      <Modal visible={done} transparent animationType="fade">
        <View style={{ flex: 1, backgroundColor: 'rgba(11,42,111,0.55)', alignItems: 'center', justifyContent: 'center', padding: 32 }}>
          <Animated.View style={{ backgroundColor: '#fff', borderRadius: 32, padding: 28, alignItems: 'center', width: '100%', transform: [{ scale }] }}>
            <View style={{ width: 110, height: 110, borderRadius: 55, backgroundColor: '#DCFCE7', alignItems: 'center', justifyContent: 'center' }}>
              <Ionicons name="checkmark-circle" size={96} color={C.success} />
            </View>
            <Text style={[styles.h2, { textAlign: 'center', marginTop: 16 }]}>Votre compte a été créé avec succès</Text>
            <Text style={[styles.muted, { textAlign: 'center', marginTop: 8 }]}>Bienvenue sur Ballal, {name.split(' ')[0]} ! Tout est prêt.</Text>
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
