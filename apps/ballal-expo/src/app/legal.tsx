import { Ionicons } from '@expo/vector-icons';
import { router, useLocalSearchParams } from 'expo-router';
import { useState } from 'react';
import { Pressable, ScrollView, Text, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

import { FadeIn, styles } from '@/components/ui';
import { COMPANY } from '@/lib/knowledge';
import { C, F } from '@/lib/theme';

type Doc = { key: string; title: string; icon: keyof typeof Ionicons.glyphMap; sections: { h: string; p: string }[] };

const UPDATED = 'Mise à jour : novembre 2026';

const DOCS: Doc[] = [
  {
    key: 'terms',
    title: 'Conditions générales',
    icon: 'document-text-outline',
    sections: [
      { h: '1. Objet', p: `Ballal est une application de mise en relation entre des clients et des professionnels, avec un Marketplace. Elle est éditée par ${COMPANY.company} (${COMPANY.founder}), ${COMPANY.office}. En créant un compte, vous acceptez les présentes conditions.` },
      { h: '2. Compte', p: 'Vous devez fournir des informations exactes : nom, pays, ville et quartier. Votre compte est personnel ; vous êtes responsable de votre mot de passe et de toute activité sur votre compte.' },
      { h: '3. Rôle de Ballal', p: 'Ballal met les personnes en contact. Le contrat de service ou de vente est conclu directement entre le client et le professionnel, qui reste seul responsable de la qualité, du prix et de la réalisation de sa prestation ou de son article.' },
      { h: '4. Professionnels', p: 'Les professionnels s’engagent à décrire honnêtement leurs compétences, leurs tarifs et leurs articles, à respecter les clients et à honorer les demandes acceptées. Seuls les comptes professionnels peuvent publier sur le Marketplace.' },
      { h: '5. Badge vérifié', p: 'Le badge vérifié est attribué après le paiement des frais de vérification et les informations fournies sur l’activité. Il n’est pas une garantie absolue. Ballal peut le retirer, sans remboursement, en cas de fausse information, de plainte fondée ou de non-respect des règles.' },
      { h: '6. Sponsorisation', p: 'Un profil sponsorisé apparaît en priorité dans les résultats et sur l’accueil, avec la mention « Sponsorisé », pendant la durée payée. La sponsorisation ne garantit pas un nombre de clients.' },
      { h: '7. Paiements', p: 'Les paiements sont traités par nos partenaires (Djomy en Guinée, GeniusPay dans les autres pays). Les montants affichés dans l’application sont ceux facturés. Les frais de vérification et de sponsorisation ne sont pas remboursables une fois le service activé, sauf erreur de notre part.' },
      { h: '8. Contenus interdits', p: 'Sont interdits : arnaques, faux profils, contenus violents, haineux ou à caractère sexuel, articles illégaux, contrefaçons, harcèlement et spam. Ballal peut supprimer un contenu ou suspendre un compte sans préavis.' },
      { h: '9. Responsabilité', p: 'Ballal fait de son mieux pour que l’application fonctionne, sans garantir l’absence de panne. Ballal n’est pas responsable des litiges entre utilisateurs, mais peut aider à les résoudre via le support.' },
      { h: '10. Contact', p: `Pour toute question : ${COMPANY.email} ou WhatsApp ${COMPANY.phone}.` },
    ],
  },
  {
    key: 'privacy',
    title: 'Confidentialité',
    icon: 'shield-checkmark-outline',
    sections: [
      { h: 'Données collectées', p: 'Nom, e-mail, pays, ville, quartier, rôle (client ou professionnel), messages échangés, informations professionnelles et articles publiés, historique des paiements (sans vos codes secrets).' },
      { h: 'Pourquoi', p: 'Faire fonctionner la mise en relation, vous montrer les professionnels de votre zone, sécuriser les comptes, traiter les paiements, envoyer des notifications utiles et améliorer Ballal.' },
      { h: 'Partage', p: 'Votre profil public est visible des autres utilisateurs. Vos données ne sont jamais vendues. Elles sont partagées uniquement avec nos prestataires techniques (hébergement, paiement, notifications) et les autorités si la loi l’exige.' },
      { h: 'Sécurité', p: 'Connexion chiffrée, mots de passe hachés, accès aux données limité par des règles strictes et journal des activités suspectes.' },
      { h: 'Vos droits', p: `Vous pouvez demander l’accès, la correction ou la suppression de vos données en écrivant à ${COMPANY.email}.` },
      { h: 'Conservation', p: 'Les données sont conservées tant que votre compte est actif, puis supprimées ou anonymisées, sauf obligation légale (par exemple pour les paiements).' },
    ],
  },
  {
    key: 'rules',
    title: 'Règles de la communauté',
    icon: 'people-outline',
    sections: [
      { h: 'Respect', p: 'Soyez poli et honnête dans vos messages, vos annonces et vos avis.' },
      { h: 'Vérité', p: 'Pas de fausses photos, de faux avis, de prix trompeurs ni de faux profils.' },
      { h: 'Sécurité', p: 'Ne partagez jamais vos codes Orange Money, MTN ou bancaires. Ballal ne vous les demandera jamais.' },
      { h: 'Sanctions', p: 'Avertissement, retrait du badge vérifié, retrait d’annonces, suspension ou suppression du compte selon la gravité.' },
    ],
  },
];

/** Conditions générales, confidentialité et règles, lisibles dans l'application. */
export default function Legal() {
  const insets = useSafeAreaInsets();
  const { doc } = useLocalSearchParams<{ doc?: string }>();
  const [tab, setTab] = useState(DOCS.find((d) => d.key === doc)?.key ?? 'terms');
  const current = DOCS.find((d) => d.key === tab) ?? DOCS[0];

  return (
    <View style={{ flex: 1, backgroundColor: C.bg }}>
      <View style={{ paddingTop: insets.top + 6, paddingHorizontal: 12, backgroundColor: '#fff', borderBottomWidth: 1, borderBottomColor: C.border }}>
        <View style={styles.row}>
          <Pressable onPress={() => (router.canGoBack() ? router.back() : router.replace('/'))} hitSlop={10} style={{ padding: 6 }}>
            <Ionicons name="chevron-back" size={26} color={C.text} />
          </Pressable>
          <Text style={[styles.h2, { marginLeft: 4 }]}>Informations légales</Text>
        </View>
        <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={{ gap: 8, paddingVertical: 12, paddingHorizontal: 4 }}>
          {DOCS.map((d) => {
            const on = d.key === tab;
            return (
              <Pressable
                key={d.key}
                onPress={() => setTab(d.key)}
                style={[styles.row, { paddingHorizontal: 14, paddingVertical: 9, borderRadius: 999, backgroundColor: on ? C.primary : C.field }]}>
                <Ionicons name={d.icon} size={16} color={on ? '#fff' : C.muted} />
                <Text style={{ marginLeft: 6, fontFamily: F.bold, fontSize: 13, color: on ? '#fff' : C.text }}>{d.title}</Text>
              </Pressable>
            );
          })}
        </ScrollView>
      </View>
      <ScrollView key={tab} contentContainerStyle={{ padding: 20, paddingBottom: insets.bottom + 40, gap: 14 }}>
        <Text style={[styles.muted, { fontSize: 12.5 }]}>{UPDATED}</Text>
        {current.sections.map((s, i) => (
          <FadeIn key={s.h} index={i} style={[styles.card, { gap: 6 }]}>
            <Text style={{ fontFamily: F.heavy, fontSize: 15.5, color: C.text }}>{s.h}</Text>
            <Text style={{ fontFamily: F.body, fontSize: 14.5, lineHeight: 22, color: C.text }}>{s.p}</Text>
          </FadeIn>
        ))}
      </ScrollView>
    </View>
  );
}
