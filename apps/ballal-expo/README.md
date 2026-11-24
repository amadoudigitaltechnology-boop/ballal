# BALLAL — version Expo (iPhone + Android)

Même base Supabase que l'application Flutter (`apps/mobile`) : mêmes comptes, mêmes pros, mêmes messages.

## Tester sur iPhone avec Expo Go (gratuit)

1. Sur l'iPhone : installer **Expo Go** depuis l'App Store.
2. Sur le PC : installer **Node.js LTS** (https://nodejs.org) si ce n'est pas déjà fait.
3. Dans l'invite de commandes (cmd) :

```
git clone https://github.com/amadoudigitaltechnology-boop/ballal.git
cd ballal\apps\ballal-expo
npm install
npx expo start --tunnel
```

4. Un QR code s'affiche : le scanner avec l'appareil photo de l'iPhone → BALLAL s'ouvre dans Expo Go.

## Contenu de la démo

Présentation, connexion / création de compte (mot de passe, code à 6 chiffres, mot de passe oublié, Google),
profil à compléter, accueil (bannière, catégories, tous les pros), recherche, fiche pro (contacter),
messages (liste), profil, paramètres, déconnexion.

## Vérifications

```
npx tsc --noEmit
npx expo lint
```
