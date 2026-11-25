/**
 * Variables d'environnement vérifiées au démarrage.
 * Elles viennent de .env.local (jamais commité) ou des variables EAS.
 * Seules des clés publiques sont autorisées : une clé « service_role » fait planter l'app exprès.
 */
function required(name: string, value: string | undefined): string {
  if (!value || !value.trim()) throw new Error(`Configuration manquante : ${name} (voir .env.example)`);
  return value.trim();
}

const url = required('EXPO_PUBLIC_SUPABASE_URL', process.env.EXPO_PUBLIC_SUPABASE_URL);
const anonKey = required('EXPO_PUBLIC_SUPABASE_ANON_KEY', process.env.EXPO_PUBLIC_SUPABASE_ANON_KEY);

if (!/^https:\/\/[a-z0-9-]+\.supabase\.co$/.test(url)) {
  throw new Error('EXPO_PUBLIC_SUPABASE_URL doit être une adresse https://<projet>.supabase.co');
}

function jwtRole(token: string): string | null {
  try {
    const part = token.split('.')[1].replace(/-/g, '+').replace(/_/g, '/');
    return JSON.parse(atob(part)).role ?? null;
  } catch {
    return null;
  }
}
const role = anonKey.startsWith('sb_publishable_') ? 'anon' : jwtRole(anonKey);
if (role !== 'anon') {
  throw new Error('EXPO_PUBLIC_SUPABASE_ANON_KEY doit être la clé publique (anon). Jamais la clé service_role.');
}

export const env = { supabaseUrl: url, supabaseAnonKey: anonKey } as const;
