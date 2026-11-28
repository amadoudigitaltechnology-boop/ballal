import { Ionicons } from '@expo/vector-icons';
import { Image } from 'expo-image';
import * as ImagePicker from 'expo-image-picker';
import { router } from 'expo-router';
import { useState } from 'react';
import { Alert, KeyboardAvoidingView, Pressable, ScrollView, Text, TextInput, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

import { Button, Input, Pressy, styles } from '@/components/ui';
import { MARKET_CATEGORIES, createListing, gnf, uploadMarketPhoto } from '@/lib/market';
import { useSession } from '@/lib/session';
import { friendlyError } from '@/lib/supabase';
import { C, F, shadow } from '@/lib/theme';

type Picked = { uri: string; mime?: string | null; size?: number | null };
const MAX_PHOTOS = 6;
const COMMUNES = ['Kaloum', 'Dixinn', 'Matam', 'Ratoma', 'Matoto', 'Kipé', 'Lambanyi'];

/** Publier un article : photos (6 max), titre, prix, catégorie, état, quartier, description. */
export default function NewListing() {
  const insets = useSafeAreaInsets();
  const { session, profile } = useSession();
  const isPro = !!profile?.roles.includes('professional');
  const [photos, setPhotos] = useState<Picked[]>([]);
  const [title, setTitle] = useState('');
  const [price, setPrice] = useState('');
  const [category, setCategory] = useState<string | null>(null);
  const [condition, setCondition] = useState<'new' | 'used'>('used');
  const [place, setPlace] = useState('');
  const [description, setDescription] = useState('');
  const [busy, setBusy] = useState(false);
  const [step, setStep] = useState('');

  const pick = async () => {
    const perm = await ImagePicker.requestMediaLibraryPermissionsAsync();
    if (!perm.granted) return Alert.alert('Photos', 'Autorisez l’accès à vos photos pour ajouter des images.');
    const res = await ImagePicker.launchImageLibraryAsync({
      mediaTypes: ['images'],
      allowsMultipleSelection: true,
      selectionLimit: MAX_PHOTOS - photos.length,
      quality: 0.7,
    });
    if (res.canceled) return;
    const next = res.assets.map((a) => ({ uri: a.uri, mime: a.mimeType, size: a.fileSize }));
    const tooBig = next.filter((p) => p.size && p.size > 5 * 1024 * 1024).length;
    if (tooBig) Alert.alert('Photos', `${tooBig} photo(s) de plus de 5 Mo ignorée(s).`);
    setPhotos((prev) => [...prev, ...next.filter((p) => !p.size || p.size <= 5 * 1024 * 1024)].slice(0, MAX_PHOTOS));
  };

  const amount = Number(price.replace(/\D/g, '') || 0);

  const publish = async () => {
    if (!session) return;
    if (photos.length === 0) return Alert.alert('Photos', 'Ajoutez au moins une photo de l’article.');
    if (title.trim().length < 3) return Alert.alert('Titre', 'Donnez un titre à votre article (3 caractères minimum).');
    if (!amount) return Alert.alert('Prix', 'Indiquez le prix en GNF.');
    if (!category) return Alert.alert('Catégorie', 'Choisissez une catégorie.');
    setBusy(true);
    try {
      const paths: string[] = [];
      for (let i = 0; i < photos.length; i++) {
        setStep(`Envoi des photos ${i + 1}/${photos.length}…`);
        paths.push(await uploadMarketPhoto(session.user.id, photos[i].uri, photos[i].mime, photos[i].size));
      }
      setStep('Publication…');
      const id = await createListing({
        sellerId: session.user.id,
        title,
        description,
        priceGnf: amount,
        category,
        condition,
        locationName: place,
        photos: paths,
      });
      router.replace(`/market/${id}`);
    } catch (e) {
      const m = (e as Error)?.message ?? '';
      Alert.alert('BALLAL', m === 'photo_too_big' ? 'Une photo dépasse 5 Mo.' : friendlyError(e));
    } finally {
      setBusy(false);
      setStep('');
    }
  };

  if (!isPro)
    return (
      <View style={{ flex: 1, backgroundColor: C.bg, alignItems: 'center', justifyContent: 'center', padding: 30, gap: 14 }}>
        <Ionicons name="storefront-outline" size={56} color={C.accent} />
        <Text style={[styles.h2, { textAlign: 'center' }]}>Réservé aux professionnels</Text>
        <Text style={[styles.muted, { textAlign: 'center' }]}>Seuls les comptes professionnels peuvent vendre sur le Marketplace. Vous pouvez parcourir les articles et commander auprès des vendeurs.</Text>
        <Button label="Retour au Marketplace" icon="arrow-back" onPress={() => router.back()} />
      </View>
    );

  return (
    <KeyboardAvoidingView style={{ flex: 1, backgroundColor: C.bg }} behavior="padding">
      <View style={[styles.row, { paddingTop: insets.top + 6, paddingHorizontal: 12, paddingBottom: 8 }]}>
        <Pressable onPress={() => router.back()} hitSlop={10} style={{ padding: 6 }}>
          <Ionicons name="close" size={26} color={C.text} />
        </Pressable>
        <Text style={[styles.h2, { flex: 1, marginLeft: 6 }]}>Vendre un article</Text>
      </View>

      <ScrollView contentContainerStyle={{ padding: 16, paddingBottom: 140, gap: 14 }} keyboardShouldPersistTaps="handled" overScrollMode="never">
        {/* Photos */}
        <View>
          <Label text={`Photos (${photos.length}/${MAX_PHOTOS})`} />
          <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={{ gap: 10 }}>
            {photos.length < MAX_PHOTOS ? (
              <Pressy onPress={pick} style={{ width: 96, height: 96, borderRadius: 18, borderWidth: 2, borderStyle: 'dashed', borderColor: C.primary, backgroundColor: C.primarySoft, alignItems: 'center', justifyContent: 'center' }}>
                <Ionicons name="camera" size={26} color={C.primary} />
                <Text style={{ fontFamily: F.bold, fontSize: 11.5, color: C.primary, marginTop: 4 }}>Ajouter</Text>
              </Pressy>
            ) : null}
            {photos.map((p, i) => (
              <View key={p.uri}>
                <Image source={p.uri} style={{ width: 96, height: 96, borderRadius: 18 }} contentFit="cover" />
                {i === 0 ? (
                  <View style={{ position: 'absolute', left: 6, bottom: 6, backgroundColor: 'rgba(15,23,42,0.6)', borderRadius: 8, paddingHorizontal: 6, paddingVertical: 1 }}>
                    <Text style={{ color: '#fff', fontFamily: F.bold, fontSize: 10 }}>Principale</Text>
                  </View>
                ) : null}
                <Pressable onPress={() => setPhotos(photos.filter((x) => x.uri !== p.uri))} hitSlop={8} style={{ position: 'absolute', right: -6, top: -6, backgroundColor: C.danger, borderRadius: 12, padding: 3 }}>
                  <Ionicons name="close" size={14} color="#fff" />
                </Pressable>
              </View>
            ))}
          </ScrollView>
        </View>

        <View>
          <Label text="Titre" />
          <Input icon="pricetag-outline" placeholder="Ex. iPhone 13 128 Go, très propre" value={title} onChangeText={setTitle} maxLength={80} />
        </View>

        <View>
          <Label text="Prix" />
          <Input icon="cash-outline" placeholder="Prix en GNF" value={price ? amount.toLocaleString('fr-FR') : ''} onChangeText={setPrice} keyboardType="number-pad" maxLength={18} />
          {amount ? <Text style={{ fontFamily: F.bold, color: C.accent, marginTop: 6, marginLeft: 4 }}>{gnf(amount)}</Text> : null}
        </View>

        <View>
          <Label text="Catégorie" />
          <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: 8 }}>
            {MARKET_CATEGORIES.map((c) => {
              const on = category === c.key;
              return (
                <Pressable key={c.key} onPress={() => setCategory(c.key)}>
                  <View style={[styles.row, { height: 36, paddingHorizontal: 12, borderRadius: 18, backgroundColor: on ? C.primary : '#fff', borderWidth: 1, borderColor: on ? C.primary : C.border }]}>
                    <Ionicons name={c.icon as keyof typeof Ionicons.glyphMap} size={15} color={on ? '#fff' : C.primary} />
                    <Text style={{ marginLeft: 6, fontFamily: F.semibold, fontSize: 13, color: on ? '#fff' : C.text }}>{c.label}</Text>
                  </View>
                </Pressable>
              );
            })}
          </View>
        </View>

        <View>
          <Label text="État" />
          <View style={{ flexDirection: 'row', backgroundColor: C.field, borderRadius: 16, padding: 4 }}>
            {(['used', 'new'] as const).map((k) => (
              <Pressable key={k} style={{ flex: 1 }} onPress={() => setCondition(k)}>
                <View style={{ paddingVertical: 10, borderRadius: 12, backgroundColor: condition === k ? '#fff' : 'transparent' }}>
                  <Text style={{ textAlign: 'center', fontFamily: F.heavy, color: condition === k ? C.primary : C.muted }}>{k === 'new' ? 'Neuf' : 'Occasion'}</Text>
                </View>
              </Pressable>
            ))}
          </View>
        </View>

        <View>
          <Label text="Quartier" />
          <Input icon="location-outline" placeholder="Quartier ou commune" value={place} onChangeText={setPlace} maxLength={60} />
          <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={{ gap: 6, marginTop: 8 }}>
            {COMMUNES.map((c) => (
              <Pressable key={c} onPress={() => setPlace(c)}>
                <View style={{ paddingHorizontal: 10, paddingVertical: 5, borderRadius: 14, backgroundColor: place === c ? C.primarySoft : '#fff', borderWidth: 1, borderColor: C.border }}>
                  <Text style={{ fontFamily: F.medium, fontSize: 12, color: C.primary }}>{c}</Text>
                </View>
              </Pressable>
            ))}
          </ScrollView>
        </View>

        <View>
          <Label text="Description" />
          <View style={[styles.input, { height: 120, alignItems: 'flex-start', paddingVertical: 12 }]}>
            <TextInput
              value={description}
              onChangeText={setDescription}
              placeholder="État, taille, couleur, raison de la vente…"
              placeholderTextColor="#94A3B8"
              multiline
              maxLength={2000}
              style={[styles.inputText, { height: '100%', textAlignVertical: 'top' }]}
            />
          </View>
        </View>
      </ScrollView>

      <View style={{ position: 'absolute', left: 0, right: 0, bottom: 0, padding: 16, paddingBottom: Math.max(insets.bottom, 14), backgroundColor: 'rgba(243,246,253,0.97)', ...shadow }}>
        {step ? <Text style={[styles.muted, { textAlign: 'center', marginBottom: 8 }]}>{step}</Text> : null}
        <Button label="Publier l’article" icon="rocket-outline" variant="accent" onPress={publish} loading={busy} />
      </View>
    </KeyboardAvoidingView>
  );
}

function Label({ text }: { text: string }) {
  return <Text style={{ fontFamily: F.bold, fontSize: 14, color: C.text, marginBottom: 8, marginLeft: 2 }}>{text}</Text>;
}
