# Architecture BALLAL

## Vue d'ensemble

```
 App Flutter (Android/iOS)          Site Next.js + back-office (phase 9)
          │  supabase_flutter                │
          ▼                                  ▼
 ┌────────────────────── Supabase ──────────────────────┐
 │ Auth (OTP SMS)   PostgREST + RPC   Realtime   Storage │
 │                PostgreSQL + RLS                       │
 │  Edge Functions : delete-account (fait),              │
 │                   send-push FCM (phase 5),            │
 │                   recommend IA externe (phase 7+)     │
 └───────────────────────────────────────────────────────┘
```

**Principe de sécurité** : chaque table exposée a RLS. Les écritures sensibles (statut d'une demande,
ouverture de conversation, signalement, modération, rôles) passent uniquement par des fonctions SQL
`SECURITY DEFINER` qui vérifient `auth.uid()`. Les colonnes réservées (note moyenne, badges vérifiés,
statut du compte) sont protégées par déclencheur, même si un client envoie une requête trafiquée.

## Base de données (migrations)

| Fichier | Contenu |
|---|---|
| 0001 | Extensions (`pg_trgm`, `unaccent`, `pgcrypto`), types, `f_norm()` |
| 0002 | 34 tables (comptes, pros, catalogue, zones, demandes, messagerie, avis, signalements, notifications, audit) |
| 0003 | Helpers de rôles, anti-spam, notifications, déclencheurs (historique des statuts, note moyenne, document de recherche) |
| 0004 | Politiques RLS + droits par colonne |
| 0005 | RPC : comptes, demandes, conversations, recherche, recommandation, modération |
| 0006 | Buckets de stockage publics / privés et leurs règles |
| 0007 | Publication temps réel (messages, notifications, accusés de lecture) |
| 0008 | Statistiques du tableau de bord pro |

Correspondance avec le cahier des charges : la table `users` s'appelle `profiles` (Supabase gère
`auth.users`) ; `user_roles` permet le double rôle client + pro.

## Choix techniques notables

- **Recherche** : document normalisé (sans accents, minuscules) + index trigrammes. Chaque mot de la
  requête doit correspondre exactement ou avec une faute (`word_similarity ≥ 0,5`).
  « plombie », « Plombier Kipé », « chauffe eau » trouvent le même pro.
- **Zones** : arbre `pays > région > ville > commune > quartier` avec chemin matérialisé.
  Un pro qui couvre Ratoma apparaît pour un client qui choisit Kipé, et inversement.
- **Proximité** : distance de Haversine sur le centre de la zone du pro (jamais son domicile),
  préfiltre par boîte englobante. PostGIS pourra remplacer ce calcul sans changer l'app.
- **Recommandation (moteur « rules-v1 »)** : score explicable = zone 30 % + note bayésienne 25 %
  + disponibilité récente 15 % + affinité de catégories 15 % + qualité du profil 15 %, au plus 3 pros
  par catégorie pour la diversité. Chaque résultat porte ses raisons (« Intervient dans votre zone »…).
  « Disponible » n'est affiché que si le pro a mis à jour sa disponibilité depuis moins de 7 jours.
  Si le RPC échoue, l'app se replie sur la recherche classique.
- **Messagerie** : temps réel Supabase, envoi idempotent (`client_message_id`), renvoi après échec,
  reconnexion automatique, photos et **messages vocaux**, accusés de lecture, blocage, 30 messages/minute max.
- **Signalement** : seuls les messages joints par la personne qui signale sont copiés pour la
  modération. Les administrateurs n'ont aucun accès aux conversations.
- **Avis** : uniquement sur une demande terminée, un seul par demande. Le client peut lui-même
  marquer la prestation terminée (le pro ne peut pas bloquer un avis négatif), et une demande
  acceptée sans nouvelles est clôturée automatiquement après 14 jours.

## App Flutter

```
lib/
├── core/        thème, config, session, client Supabase, formats, compteurs non-lus
├── data/        modèles + dépôts (une classe par domaine)
├── widgets/     composants communs (cartes, badges, sélecteur de zone…)
├── features/    un dossier par écran / parcours
├── l10n/        textes (app_fr.arb) — aucun texte en dur dans le code
└── router.dart  navigation go_router + redirections (connexion, profil à compléter, compte suspendu)
```

Pas de bibliothèque de gestion d'état lourde : `ChangeNotifier` pour la session et les non-lus,
`FutureBuilder` / `StreamBuilder` pour le reste.
