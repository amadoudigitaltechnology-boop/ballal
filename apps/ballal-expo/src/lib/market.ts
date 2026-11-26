import * as Crypto from 'expo-crypto';

import { supabase } from './supabase';

export const MARKET_CATEGORIES = [
  { key: 'phones', label: 'Téléphones', icon: 'phone-portrait' },
  { key: 'electronics', label: 'Électronique', icon: 'tv' },
  { key: 'fashion', label: 'Mode', icon: 'shirt' },
  { key: 'home', label: 'Maison', icon: 'bed' },
  { key: 'vehicles', label: 'Véhicules', icon: 'car-sport' },
  { key: 'beauty', label: 'Beauté', icon: 'sparkles' },
  { key: 'food', label: 'Alimentation', icon: 'restaurant' },
  { key: 'other', label: 'Autres', icon: 'cube' },
] as const;
export type MarketCategory = (typeof MARKET_CATEGORIES)[number]['key'];

export const categoryLabel = (k: string) => MARKET_CATEGORIES.find((c) => c.key === k)?.label ?? 'Autres';

export type Listing = {
  id: string;
  sellerId: string;
  sellerName: string;
  sellerAvatar: string | null;
  title: string;
  description: string | null;
  priceGnf: number;
  category: string;
  condition: 'new' | 'used';
  locationName: string | null;
  photos: string[];
  status: 'active' | 'sold' | 'removed';
  views: number;
  createdAt: string;
};

function toListing(m: Record<string, any>): Listing {
  return {
    id: m.id,
    sellerId: m.seller_id,
    sellerName: m.seller_name ?? 'Vendeur',
    sellerAvatar: m.seller_avatar ?? null,
    title: m.title,
    description: m.description ?? null,
    priceGnf: Number(m.price_gnf ?? 0),
    category: m.category,
    condition: m.condition === 'new' ? 'new' : 'used',
    locationName: m.location_name ?? null,
    photos: m.photos ?? [],
    status: m.status,
    views: Number(m.views ?? 0),
    createdAt: m.created_at,
  };
}

export async function marketFeed(opts: { category?: string | null; query?: string; seller?: string; id?: string; offset?: number; limit?: number } = {}) {
  const { data, error } = await supabase.rpc('market_feed', {
    p_category: opts.category ?? null,
    p_query: opts.query?.trim() || null,
    p_seller: opts.seller ?? null,
    p_limit: opts.limit ?? 30,
    p_offset: opts.offset ?? 0,
    p_id: opts.id ?? null,
  });
  if (error) throw error;
  return ((data ?? []) as Record<string, any>[]).map(toListing);
}

export async function getListing(id: string): Promise<Listing | null> {
  const [l] = await marketFeed({ id, limit: 1 });
  return l ?? null;
}

export function marketPhoto(path?: string | null): string | null {
  if (!path) return null;
  return supabase.storage.from('market').getPublicUrl(path).data.publicUrl;
}

/** Prix court pour les petites cartes : 4,5 M GNF. */
export function gnfShort(n: number): string {
  if (n >= 1_000_000) return `${(Math.round(n / 100_000) / 10).toLocaleString('fr-FR')} M GNF`;
  return gnf(n);
}

/** Prix lisible : 4 500 000 GNF. */
export function gnf(n: number): string {
  return `${Math.round(n).toLocaleString('fr-FR').replace(/ | /g, ' ')} GNF`;
}

const ALLOWED = ['image/jpeg', 'image/png', 'image/webp'];
const MAX_BYTES = 5 * 1024 * 1024;

/** Envoie une photo dans le dossier du vendeur (type et taille vérifiés ici ET par le serveur). */
export async function uploadMarketPhoto(uid: string, uri: string, mime?: string | null, size?: number | null): Promise<string> {
  const type = mime && ALLOWED.includes(mime) ? mime : 'image/jpeg';
  if (size && size > MAX_BYTES) throw new Error('photo_too_big');
  const body = await (await fetch(uri)).arrayBuffer();
  if (body.byteLength > MAX_BYTES) throw new Error('photo_too_big');
  const ext = type === 'image/png' ? 'png' : type === 'image/webp' ? 'webp' : 'jpg';
  const path = `${uid}/${Crypto.randomUUID()}.${ext}`;
  const { error } = await supabase.storage.from('market').upload(path, body, { contentType: type, upsert: false });
  if (error) throw error;
  return path;
}

export async function createListing(input: {
  sellerId: string;
  title: string;
  description: string;
  priceGnf: number;
  category: string;
  condition: 'new' | 'used';
  locationName: string;
  photos: string[];
}) {
  const { data, error } = await supabase
    .from('listings')
    .insert({
      seller_id: input.sellerId,
      title: input.title.trim(),
      description: input.description.trim() || null,
      price_gnf: input.priceGnf,
      category: input.category,
      condition: input.condition,
      location_name: input.locationName.trim() || null,
      photos: input.photos,
    })
    .select('id')
    .single();
  if (error) throw error;
  return data.id as string;
}

export async function setListingStatus(id: string, status: 'active' | 'sold') {
  const { error } = await supabase.from('listings').update({ status }).eq('id', id);
  if (error) throw error;
}

export async function deleteListing(l: Listing) {
  const { error } = await supabase.from('listings').delete().eq('id', l.id);
  if (error) throw error;
  if (l.photos.length) await supabase.storage.from('market').remove(l.photos);
}

export async function contactSeller(listingId: string): Promise<string> {
  const { data, error } = await supabase.rpc('start_listing_conversation', { p_listing: listingId });
  if (error) throw error;
  return data as string;
}
