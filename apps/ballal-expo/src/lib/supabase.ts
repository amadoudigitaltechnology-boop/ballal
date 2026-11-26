import 'react-native-url-polyfill/auto';

import AsyncStorage from '@react-native-async-storage/async-storage';
import { createClient } from '@supabase/supabase-js';
import { AppState, Platform } from 'react-native';

import { env } from './env';


/** Même base que l'application Flutter : comptes, pros, messages partagés. */
export const supabase = createClient(env.supabaseUrl, env.supabaseAnonKey, {
  auth: {
    storage: AsyncStorage,
    autoRefreshToken: true,
    persistSession: true, // l'utilisateur reste connecté entre deux ouvertures
    detectSessionInUrl: false,
  },
});

// Rafraîchit la session seulement quand l'application est au premier plan.
if (Platform.OS !== 'web') {
  AppState.addEventListener('change', (state) => {
    if (state === 'active') supabase.auth.startAutoRefresh();
    else supabase.auth.stopAutoRefresh();
  });
}

export function publicUrl(bucket: string, path?: string | null): string | null {
  if (!path) return null;
  if (path.startsWith('http')) return path;
  return supabase.storage.from(bucket).getPublicUrl(path).data.publicUrl;
}

/** Message d'erreur lisible en français. */
export function friendlyError(e: unknown): string {
  const m = (e as { message?: string })?.message ?? String(e);
  const l = m.toLowerCase();
  if (l.includes('invalid login') || l.includes('invalid credentials')) return 'E-mail ou mot de passe incorrect.';
  if (l.includes('already registered') || l.includes('already_registered')) return 'Un compte existe déjà avec cet e-mail.';
  if (l.includes('not confirmed')) return 'Confirmez d’abord votre e-mail avec le code reçu.';
  if (l.includes('expired') || l.includes('otp')) return 'Code incorrect ou expiré.';
  if (l.includes('network') || l.includes('fetch')) return 'Pas de connexion Internet.';
  if (l.includes('rate limit')) return 'Trop de tentatives. Réessayez dans quelques minutes.';
  return 'Une erreur s’est produite. Réessayez.';
}

/** Mot de passe robuste : 8 caractères, au moins une lettre et un chiffre. */
export function strongPassword(p: string): boolean {
  return p.length >= 8 && /[A-Za-zÀ-ÿ]/.test(p) && /[0-9]/.test(p);
}

/** Compte créé avec Google sans mot de passe BALLAL : on lui fait créer un mot de passe. */
export function needsPassword(user: { app_metadata?: Record<string, unknown>; user_metadata?: Record<string, unknown> } | null | undefined): boolean {
  if (!user) return false;
  const provider = (user.app_metadata?.provider as string | undefined) ?? 'email';
  return provider !== 'email' && !user.user_metadata?.password_set;
}
