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

import { Button, Card, FadeIn, styles } from '@/components/ui';
import { useSession } from '@/lib/session';
import { friendlyError, supabase } from '@/lib/supabase';
import { C, F } from '@/lib/theme';

const RETURN_URL = 'com.amadoutechnology.ballal://payment-return';

type Doc = { id: string; status: 'pending' | 'approved' | 'rejected'; payment_reference: string | null; rejection_reason: string | null; doc_type: string };

const gnf = (n: number) => `${Math.round(n).toLocaleString('fr-FR').replace(/\s/g, ' ')} GNF`;

/** Vérification du compte : pièce d'identité + paiement Djomy (Orange Money, MTN MoMo, carte). */
export default function Verification() {
  const insets = useSafeAreaInsets();
  const { session } = useSession();
  const uid = session?.user.id ?? '';
  const [doc, setDoc] = useState<Doc | null | undefined>(undefined);
  const [fee, setFee] = useState<number | null>(null);
  const [docType, setDocType] = useState<'identity' | 'company'>('identity');
  const [photo, setPhoto] = useState<{ uri: string; mime?: string | null } | null>(null);
  const [busy, setBusy] = useState('');

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
        if (!photo) return Alert.alert('Ballal', 'Ajoutez d’abord la photo de votre document.');
        setBusy('Envoi du document…');
        const body = await (await fetch(photo.uri)).arrayBuffer();
        if (body.byteLength > 5 * 1024 * 1024) throw new Error('Photo trop lourde (5 Mo maximum).');
        const type = photo.mime === 'image/png' ? 'image/png' : 'image/jpeg';
        const path = `${uid}/${Crypto.randomUUID()}.${type === 'image/png' ? 'png' : 'jpg'}`;
        const up = await supabase.storage.from('verification-docs').upload(path, body, { contentType: type });
        if (up.error) throw up.error;
        const ins = await supabase
          .from('verification_documents')
          .insert({ user_id: uid, doc_type: docType, storage_path: path })
          .select('id, status, payment_reference, rejection_reason, doc_type')
          .single();
        if (ins.error) throw ins.error;
        current = ins.data as Doc;
        setDoc(current);
      }
      setBusy('Ouverture du paiement…');
      const { data, error } = await supabase.functions.invoke('djomy-pay', { body: { verification_id: current.id } });
      if (error || !data?.redirect_url) {
        const code = (data as { error?: string } | null)?.error;
        throw new Error(code === 'payment_not_configured' ? 'Le paiement en ligne sera disponible très bientôt.' : 'Paiement indisponible pour le moment. Réessayez.');
      }
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
                <Text style={[styles.muted, { textAlign: 'center', marginTop: 6 }]}>Notre équipe vérifie votre document sous 48 heures. Vous recevrez une notification.</Text>
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
                  <Text style={{ fontFamily: F.bold, color: C.danger }}>Document refusé</Text>
                  <Text style={[styles.muted, { marginTop: 4 }]}>{doc.rejection_reason || 'Envoyez un document plus lisible.'}</Text>
                </Card>
              ) : null}

              {!doc || doc.status === 'rejected' ? (
                <FadeIn index={1} style={{ gap: 12 }}>
                  <Text style={{ fontFamily: F.bold, color: C.text }}>1. Votre document</Text>
                  <View style={{ flexDirection: 'row', gap: 10 }}>
                    {(
                      [
                        ['identity', 'Pièce d’identité'],
                        ['company', 'Registre de commerce'],
                      ] as const
                    ).map(([k, label]) => (
                      <Pressable
                        key={k}
                        onPress={() => setDocType(k)}
                        style={{ flex: 1, borderRadius: 16, padding: 12, borderWidth: 1.5, borderColor: docType === k ? C.success : C.border, backgroundColor: docType === k ? '#ECFDF5' : '#fff', alignItems: 'center' }}>
                        <Text style={{ fontFamily: F.bold, fontSize: 13, color: C.text }}>{label}</Text>
                      </Pressable>
                    ))}
                  </View>
                  {photo ? (
                    <Image source={photo.uri} style={{ width: '100%', height: 190, borderRadius: 18 }} contentFit="cover" />
                  ) : null}
                  <View style={{ flexDirection: 'row', gap: 10 }}>
                    <Button label="Prendre en photo" icon="camera-outline" variant="outline" onPress={() => pick(true)} style={{ flex: 1 }} />
                    <Button label="Galerie" icon="images-outline" variant="outline" onPress={() => pick(false)} style={{ flex: 1 }} />
                  </View>
                  <Text style={{ fontFamily: F.bold, color: C.text, marginTop: 4 }}>2. Paiement sécurisé</Text>
                </FadeIn>
              ) : (
                <Text style={{ fontFamily: F.bold, color: C.text }}>Document reçu. Il reste le paiement.</Text>
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
