import { Ionicons } from '@expo/vector-icons';
import * as Crypto from 'expo-crypto';
import { Image } from 'expo-image';
import * as ImagePicker from 'expo-image-picker';
import { LinearGradient } from 'expo-linear-gradient';
import { router, useFocusEffect } from 'expo-router';
import * as WebBrowser from 'expo-web-browser';
import { useCallback, useState } from 'react';
import { ActivityIndicator, Alert, Pressable, ScrollView, Text, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

import { Button, Card, FadeIn, Input, styles } from '@/components/ui';
import { startPayment } from '@/lib/api';
import { useSession } from '@/lib/session';
import { friendlyError, supabase } from '@/lib/supabase';
import { C, F } from '@/lib/theme';

const RETURN_URL = 'com.amadoutechnology.ballal://payment-return';

type Doc = { id: string; status: 'pending' | 'approved' | 'rejected'; payment_reference: string | null; rejection_reason: string | null; doc_type: string };

const gnf = (n: number) => `${Math.round(n).toLocaleString('fr-FR').replace(/\s/g, ' ')} GNF`;

/** Vérification du compte : informations sur l'entreprise (RCCM et pièce d'identité facultatifs) + paiement Djomy. */
export default function Verification() {
  const insets = useSafeAreaInsets();
  const { session } = useSession();
  const uid = session?.user.id ?? '';
  const [doc, setDoc] = useState<Doc | null | undefined>(undefined);
  const [fee, setFee] = useState<number | null>(null);
  const docType = 'identity' as const;
  const [photo, setPhoto] = useState<{ uri: string; mime?: string | null } | null>(null);
  const [busy, setBusy] = useState('');
  const [company, setCompany] = useState('');
  const [trade, setTrade] = useState('');
  const [quartier, setQuartier] = useState('');
  const [years, setYears] = useState('');
  const [rccm, setRccm] = useState('');

  const load = useCallback(async () => {
    const [{ data: d }, { data: s }] = await Promise.all([
      supabase.from('verification_documents').select('id, status, payment_reference, rejection_reason, doc_type').eq('user_id', uid).order('created_at', { ascending: false }).limit(1).maybeSingle(),
      supabase.from('app_settings').select('value').eq('key', 'verification_fee_gnf').maybeSingle(),
    ]);
    setDoc((d as Doc) ?? null);
    setFee(Number(s?.value) || null);
  }, [uid]);

  useFocusEffect(
    useCallback(() => {
      load().catch(() => setDoc(null));
    }, [load]),
  );

  const pick = async (camera: boolean) => {
    const perm = camera ? await ImagePicker.requestCameraPermissionsAsync() : await ImagePicker.requestMediaLibraryPermissionsAsync();
    if (!perm.granted) return Alert.alert('Ballal', 'Autorisez l’accès pour ajouter la photo de votre document.');
    const res = camera
      ? await ImagePicker.launchCameraAsync({ quality: 0.7 })
      : await ImagePicker.launchImageLibraryAsync({ mediaTypes: ['images'], quality: 0.7 });
    if (!res.canceled) setPhoto({ uri: res.assets[0].uri, mime: res.assets[0].mimeType });
  };

  /** Envoie le document, puis ouvre le paiement Djomy. */
  const submitAndPay = async () => {
    try {
      let current = doc;
      if (!current || current.status === 'rejected') {
        if (company.trim().length < 2 || trade.trim().length < 2)
          return Alert.alert('Ballal', 'Indiquez le nom de votre entreprise et votre métier principal.');
        const rc = rccm.trim();
        if (rc && !/^[A-Za-z0-9 ./-]{4,40}$/.test(rc)) return Alert.alert('Ballal', 'Le numéro RCCM ne semble pas valide.');
        setBusy('Envoi de votre demande…');
        // Photo de la pièce d'identité : facultative.
        let path: string | null = null;
        if (photo) {
          const body = await (await fetch(photo.uri)).arrayBuffer();
          if (body.byteLength > 5 * 1024 * 1024) throw new Error('Photo trop lourde (5 Mo maximum).');
          const type = photo.mime === 'image/png' ? 'image/png' : 'image/jpeg';
          path = `${uid}/${Crypto.randomUUID()}.${type === 'image/png' ? 'png' : 'jpg'}`;
          const up = await supabase.storage.from('verification-docs').upload(path, body, { contentType: type });
          if (up.error) throw up.error;
        }
        const yrs = parseInt(years, 10);
        const ins = await supabase
          .from('verification_documents')
          .insert({
            user_id: uid,
            doc_type: rc ? 'company' : docType,
            storage_path: path,
            company_name: company.trim().slice(0, 120),
            main_trade: trade.trim().slice(0, 80),
            quartier: quartier.trim() ? quartier.trim().slice(0, 80) : null,
            experience_years: Number.isFinite(yrs) ? Math.min(Math.max(yrs, 0), 70) : null,
            rccm: rc || null,
          })
          .select('id, status, payment_reference, rejection_reason, doc_type')
          .single();
        if (ins.error) throw ins.error;
        current = ins.data as Doc;
        setDoc(current);
      }
      setBusy('Ouverture du paiement…');
      const data = await startPayment({ verification_id: current.id });
      setBusy('Paiement en cours…');
      await WebBrowser.openAuthSessionAsync(data.redirect_url as string, RETURN_URL);
      setBusy('Vérification du paiement…');
      // La confirmation vient de Djomy (serveur) : on attend qu'elle soit enregistrée.
      for (let i = 0; i < 6; i++) {
        const { data: p } = await supabase.from('payments').select('status').eq('id', data.payment_id).maybeSingle();
        if (p?.status === 'success') {
          await load();
          return Alert.alert('Paiement reçu', 'Merci ! Votre demande de vérification est en cours d’examen (48 h maximum).');
        }
        if (p?.status === 'failed' || p?.status === 'cancelled') break;
        await new Promise((r) => setTimeout(r, 2000));
      }
      await load();
      Alert.alert('Ballal', 'Paiement non confirmé pour le moment. Si vous avez payé, la confirmation arrivera dans quelques minutes.');
    } catch (e) {
      Alert.alert('Ballal', e instanceof Error && !('code' in e) ? e.message : friendlyError(e));
    } finally {
      setBusy('');
    }
  };

  const paid = !!doc?.payment_reference;

  return (
    <View style={{ flex: 1, backgroundColor: C.bg }}>
      <LinearGradient colors={['#0E9F6E', '#057A55']} start={{ x: 0, y: 0 }} end={{ x: 1, y: 1 }} style={{ paddingTop: insets.top + 6, paddingBottom: 22, paddingHorizontal: 12, borderBottomLeftRadius: 28, borderBottomRightRadius: 28 }}>
        <View style={styles.row}>
          <Pressable onPress={() => router.back()} hitSlop={10} style={{ padding: 6 }}>
            <Ionicons name="chevron-back" size={26} color="#fff" />
          </Pressable>
          <View style={{ flex: 1, marginLeft: 4 }}>
            <Text style={{ color: '#fff', fontFamily: F.displayHeavy, fontSize: 22 }}>Compte vérifié</Text>
            <Text style={{ color: 'rgba(255,255,255,0.88)', fontFamily: F.medium, fontSize: 13 }}>Le badge qui inspire confiance aux clients</Text>
          </View>
          <Ionicons name="shield-checkmark" size={34} color="#fff" />
        </View>
      </LinearGradient>

      {doc === undefined ? (
        <ActivityIndicator color={C.primary} style={{ marginTop: 40 }} />
      ) : (
        <ScrollView contentContainerStyle={{ padding: 16, gap: 14, paddingBottom: insets.bottom + 30 }}>
          {doc?.status === 'approved' ? (
            <FadeIn>
              <Card style={{ alignItems: 'center', padding: 24 }}>
                <Ionicons name="checkmark-circle" size={70} color={C.success} />
                <Text style={[styles.h2, { marginTop: 10 }]}>Votre compte est vérifié</Text>
                <Text style={[styles.muted, { textAlign: 'center', marginTop: 6 }]}>Le badge vérifié apparaît sur votre profil et vos annonces.</Text>
              </Card>
            </FadeIn>
          ) : doc?.status === 'pending' && paid ? (
            <FadeIn>
              <Card style={{ alignItems: 'center', padding: 24 }}>
                <Ionicons name="time" size={64} color={C.accent} />
                <Text style={[styles.h2, { marginTop: 10, textAlign: 'center' }]}>Paiement reçu, examen en cours</Text>
                <Text style={[styles.muted, { textAlign: 'center', marginTop: 6 }]}>Notre équipe examine votre demande sous 48 heures. Vous recevrez une notification.</Text>
              </Card>
            </FadeIn>
          ) : (
            <>
              <FadeIn>
                <Card style={{ padding: 18 }}>
                  {[
                    ['shield-checkmark-outline', 'Badge « Vérifié » sur votre profil'],
                    ['trending-up-outline', 'Mieux classé dans les recherches'],
                    ['people-outline', 'Plus de confiance, plus de clients'],
                  ].map(([icon, label]) => (
                    <View key={label} style={[styles.row, { marginBottom: 10 }]}>
                      <Ionicons name={icon as keyof typeof Ionicons.glyphMap} size={20} color={C.success} />
                      <Text style={{ marginLeft: 10, fontFamily: F.semibold, color: C.text }}>{label}</Text>
                    </View>
                  ))}
                  <View style={[styles.row, { marginTop: 6, justifyContent: 'space-between' }]}>
                    <Text style={styles.muted}>Frais uniques</Text>
                    <Text style={{ fontFamily: F.displayHeavy, fontSize: 20, color: C.accent }}>{fee ? gnf(fee) : '…'}</Text>
                  </View>
                </Card>
              </FadeIn>

              {doc?.status === 'rejected' ? (
                <Card style={{ padding: 14, backgroundColor: '#FEF2F2' }}>
                  <Text style={{ fontFamily: F.bold, color: C.danger }}>Demande refusée</Text>
                  <Text style={[styles.muted, { marginTop: 4 }]}>{doc.rejection_reason || 'Corrigez vos informations et renvoyez votre demande.'}</Text>
                </Card>
              ) : null}

              {!doc || doc.status === 'rejected' ? (
                <FadeIn index={1} style={{ gap: 12 }}>
                  <Text style={{ fontFamily: F.bold, color: C.text }}>1. Votre entreprise</Text>
                  <Input icon="business-outline" placeholder="Nom de l’entreprise ou nom commercial" value={company} onChangeText={setCompany} maxLength={120} />
                  <Input icon="construct-outline" placeholder="Métier principal (ex. : électricien)" value={trade} onChangeText={setTrade} maxLength={80} />
                  <Input icon="location-outline" placeholder="Quartier / commune" value={quartier} onChangeText={setQuartier} maxLength={80} />
                  <Input icon="time-outline" placeholder="Années d’expérience" value={years} onChangeText={(v) => setYears(v.replace(/\D/g, '').slice(0, 2))} keyboardType="number-pad" />
                  <Input icon="document-text-outline" placeholder="Numéro RCCM (facultatif)" value={rccm} onChangeText={setRccm} maxLength={40} autoCapitalize="characters" />

                  <Text style={{ fontFamily: F.bold, color: C.text, marginTop: 4 }}>Photo de la pièce d’identité (facultatif)</Text>
                  <Text style={[styles.muted, { fontSize: 12.5, marginTop: -6 }]}>Recommandé : la vérification est plus rapide avec une pièce d’identité.</Text>
                  {photo ? (
                    <View>
                      <Image source={photo.uri} style={{ width: '100%', height: 170, borderRadius: 18 }} contentFit="cover" />
                      <Pressable onPress={() => setPhoto(null)} style={{ position: 'absolute', right: 10, top: 10, backgroundColor: 'rgba(0,0,0,0.55)', borderRadius: 14, padding: 6 }}>
                        <Ionicons name="close" size={16} color="#fff" />
                      </Pressable>
                    </View>
                  ) : null}
                  <View style={{ flexDirection: 'row', gap: 10 }}>
                    <Button label="Prendre en photo" icon="camera-outline" variant="outline" onPress={() => pick(true)} style={{ flex: 1 }} />
                    <Button label="Galerie" icon="images-outline" variant="outline" onPress={() => pick(false)} style={{ flex: 1 }} />
                  </View>
                  <Text style={{ fontFamily: F.bold, color: C.text, marginTop: 4 }}>2. Paiement sécurisé</Text>
                </FadeIn>
              ) : (
                <Text style={{ fontFamily: F.bold, color: C.text }}>Demande reçue. Il reste le paiement.</Text>
              )}

              <View style={[styles.row, { gap: 8, justifyContent: 'center' }]}>
                {['Orange Money', 'MTN MoMo', 'Carte'].map((m) => (
                  <View key={m} style={{ backgroundColor: '#fff', borderRadius: 12, paddingHorizontal: 10, paddingVertical: 6, borderWidth: 1, borderColor: C.border }}>
                    <Text style={{ fontFamily: F.semibold, fontSize: 12, color: C.text }}>{m}</Text>
                  </View>
                ))}
              </View>
              <Button label={busy || `Payer ${fee ? gnf(fee) : ''}`} icon="lock-closed" onPress={submitAndPay} loading={!!busy} />
              <Text style={[styles.muted, { textAlign: 'center', fontSize: 12 }]}>Paiement traité par Djomy. Ballal ne voit jamais vos codes.</Text>
            </>
          )}
        </ScrollView>
      )}
    </View>
  );
}
