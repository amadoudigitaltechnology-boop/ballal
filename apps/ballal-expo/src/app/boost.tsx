import { Ionicons } from '@expo/vector-icons';
import { LinearGradient } from 'expo-linear-gradient';
import { router, useFocusEffect, useLocalSearchParams } from 'expo-router';
import * as WebBrowser from 'expo-web-browser';
import { useCallback, useState } from 'react';
import { ActivityIndicator, Alert, Pressable, ScrollView, Text, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

import { Button, Card, FadeIn, styles } from '@/components/ui';
import { startPayment } from '@/lib/api';
import { useMoney } from '@/lib/money';
import { useSession } from '@/lib/session';
import { supabase } from '@/lib/supabase';
import { C, F } from '@/lib/theme';

const RETURN_URL = 'com.amadoutechnology.ballal://payment-return';
type Plan = { days: number; price_gnf: number };

/** Sponsoriser son profil : en tête des résultats et de l'accueil, avec la mention « Sponsorisé ». */
export default function Boost() {
  const gnf = useMoney();
  const { welcome } = useLocalSearchParams<{ welcome?: string }>();
  const isWelcome = welcome === '1';
  const leave = () => (isWelcome || !router.canGoBack() ? router.replace('/') : router.back());
  const insets = useSafeAreaInsets();
  const { session } = useSession();
  const uid = session?.user.id ?? '';
  const [plans, setPlans] = useState<Plan[] | null>(null);
  const [until, setUntil] = useState<string | null>(null);
  const [isPro, setIsPro] = useState(true);
  const [choice, setChoice] = useState(7);
  const [busy, setBusy] = useState('');

  const load = useCallback(async () => {
    const [{ data: s }, { data: p }] = await Promise.all([
      supabase.from('app_settings').select('value').eq('key', 'boost_plans').maybeSingle(),
      supabase.from('professional_profiles').select('featured_until').eq('user_id', uid).maybeSingle(),
    ]);
    setPlans(Array.isArray(s?.value) ? (s!.value as Plan[]) : []);
    setIsPro(!!p);
    setUntil(p?.featured_until && new Date(p.featured_until) > new Date() ? p.featured_until : null);
  }, [uid]);

  useFocusEffect(
    useCallback(() => {
      load().catch(() => setPlans([]));
    }, [load]),
  );

  const pay = async () => {
    try {
      setBusy('Ouverture du paiement…');
      const data = await startPayment({ purpose: 'boost', days: choice });
      setBusy('Paiement en cours…');
      await WebBrowser.openAuthSessionAsync(data.redirect_url as string, RETURN_URL);
      setBusy('Vérification du paiement…');
      for (let i = 0; i < 6; i++) {
        const { data: p } = await supabase.from('payments').select('status').eq('id', data.payment_id).maybeSingle();
        if (p?.status === 'success') {
          await load();
          Alert.alert('Profil sponsorisé', `Votre profil est en tête des résultats pendant ${choice} jours.`);
          if (isWelcome) router.replace('/');
          return;
        }
        if (p?.status === 'failed' || p?.status === 'cancelled') break;
        await new Promise((r) => setTimeout(r, 2000));
      }
      Alert.alert('Ballal', 'Paiement non confirmé pour le moment. Si vous avez payé, la sponsorisation s’activera dans quelques minutes.');
    } catch (e) {
      Alert.alert('Ballal', e instanceof Error ? e.message : 'Erreur');
    } finally {
      setBusy('');
    }
  };

  const selected = plans?.find((p) => p.days === choice);

  return (
    <View style={{ flex: 1, backgroundColor: C.bg }}>
      <LinearGradient colors={['#FF9A3D', C.accent, '#F25C05']} start={{ x: 0, y: 0 }} end={{ x: 1, y: 1 }} style={{ paddingTop: insets.top + 6, paddingBottom: 24, paddingHorizontal: 12, borderBottomLeftRadius: 28, borderBottomRightRadius: 28 }}>
        <View style={styles.row}>
          {isWelcome ? null : (
            <Pressable onPress={leave} hitSlop={10} style={{ padding: 6 }}>
              <Ionicons name="chevron-back" size={26} color="#fff" />
            </Pressable>
          )}
          <View style={{ flex: 1, marginLeft: isWelcome ? 8 : 4 }}>
            <Text style={{ color: '#fff', fontFamily: F.displayHeavy, fontSize: 22 }}>{isWelcome ? 'Votre compte est prêt' : 'Sponsoriser mon profil'}</Text>
            <Text style={{ color: 'rgba(255,255,255,0.9)', fontFamily: F.medium, fontSize: 13 }}>
              {isWelcome ? 'Boostez votre profil pour recevoir vos premiers clients' : 'Soyez vu en premier par les clients'}
            </Text>
          </View>
          <Ionicons name="rocket" size={32} color="#fff" />
        </View>
      </LinearGradient>

      {plans === null ? (
        <ActivityIndicator color={C.accent} style={{ marginTop: 40 }} />
      ) : !isPro ? (
        <View style={{ alignItems: 'center', margin: 30, gap: 16 }}>
          <Text style={[styles.muted, { textAlign: 'center' }]}>La sponsorisation est réservée aux comptes professionnels.</Text>
          <Button label="Continuer" icon="arrow-forward" onPress={leave} />
        </View>
      ) : (
        <ScrollView contentContainerStyle={{ padding: 16, gap: 14, paddingBottom: insets.bottom + 30 }}>
          {until ? (
            <Card style={{ padding: 14, backgroundColor: '#FFF4EA', flexDirection: 'row', alignItems: 'center' }}>
              <Ionicons name="flash" size={22} color={C.accent} />
              <Text style={{ flex: 1, marginLeft: 10, fontFamily: F.semibold, color: C.text }}>
                Sponsorisé jusqu’au {new Date(until).toLocaleDateString('fr-FR', { day: 'numeric', month: 'long' })}. Une nouvelle période s’ajoute à la suite.
              </Text>
            </Card>
          ) : null}

          <FadeIn>
            <Card style={{ padding: 18 }}>
              {[
                ['trending-up-outline', 'En tête des recherches et de l’accueil'],
                ['megaphone-outline', 'Mention « Sponsorisé » bien visible'],
                ['people-outline', 'Plus de clients vous contactent'],
              ].map(([icon, label]) => (
                <View key={label} style={[styles.row, { marginBottom: 10 }]}>
                  <Ionicons name={icon as keyof typeof Ionicons.glyphMap} size={20} color={C.accent} />
                  <Text style={{ marginLeft: 10, fontFamily: F.semibold, color: C.text }}>{label}</Text>
                </View>
              ))}
            </Card>
          </FadeIn>

          <Text style={{ fontFamily: F.bold, color: C.text }}>Choisissez votre durée</Text>
          {plans.map((p, i) => {
            const on = p.days === choice;
            return (
              <FadeIn key={p.days} index={i}>
                <Pressable
                  onPress={() => setChoice(p.days)}
                  style={[styles.row, { backgroundColor: '#fff', borderRadius: 20, padding: 16, borderWidth: 2, borderColor: on ? C.accent : C.border }]}>
                  <View style={{ width: 24, height: 24, borderRadius: 12, borderWidth: 2, borderColor: on ? C.accent : C.border, alignItems: 'center', justifyContent: 'center' }}>
                    {on ? <View style={{ width: 12, height: 12, borderRadius: 6, backgroundColor: C.accent }} /> : null}
                  </View>
                  <View style={{ flex: 1, marginLeft: 12 }}>
                    <Text style={{ fontFamily: F.display, fontSize: 16, color: C.text }}>{p.days} jours</Text>
                    <Text style={[styles.muted, { fontSize: 12.5 }]}>{gnf(p.price_gnf / p.days, true)} par jour</Text>
                  </View>
                  {p.days === 7 ? (
                    <View style={{ backgroundColor: C.accentSoft, borderRadius: 10, paddingHorizontal: 8, paddingVertical: 3, marginRight: 8 }}>
                      <Text style={{ color: C.accent, fontFamily: F.heavy, fontSize: 10.5 }}>POPULAIRE</Text>
                    </View>
                  ) : null}
                  <Text style={{ fontFamily: F.displayHeavy, fontSize: 16, color: C.text }}>{gnf(p.price_gnf)}</Text>
                </Pressable>
              </FadeIn>
            );
          })}

          <Button label={busy || `Payer ${selected ? gnf(selected.price_gnf) : ''}`} icon="lock-closed" variant="accent" onPress={pay} loading={!!busy} style={{ marginTop: 6 }} />
          <Text style={[styles.muted, { textAlign: 'center', fontSize: 12 }]}>Orange Money, MTN MoMo, Wave ou carte. Paiement sécurisé.</Text>
          {isWelcome ? (
            <Pressable onPress={leave} style={{ alignSelf: 'center', paddingVertical: 12, paddingHorizontal: 24 }}>
              <Text style={{ fontFamily: F.bold, color: C.muted, fontSize: 15 }}>Plus tard</Text>
            </Pressable>
          ) : null}
        </ScrollView>
      )}
    </View>
  );
}
