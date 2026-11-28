import { useCallback, useEffect, useState } from 'react';

import { useSession } from './session';
import { supabase } from './supabase';

const fmt = (n: number, unit: string) => `${Math.round(n).toLocaleString('fr-FR').replace(/\s/g, ' ')} ${unit}`;

/**
 * Affichage des prix selon le pays de l'utilisateur.
 * Les prix sont fixés en GNF côté serveur ; hors Guinée (GeniusPay), ils sont convertis en FCFA
 * avec la même règle que le serveur : arrondi à la centaine supérieure, minimum 200.
 */
export function useMoney() {
  const { session } = useSession();
  const uid = session?.user.id ?? '';
  const [cur, setCur] = useState<{ xof: boolean; rate: number }>({ xof: false, rate: 15 });

  useEffect(() => {
    if (!uid) return;
    let alive = true;
    Promise.all([
      supabase.from('profiles').select('country_code').eq('id', uid).maybeSingle(),
      supabase.from('app_settings').select('key, value').in('key', ['gnf_per_xof', 'geniuspay_countries']),
    ])
      .then(([{ data: p }, { data: s }]) => {
        if (!alive) return;
        const country = (p?.country_code as string | null) ?? 'GN';
        const get = (k: string) => s?.find((r) => r.key === k)?.value;
        const list = get('geniuspay_countries');
        const rate = Number(get('gnf_per_xof'));
        setCur({ xof: country !== 'GN' && Array.isArray(list) && list.includes(country), rate: rate > 0 ? rate : 15 });
      })
      .catch(() => undefined);
    return () => {
      alive = false;
    };
  }, [uid]);

  return useCallback(
    (gnf: number, approx = false) =>
      !cur.xof ? fmt(gnf, 'GNF') : fmt(approx ? gnf / cur.rate : Math.max(200, Math.ceil(gnf / cur.rate / 100) * 100), 'FCFA'),
    [cur],
  );
}
