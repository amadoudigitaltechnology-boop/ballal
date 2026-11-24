import AsyncStorage from '@react-native-async-storage/async-storage';
import type { Session } from '@supabase/supabase-js';
import { createContext, useCallback, useContext, useEffect, useMemo, useState, type ReactNode } from 'react';

import { supabase } from './supabase';

type Profile = { fullName: string | null; avatarPath: string | null; status: string; roles: string[] };

type Ctx = {
  ready: boolean;
  session: Session | null;
  profile: Profile | null;
  onboardingSeen: boolean;
  needsSetup: boolean;
  refresh: () => Promise<void>;
  markOnboardingSeen: () => Promise<void>;
  signOut: () => Promise<void>;
};

const SessionContext = createContext<Ctx | null>(null);

/** État de connexion partagé par toute l'application (même logique que la version Flutter). */
export function SessionProvider({ children }: { children: ReactNode }) {
  const [ready, setReady] = useState(false);
  const [session, setSession] = useState<Session | null>(null);
  const [profile, setProfile] = useState<Profile | null>(null);
  const [onboardingSeen, setOnboardingSeen] = useState(false);

  const loadProfile = useCallback(async (s: Session | null) => {
    if (!s) {
      setProfile(null);
      return;
    }
    const uid = s.user.id;
    const [p, r] = await Promise.all([
      supabase.from('profiles').select('full_name, avatar_path, status').eq('id', uid).maybeSingle(),
      supabase.from('user_roles').select('role').eq('user_id', uid),
    ]);
    setProfile({
      fullName: (p.data?.full_name as string | null) ?? null,
      avatarPath: (p.data?.avatar_path as string | null) ?? null,
      status: (p.data?.status as string | null) ?? 'active',
      roles: (r.data ?? []).map((x) => x.role as string),
    });
  }, []);

  useEffect(() => {
    let mounted = true;
    (async () => {
      setOnboardingSeen((await AsyncStorage.getItem('onboarding_seen')) === '1');
      const { data } = await supabase.auth.getSession();
      if (!mounted) return;
      setSession(data.session);
      await loadProfile(data.session).catch(() => undefined);
      setReady(true);
    })();
    const { data: sub } = supabase.auth.onAuthStateChange((_e, s) => {
      setSession(s);
      loadProfile(s).catch(() => undefined);
    });
    return () => {
      mounted = false;
      sub.subscription.unsubscribe();
    };
  }, [loadProfile]);

  const value = useMemo<Ctx>(() => {
    const roles = profile?.roles ?? [];
    return {
      ready,
      session,
      profile,
      onboardingSeen,
      needsSetup: !!session && !!profile && (!(profile.fullName ?? '').trim() || !(roles.includes('client') || roles.includes('professional'))),
      refresh: () => loadProfile(session),
      markOnboardingSeen: async () => {
        await AsyncStorage.setItem('onboarding_seen', '1');
        setOnboardingSeen(true);
      },
      signOut: async () => {
        await supabase.auth.signOut();
      },
    };
  }, [ready, session, profile, onboardingSeen, loadProfile]);

  return <SessionContext.Provider value={value}>{children}</SessionContext.Provider>;
}

export function useSession(): Ctx {
  const ctx = useContext(SessionContext);
  if (!ctx) throw new Error('useSession hors de SessionProvider');
  return ctx;
}
