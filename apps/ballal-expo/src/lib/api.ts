import { supabase } from './supabase';

export type ProCard = {
  id: string;
  displayName: string;
  headline: string;
  logoPath: string | null;
  locationName: string | null;
  availability: string;
  ratingAvg: number;
  ratingCount: number;
  verified: boolean;
  distanceKm: number | null;
  isFeatured: boolean;
};

export type Category = { id: string; name: string; icon: string | null; parentId: string | null };

const num = (v: unknown) => (typeof v === 'number' ? v : v == null ? 0 : Number(v));

function toCard(m: Record<string, unknown>): ProCard {
  return {
    id: m.professional_id as string,
    displayName: (m.display_name as string) ?? '',
    headline: (m.headline as string) ?? '',
    logoPath: (m.logo_path as string) ?? null,
    locationName: (m.location_name as string) ?? null,
    availability: (m.availability as string) ?? 'available',
    ratingAvg: num(m.rating_avg),
    ratingCount: num(m.rating_count),
    verified: !!(m.identity_verified || m.company_verified),
    distanceKm: m.distance_km == null ? null : num(m.distance_km),
    isFeatured: !!m.is_featured,
  };
}

/** Recherche des pros (même fonction serveur que l'application Flutter). */
export async function searchPros(opts: { query?: string; categoryId?: string; offset?: number; sort?: string } = {}) {
  const { data, error } = await supabase.rpc('search_professionals', {
    p_query: opts.query?.trim() || null,
    p_category: opts.categoryId ?? null,
    p_sort: opts.sort ?? 'relevance',
    p_limit: 20,
    p_offset: opts.offset ?? 0,
  });
  if (error) throw error;
  return ((data ?? []) as Record<string, unknown>[]).map(toCard);
}

let catCache: Category[] | null = null;
export async function families(): Promise<Category[]> {
  if (!catCache) {
    const { data, error } = await supabase.from('categories').select('id, name, icon, parent_id').order('sort_order');
    if (error) throw error;
    catCache = (data ?? []).map((c) => ({ id: c.id, name: c.name, icon: c.icon, parentId: c.parent_id }));
  }
  return catCache.filter((c) => c.parentId === null);
}

export type ProDetail = {
  id: string;
  displayName: string;
  headline: string;
  description: string;
  logoPath: string | null;
  coverPath: string | null;
  locationName: string | null;
  availability: string;
  ratingAvg: number;
  ratingCount: number;
  verified: boolean;
  experienceYears: number | null;
  profileViews: number;
  skills: string[];
  categories: string[];
};

export async function proDetail(id: string): Promise<ProDetail | null> {
  const { data, error } = await supabase
    .from('professional_profiles')
    .select('*, location:locations(name), professional_categories(category:categories(name))')
    .eq('user_id', id)
    .maybeSingle();
  if (error) throw error;
  if (!data) return null;
  const d = data as Record<string, any>;
  return {
    id,
    displayName: d.display_name ?? '',
    headline: d.headline ?? '',
    description: d.description ?? '',
    logoPath: d.logo_path,
    coverPath: d.cover_path,
    locationName: d.location?.name ?? null,
    availability: d.availability ?? 'available',
    ratingAvg: num(d.rating_avg),
    ratingCount: num(d.rating_count),
    verified: !!(d.identity_verified || d.company_verified),
    experienceYears: d.experience_years ?? null,
    profileViews: num(d.profile_views),
    skills: d.skills ?? [],
    categories: (d.professional_categories ?? []).map((pc: any) => pc.category?.name).filter(Boolean),
  };
}

export type Conversation = {
  id: string;
  otherName: string;
  otherAvatar: string | null;
  otherIsPro: boolean;
  lastMessageAt: string | null;
  preview: string | null;
  unread: number;
};

export async function conversations(): Promise<Conversation[]> {
  const { data, error } = await supabase.rpc('list_my_conversations', { p_limit: 50 });
  if (error) throw error;
  return ((data ?? []) as Record<string, any>[]).map((m) => ({
    id: m.conversation_id,
    otherName: m.other_name ?? '',
    otherAvatar: m.other_avatar ?? null,
    otherIsPro: !!m.other_is_pro,
    lastMessageAt: m.last_message_at ?? null,
    preview: m.last_message_preview ?? null,
    unread: num(m.unread_count),
  }));
}

/** Icône Ionicons correspondant au code d'icône des catégories. */
export function categoryIcon(code: string | null): string {
  const map: Record<string, string> = {
    construction: 'hammer',
    home: 'home',
    computer: 'laptop',
    local_shipping: 'car',
    face: 'sparkles',
    school: 'school',
    palette: 'color-palette',
    business_center: 'briefcase',
    celebration: 'balloon',
  };
  return (code && map[code]) || 'apps';
}

export function timeAgo(iso: string | null): string {
  if (!iso) return '';
  const s = (Date.now() - new Date(iso).getTime()) / 1000;
  if (s < 60) return 'à l’instant';
  if (s < 3600) return `${Math.floor(s / 60)} min`;
  if (s < 86400) return `${Math.floor(s / 3600)} h`;
  return `${Math.floor(s / 86400)} j`;
}
