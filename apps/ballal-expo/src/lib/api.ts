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
  otherUserId: string;
  otherLastReadAt: string | null;
  listingId: string | null;
  listingTitle: string | null;
  listingPhoto: string | null;
  listingPrice: number | null;
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
    otherUserId: m.other_user_id,
    otherLastReadAt: m.other_last_read_at ?? null,
    listingId: m.listing_id ?? null,
    listingTitle: m.listing_title ?? null,
    listingPhoto: m.listing_photo ?? null,
    listingPrice: m.listing_price_gnf == null ? null : Number(m.listing_price_gnf),
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

// ═════════════ Messagerie ═════════════

export type ChatMessage = {
  id: string;
  conversationId: string;
  senderId: string;
  clientId: string | null;
  type: 'text' | 'image' | 'audio';
  body: string | null;
  attachmentPath: string | null;
  durationMs: number | null;
  createdAt: string;
  pending?: boolean;
  failed?: boolean;
};

export function toMessage(m: Record<string, any>): ChatMessage {
  return {
    id: m.id,
    conversationId: m.conversation_id,
    senderId: m.sender_id,
    clientId: m.client_message_id ?? null,
    type: m.type ?? 'text',
    body: m.body ?? null,
    attachmentPath: m.attachment_path ?? null,
    durationMs: m.duration_ms ?? null,
    createdAt: m.created_at,
  };
}

/** Les 100 derniers messages, du plus récent au plus ancien. */
export async function loadMessages(conversationId: string): Promise<ChatMessage[]> {
  const { data, error } = await supabase
    .from('messages')
    .select('*')
    .eq('conversation_id', conversationId)
    .order('created_at', { ascending: false })
    .limit(100);
  if (error) throw error;
  return (data ?? []).map(toMessage);
}

/** Envoi idempotent (un renvoi après coupure ne crée pas de doublon). */
export async function sendText(conversationId: string, senderId: string, clientId: string, body: string): Promise<ChatMessage | null> {
  const { data, error } = await supabase
    .from('messages')
    .insert({ conversation_id: conversationId, sender_id: senderId, client_message_id: clientId, type: 'text', body })
    .select('*')
    .single();
  if (error) {
    if (error.code === '23505') return null;
    throw error;
  }
  return toMessage(data);
}

/** Message vocal : fichier dans le dossier privé de la conversation, puis message de type audio. */
export async function sendAudio(conversationId: string, senderId: string, clientId: string, uri: string, durationMs: number): Promise<ChatMessage | null> {
  const body = await (await fetch(uri)).arrayBuffer();
  if (body.byteLength > 10 * 1024 * 1024) throw new Error('Message vocal trop long.');
  const path = `${conversationId}/${clientId}.m4a`;
  const up = await supabase.storage.from('message-attachments').upload(path, body, { contentType: 'audio/mp4', upsert: true });
  if (up.error) throw up.error;
  const { data, error } = await supabase
    .from('messages')
    .insert({
      conversation_id: conversationId,
      sender_id: senderId,
      client_message_id: clientId,
      type: 'audio',
      attachment_path: path,
      attachment_mime: 'audio/mp4',
      attachment_size: body.byteLength,
      duration_ms: Math.min(Math.max(Math.round(durationMs), 0), 300000),
    })
    .select('*')
    .single();
  if (error) {
    if (error.code === '23505') return null;
    throw error;
  }
  return toMessage(data);
}

export async function markRead(conversationId: string) {
  await supabase.rpc('mark_conversation_read', { p_conv: conversationId });
}

export async function signedAttachment(path: string): Promise<string | null> {
  const { data } = await supabase.storage.from('message-attachments').createSignedUrl(path, 3600);
  return data?.signedUrl ?? null;
}

export async function unreadMessages(): Promise<number> {
  const { data } = await supabase.rpc('get_unread_counts');
  const row = Array.isArray(data) ? data[0] : data;
  return num(row?.messages);
}

export function clock(iso: string): string {
  const d = new Date(iso);
  return `${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`;
}

export function dayLabel(iso: string): string {
  const d = new Date(iso);
  const today = new Date();
  const y = new Date();
  y.setDate(today.getDate() - 1);
  const same = (a: Date, b: Date) => a.toDateString() === b.toDateString();
  if (same(d, today)) return 'Aujourd’hui';
  if (same(d, y)) return 'Hier';
  return d.toLocaleDateString('fr-FR', { weekday: 'long', day: 'numeric', month: 'long' });
}
