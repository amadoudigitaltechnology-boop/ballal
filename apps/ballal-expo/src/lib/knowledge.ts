/** Base de connaissances de l'assistant Ballal et de la FAQ (Aide & Support). */

export type Faq = { id: string; q: string; a: string; tags: string[]; link?: { label: string; href: string } };

export const COMPANY = {
  founder: 'Alpha Amadou BAH',
  company: 'Amadou Technology',
  site: 'https://amadoutechnology.com',
  email: 'amadoudigitaltechnology@gmail.com',
  whatsapp: '224620657693',
  phone: '+224 620 65 76 93',
  office: 'T5, Conakry (Guinée)',
  slogan: 'La technologie doit être au service de chaque Guinéen, de chaque Africain.',
};

export const FAQ: Faq[] = [
  {
    id: 'what',
    q: 'C’est quoi Ballal ?',
    a: 'Ballal met en relation les clients avec des professionnels de confiance près de chez eux : plombiers, électriciens, menuisiers, coiffeurs, mécaniciens, et bien d’autres. Vous cherchez, vous comparez, vous écrivez au pro directement dans l’application. Ballal a aussi un Marketplace où les professionnels vendent leurs articles.',
    tags: ['ballal', 'application', 'appli', 'quoi', 'sert', 'fonctionne', 'marche', 'service'],
  },
  {
    id: 'find',
    q: 'Comment trouver un professionnel ?',
    a: 'Tapez un métier ou un service dans la recherche (ex. : « plombier »), ou choisissez une catégorie sur l’accueil. Les profils vérifiés et sponsorisés apparaissent en premier. Ouvrez un profil, puis touchez « Envoyer une demande » ou « Message ».',
    tags: ['trouver', 'chercher', 'recherche', 'pro', 'professionnel', 'artisan', 'besoin', 'contacter'],
    link: { label: 'Ouvrir la recherche', href: '/search' },
  },
  {
    id: 'verify',
    q: 'Comment obtenir le badge vérifié ?',
    a: 'Dans Paramètres > Mon profil, touchez « Vérifier mon compte ». Répondez à quelques questions sur votre activité (le RCCM et la pièce d’identité sont facultatifs), puis payez les frais de vérification. Dès que le paiement est confirmé, le badge vérifié s’affiche sur votre profil et Ballal vous recommande en priorité aux clients. Le badge peut être retiré en cas de non-respect des règles.',
    tags: ['badge', 'vérifié', 'verifie', 'vérification', 'verification', 'certifié', 'confiance', 'recommandé'],
    link: { label: 'Vérifier mon compte', href: '/verification' },
  },
  {
    id: 'boost',
    q: 'Comment sponsoriser mon profil ?',
    a: 'Dans Paramètres > Mon profil, touchez « Sponsoriser ». Choisissez une durée et payez. Votre profil passe en tête des résultats et sur l’accueil avec la mention « Sponsorisé », pendant toute la durée choisie.',
    tags: ['sponsoriser', 'sponsor', 'booster', 'boost', 'publicité', 'pub', 'visible', 'visibilité', 'clients', 'tête'],
    link: { label: 'Sponsoriser mon profil', href: '/boost' },
  },
  {
    id: 'pay',
    q: 'Quels moyens de paiement ?',
    a: 'En Guinée : Orange Money, MTN MoMo ou carte, via Djomy. Au Sénégal, en Côte d’Ivoire, au Bénin, au Cameroun, en RD Congo, au Congo, au Gabon et en Sierra Leone : Wave, Orange Money, MTN ou carte, via GeniusPay, en FCFA. Ballal ne voit jamais vos codes secrets.',
    tags: ['payer', 'paiement', 'orange', 'money', 'mtn', 'momo', 'wave', 'carte', 'prix', 'tarif', 'combien', 'coût', 'frais'],
  },
  {
    id: 'market',
    q: 'Comment marche le Marketplace ?',
    a: 'Touchez le chariot en haut de l’accueil. Tout le monde peut parcourir les articles et contacter le vendeur pour commander. Seuls les comptes professionnels peuvent publier des articles à vendre.',
    tags: ['marketplace', 'market', 'vendre', 'acheter', 'article', 'produit', 'commande', 'commander', 'boutique', 'chariot', 'publier'],
    link: { label: 'Ouvrir le Marketplace', href: '/market' },
  },
  {
    id: 'become-pro',
    q: 'Je suis client, comment devenir professionnel ?',
    a: 'Contactez le support depuis Aide & Support : nous activons votre compte professionnel. Vous pourrez alors compléter votre profil, être trouvé par les clients et vendre sur le Marketplace.',
    tags: ['devenir', 'professionnel', 'compte pro', 'changer', 'rôle', 'role', 'client'],
    link: { label: 'Contacter le support', href: '/support' },
  },
  {
    id: 'password',
    q: 'J’ai oublié mon mot de passe',
    a: 'Sur l’écran de connexion, touchez « Mot de passe oublié ? » et suivez le lien reçu par e-mail. Si vous êtes connecté, allez dans Paramètres > Mot de passe.',
    tags: ['mot de passe', 'oublié', 'password', 'connexion', 'connecter', 'compte', 'bloqué'],
  },
  {
    id: 'google',
    q: 'Je n’arrive pas à me connecter',
    a: 'Si vous avez créé votre compte avec Google, utilisez « Continuer avec Google ». Sinon, vérifiez votre adresse e-mail et touchez « Mot de passe oublié ? ». Toujours bloqué ? Écrivez-nous sur WhatsApp.',
    tags: ['connecter', 'connexion', 'google', 'erreur', 'bloqué', 'marche pas', 'problème'],
    link: { label: 'Écrire au support', href: '/support' },
  },
  {
    id: 'safety',
    q: 'Comment éviter les arnaques ?',
    a: 'Préférez les profils vérifiés, discutez dans la messagerie Ballal, ne payez jamais un acompte important avant d’avoir vu le travail ou l’article, et signalez tout comportement suspect au support. Ballal ne vous demandera jamais votre code Orange Money ou MTN.',
    tags: ['arnaque', 'sécurité', 'securite', 'confiance', 'signaler', 'fraude', 'escroc'],
  },
  {
    id: 'delete',
    q: 'Comment supprimer mon compte ?',
    a: 'Écrivez au support depuis Aide & Support avec l’adresse e-mail de votre compte. Vos données sont supprimées selon notre politique de confidentialité.',
    tags: ['supprimer', 'suppression', 'effacer', 'désinscrire', 'fermer', 'compte', 'données'],
    link: { label: 'Politique de confidentialité', href: '/legal?doc=privacy' },
  },
  {
    id: 'countries',
    q: 'Dans quels pays Ballal est disponible ?',
    a: 'Ballal est né en Guinée et s’ouvre à l’Afrique : Sénégal, Côte d’Ivoire, Mali, Burkina Faso, RD Congo, Congo, Cameroun, Gabon, Bénin, Togo, Niger, Nigeria, Ghana, Sierra Leone, Liberia, Gambie, Guinée-Bissau, Cap-Vert et Angola. Vous voyez les professionnels de votre pays.',
    tags: ['pays', 'disponible', 'sénégal', 'côte', 'ivoire', 'mali', 'congo', 'afrique', 'où'],
  },
  {
    id: 'founder',
    q: 'Qui a créé Ballal ?',
    a: `Ballal est créé par ${COMPANY.founder}, fondateur et PDG d’${COMPANY.company}, à Conakry. Sa conviction : « ${COMPANY.slogan} »`,
    tags: ['créateur', 'fondateur', 'créé', 'qui', 'alpha', 'amadou', 'bah', 'pdg', 'patron', 'propriétaire', 'auteur'],
  },
  {
    id: 'company',
    q: 'C’est quoi Amadou Technology ?',
    a: `${COMPANY.company} est une entreprise technologique basée à ${COMPANY.office}, fondée par ${COMPANY.founder}. Elle crée des sites web 3D et animés, des applications mobiles, des logiciels de gestion pour les PME africaines, et des supports de communication (logos, badges, kakemonos, t-shirts…). Site : ${COMPANY.site}`,
    tags: ['amadou', 'technology', 'technologie', 'entreprise', 'société', 'agence', 'site web', 'application', 'logiciel', 'création', 'devis'],
    link: { label: 'Contacter Amadou Technology', href: '/support' },
  },
  {
    id: 'contact',
    q: 'Comment contacter le support ?',
    a: `WhatsApp Business et téléphone : ${COMPANY.phone}. E-mail : ${COMPANY.email}. Bureau : ${COMPANY.office}.`,
    tags: ['contact', 'contacter', 'support', 'aide', 'whatsapp', 'téléphone', 'numéro', 'email', 'mail', 'adresse', 'bureau'],
    link: { label: 'Aide & Support', href: '/support' },
  },
  {
    id: 'notifs',
    q: 'Pourquoi je reçois des rappels ?',
    a: 'Ballal rappelle aux professionnels de se faire vérifier et de sponsoriser leur profil pour recevoir plus de clients. Les rappels de sponsorisation s’arrêtent dès que votre profil est sponsorisé.',
    tags: ['notification', 'rappel', 'message', 'alerte', 'pourquoi'],
  },
];

const strip = (s: string) =>
  s
    .toLowerCase()
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .replace(/[^a-z0-9 ]/g, ' ');

const STOP = new Set(['le', 'la', 'les', 'un', 'une', 'des', 'de', 'du', 'et', 'ou', 'je', 'tu', 'il', 'on', 'mon', 'ma', 'mes', 'est', 'a', 'en', 'pour', 'comment', 'que', 'qui', 'quoi', 'ce', 'c', 'l', 'd', 'j', 'sur', 'avec', 'dans', 'pas', 'ne']);

/** Réponses les plus pertinentes pour une question libre (score par mots-clés, sans accents). */
export function bestAnswers(question: string, max = 2): Faq[] {
  const words = strip(question).split(/\s+/).filter((w) => w.length > 1 && !STOP.has(w));
  if (!words.length) return [];
  const scored = FAQ.map((f) => {
    const tags = f.tags.map(strip);
    const hay = strip(`${f.q} ${f.a}`);
    let score = 0;
    for (const w of words) {
      if (tags.some((t) => t === w || t.includes(w) || (w.length > 4 && w.includes(t)))) score += 3;
      else if (hay.includes(w)) score += 1;
    }
    return { f, score };
  })
    .filter((x) => x.score >= 3)
    .sort((a, b) => b.score - a.score);
  return scored.slice(0, max).map((x) => x.f);
}

/** Vrai si la question ressemble à la recherche d'un professionnel (« je cherche un plombier »). */
export function looksLikeProSearch(question: string): string | null {
  const q = strip(question);
  const m = q.match(/(?:cherche|besoin d|trouver|il me faut|recherche|veux)\s+(?:un|une|des|d)?\s*([a-z ]{3,40})/);
  if (m) return m[1].trim().split(' ').slice(0, 3).join(' ');
  const trades = ['plombier', 'electricien', 'menuisier', 'macon', 'peintre', 'mecanicien', 'coiffeur', 'coiffeuse', 'couturier', 'tailleur', 'soudeur', 'carreleur', 'frigoriste', 'chauffeur', 'informaticien', 'photographe', 'traiteur', 'nettoyage', 'jardinier', 'serrurier', 'vitrier', 'architecte', 'avocat', 'comptable', 'professeur', 'repetiteur'];
  const t = trades.find((x) => q.includes(x));
  return t ?? null;
}
