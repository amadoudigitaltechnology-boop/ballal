# État du projet — 21 novembre 2026

## Décisions prises par défaut (à confirmer)

| Question ouverte | Choix appliqué | Pour changer |
|---|---|---|
| Connexion | **Code par e-mail** (gratuit). Le code par SMS/WhatsApp est prêt dans le code (`AccountRepo.sendOtp`) mais désactivé : il demande un compte Twilio payant (~0,28 $/SMS vers la Guinée) | Réactiver l'écran téléphone quand le budget SMS/WhatsApp est prêt |
| Numéro du pro | Visible pour les utilisateurs **connectés**, si le pro l'autorise (boutons Appeler / WhatsApp désactivables) | Restreindre `get_professional_contact` aux clients ayant une demande |
| Périmètre | Cahier complet côté base ; app mobile V1 | — |
| Navigation invité | On peut chercher et voir les profils sans compte ; la connexion est demandée pour contacter | Forcer la connexion dans `router.dart` |
| Messages vocaux | **Ajoutés** (usage local très fort) | — |

## Écarts volontaires avec les maquettes

- Connexion **par code e-mail**, sans mot de passe (le SMS est payant). Google viendra ensuite.
- Pas de badge « Utilisateur Premium » ni de « Promotion -20 % » : la V1 est entièrement gratuite (cahier §19).
- Pas de carte interactive : liste triée par distance (cahier §8 « liste prioritaire, carte facultative »).
  La carte demande de choisir un fournisseur (Google Maps payant ou OpenStreetMap gratuit).
- Pas de photos de stock : illustrations par icônes, remplaçables par vos visuels.

## Fait

### Base de données — testée (65 vérifications OK sur PostgreSQL 16)
- Comptes, double rôle, préférences, consentements versionnés
- Profils pros, contacts protégés, catégories hiérarchiques (9 familles, 51 métiers), zones de Guinée
  (8 régions, 5 communes de Conakry, 34 quartiers — coordonnées approximatives à corriger)
- Services, portfolio, horaires, zones d'intervention
- Demandes avec transitions contrôlées et historique, clôture automatique
- Messagerie privée, temps réel, blocage, anti-spam, pièces jointes privées
- Avis vérifiés, réponses du pro, note moyenne automatique
- Signalements avec preuves limitées, modération, suspension, vérification de documents, journal d'audit
- Recherche tolérante, filtres combinés, proximité, recommandations explicables
- Notifications internes selon les préférences
- Suppression de compte (RPC + fonction Edge)

### App Flutter — code écrit, syntaxe vérifiée, **non compilée ici**
Accueil client (zone, catégories, recommandations, demandes récentes) · tableau de bord pro
(statistiques réelles, disponibilité) · recherche + filtres + « près de moi » avec explication GPS ·
profil pro (à propos, avis, services, vérifications, signalement) · demande en 3 étapes avec photos ·
suivi des demandes et actions par rôle · avis · messagerie (texte, photo, vocal, lu, renvoi, blocage) ·
favoris · notifications · compte, bascule client/pro, édition du profil pro, services, horaires,
portfolio · paramètres, personnalisation désactivable, suppression de compte.

## À faire

1. **Compiler et corriger** : `flutter analyze` puis tests sur un vrai téléphone Android d'entrée de gamme
   (l'environnement de travail ici n'a pas le SDK Flutter). Passer la relecture Codex.
2. **Phase 5 — notifications push** : Firebase (FCM), enregistrement des `device_tokens`, fonction Edge
   `send-push` déclenchée par webhook sur `notifications`.
3. **Phase 9 — Web** : site Next.js (pages publiques SEO, profils pros) et back-office d'administration
   (signalements, vérifications, catégories, zones, traductions, audit).
4. Écran de réponse du pro à un avis (la base le permet déjà).
5. Vérification d'identité côté app (envoi des justificatifs ; la base et le stockage privé sont prêts).
6. Traductions Pular, Soussou, Malinké, anglais (fichiers `app_ff.arb`, etc.).
7. Conditions d'utilisation et politique de confidentialité validées par un juriste en Guinée.
8. Corriger les coordonnées des quartiers dans l'administration.
