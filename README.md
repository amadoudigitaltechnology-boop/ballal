# BALLAL

Plateforme de mise en relation entre clients, professionnels et entreprises — Guinée, puis Afrique.
Marque indépendante portée par **Amadou Technology**.

```
ballal/
├── apps/
│   └── mobile/            App Flutter Android / iOS
├── supabase/
│   ├── migrations/        Schéma PostgreSQL, RLS, fonctions, stockage (versionnés)
│   ├── functions/         Fonctions Edge (Deno)
│   ├── tests/             Tests SQL de sécurité (Postgres local)
│   └── seed.sql           Catégories + zones de Guinée
└── docs/
    ├── ARCHITECTURE.md
    └── ETAT_DU_PROJET.md  Ce qui est fait, ce qui reste, décisions prises
```

## 1. Backend Supabase

```bash
# Prérequis : Supabase CLI
supabase link --project-ref VOTRE_PROJET
supabase db push                       # applique supabase/migrations/*
psql "$DATABASE_URL" -f supabase/seed.sql
supabase functions deploy delete-account
```

Dans le tableau de bord Supabase :
- **Authentication → Providers → Phone** : activer et brancher un fournisseur SMS (Twilio, Vonage, MessageBird…). Le coût des SMS vers +224 est à budgéter (voir `docs/ETAT_DU_PROJET.md`).
- **Authentication → Rate limits** : garder les limites OTP par défaut ou plus strictes.
- **Database → Extensions** : `pg_trgm`, `unaccent`, `pgcrypto` (créées par la migration 0001).
- **pg_cron** (facultatif) : `select cron.schedule('auto-complete', '0 3 * * *', 'select public.auto_complete_stale_requests()');`
- Premier super-administrateur (SQL, une seule fois) :
  `insert into public.user_roles (user_id, role) values ('<uuid>', 'super_admin');`

### Tests de sécurité (sans Supabase)

```bash
# Postgres 16 local avec pg_trgm + unaccent
PGHOST=/tmp/pg PGPORT=5433 ./supabase/tests/run.sh
```
65 vérifications : accès croisé interdit, messages privés, avis vérifiés, transitions de statut,
anti-spam, recherche tolérante aux fautes, proximité, recommandations explicables, modération sans accès aux conversations.

## 2. App mobile

```bash
cd apps/mobile
flutter create --org com.amadoutechnology --project-name ballal --platforms android,ios .
python3 tool/setup_platforms.py         # permissions localisation, micro, photos
cp env/dev.json.example env/dev.json    # puis renseigner l'URL et la clé ANON (jamais la clé service)
flutter pub get
flutter gen-l10n
flutter analyze && flutter test
flutter run --dart-define-from-file=env/dev.json
```

Flutter ≥ 3.32 requis.
