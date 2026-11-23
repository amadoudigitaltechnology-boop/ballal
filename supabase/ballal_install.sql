-- BALLAL — installation complète (migrations 0001→0013 + données de départ)
-- À coller en une fois dans Supabase → SQL Editor → Run, sur un projet VIDE.

-- ═══════ migrations/20261121000001_extensions_types.sql ═══════
-- BALLAL — 0001 : extensions et types
-- Supabase installe les extensions dans le schéma "extensions".

create schema if not exists extensions;
create extension if not exists pg_trgm with schema extensions;
create extension if not exists unaccent with schema extensions;
create extension if not exists pgcrypto with schema extensions;

-- Normalisation pour la recherche : minuscules + sans accents.
-- unaccent() n'est pas IMMUTABLE ; on l'encapsule pour pouvoir l'indexer.
create or replace function public.f_norm(t text)
returns text
language sql
immutable
parallel safe
set search_path = ''
as $$
  select lower(extensions.unaccent('extensions.unaccent'::regdictionary, coalesce(t, '')))
$$;

create type public.app_role as enum ('client', 'professional', 'moderator', 'admin', 'super_admin');
create type public.account_status as enum ('active', 'suspended', 'deleted');
create type public.pro_type as enum ('independent', 'company');
create type public.availability_status as enum ('available', 'busy', 'unavailable', 'by_appointment');
create type public.publish_status as enum ('draft', 'published', 'archived');
create type public.location_level as enum ('country', 'region', 'prefecture', 'city', 'commune', 'quartier');
create type public.request_status as enum (
  'pending',        -- envoyée, pas encore traitée
  'needs_info',     -- le pro demande des précisions
  'in_discussion',
  'accepted',
  'declined',
  'cancelled',
  'completed'
);
create type public.message_type as enum ('text', 'image', 'audio');
create type public.media_type as enum ('image', 'video');
create type public.review_status as enum ('published', 'hidden');
create type public.report_target as enum ('user', 'professional', 'service', 'review', 'message', 'conversation');
create type public.report_status as enum ('open', 'in_review', 'resolved', 'rejected');
create type public.doc_status as enum ('pending', 'approved', 'rejected');
create type public.doc_type as enum ('identity', 'company');
create type public.reco_action as enum ('impression', 'click', 'contact', 'request');

-- ═══════ migrations/20261121000002_core_tables.sql ═══════
-- BALLAL — 0002 : tables principales
-- Correspondance cahier des charges : "users" = public.profiles (lié à auth.users).

-- ───────────── Comptes ─────────────
create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text check (char_length(full_name) <= 120),
  avatar_path text,
  phone_verified boolean not null default false,
  status public.account_status not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.user_roles (
  user_id uuid not null references public.profiles(id) on delete cascade,
  role public.app_role not null,
  created_at timestamptz not null default now(),
  primary key (user_id, role)
);

create table public.user_preferences (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  locale text not null default 'fr' check (locale in ('fr', 'ff', 'sus', 'man', 'en')),
  active_mode public.app_role not null default 'client' check (active_mode in ('client', 'professional')),
  preferred_radius_km int not null default 10 check (preferred_radius_km between 1 and 200),
  personalization_enabled boolean not null default true,
  notify_messages boolean not null default true,
  notify_requests boolean not null default true,
  notify_account boolean not null default true,
  notify_product boolean not null default false,
  quiet_hours_start time,
  quiet_hours_end time,
  updated_at timestamptz not null default now()
);

create table public.user_consents (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  consent_type text not null check (consent_type in ('terms', 'privacy', 'geolocation', 'personalization', 'marketing')),
  policy_version text not null,
  granted boolean not null,
  created_at timestamptz not null default now()
);

-- ───────────── Zones géographiques ─────────────
create table public.locations (
  id uuid primary key default gen_random_uuid(),
  parent_id uuid references public.locations(id) on delete restrict,
  level public.location_level not null,
  name text not null,
  slug text not null,
  path text not null default '', -- chemin matérialisé : /guinee/conakry/ratoma/kipe/
  lat double precision check (lat between -90 and 90),
  lng double precision check (lng between -180 and 180),
  is_active boolean not null default true,
  unique (parent_id, slug)
);
create index locations_path_idx on public.locations (path text_pattern_ops);
create index locations_parent_idx on public.locations (parent_id);

-- ───────────── Catalogue ─────────────
create table public.categories (
  id uuid primary key default gen_random_uuid(),
  parent_id uuid references public.categories(id) on delete restrict,
  name text not null,
  slug text not null unique,
  icon text,
  is_active boolean not null default true,
  sort_order int not null default 0
);
create index categories_parent_idx on public.categories (parent_id);

-- ───────────── Clients ─────────────
create table public.client_profiles (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  favorite_location_id uuid references public.locations(id) on delete set null,
  created_at timestamptz not null default now()
);

-- ───────────── Professionnels ─────────────
create table public.professional_profiles (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  pro_type public.pro_type not null default 'independent',
  display_name text not null default '' check (char_length(display_name) <= 120),
  slug text unique,
  headline text not null default '' check (char_length(headline) <= 120), -- métier principal
  description text not null default '' check (char_length(description) <= 3000),
  logo_path text,
  cover_path text,
  experience_years int check (experience_years between 0 and 80),
  languages text[] not null default '{fr}',
  skills text[] not null default '{}',
  location_id uuid references public.locations(id) on delete set null, -- zone de base (jamais l'adresse)
  lat double precision check (lat between -90 and 90),  -- centre de la zone de service, pas le domicile
  lng double precision check (lng between -180 and 180),
  availability public.availability_status not null default 'available',
  availability_updated_at timestamptz not null default now(),
  price_hint text check (char_length(price_hint) <= 120),
  identity_verified boolean not null default false,
  company_verified boolean not null default false,
  is_published boolean not null default false,
  rating_avg numeric(3,2) not null default 0,
  rating_count int not null default 0,
  profile_views int not null default 0,
  search_document text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index pro_search_trgm_idx on public.professional_profiles using gin (search_document extensions.gin_trgm_ops);
create index pro_geo_idx on public.professional_profiles (lat, lng) where is_published;
create index pro_location_idx on public.professional_profiles (location_id);

-- Coordonnées : séparées pour ne jamais être lues directement par les autres.
create table public.professional_contacts (
  user_id uuid primary key references public.professional_profiles(user_id) on delete cascade,
  phone text check (phone ~ '^\+[0-9]{8,15}$'),
  whatsapp text check (whatsapp ~ '^\+[0-9]{8,15}$'),
  email text check (email ~* '^[^@\s]+@[^@\s]+\.[^@\s]+$'),
  show_phone boolean not null default true,
  show_whatsapp boolean not null default true
);

create table public.professional_categories (
  professional_id uuid not null references public.professional_profiles(user_id) on delete cascade,
  category_id uuid not null references public.categories(id) on delete cascade,
  is_primary boolean not null default false,
  primary key (professional_id, category_id)
);
create index pro_cat_category_idx on public.professional_categories (category_id);

create table public.service_areas (
  id uuid primary key default gen_random_uuid(),
  professional_id uuid not null references public.professional_profiles(user_id) on delete cascade,
  location_id uuid not null references public.locations(id) on delete cascade,
  radius_km int check (radius_km between 1 and 200),
  unique (professional_id, location_id)
);
create index service_areas_location_idx on public.service_areas (location_id);

create table public.opening_hours (
  id uuid primary key default gen_random_uuid(),
  professional_id uuid not null references public.professional_profiles(user_id) on delete cascade,
  weekday smallint not null check (weekday between 0 and 6), -- 0 = lundi
  opens time not null,
  closes time not null check (closes > opens),
  unique (professional_id, weekday, opens)
);

create table public.availability_exceptions (
  id uuid primary key default gen_random_uuid(),
  professional_id uuid not null references public.professional_profiles(user_id) on delete cascade,
  day date not null,
  is_closed boolean not null default true,
  note text check (char_length(note) <= 200),
  unique (professional_id, day)
);

create table public.services (
  id uuid primary key default gen_random_uuid(),
  professional_id uuid not null references public.professional_profiles(user_id) on delete cascade,
  category_id uuid references public.categories(id) on delete set null,
  title text not null check (char_length(title) between 2 and 120),
  description text not null default '' check (char_length(description) <= 2000),
  price_min int check (price_min >= 0),
  price_max int check (price_max >= 0),
  price_unit text check (char_length(price_unit) <= 40), -- ex. « par intervention »
  duration_text text check (char_length(duration_text) <= 60),
  status public.publish_status not null default 'draft',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (price_max is null or price_min is null or price_max >= price_min)
);
create index services_pro_idx on public.services (professional_id);

create table public.service_media (
  id uuid primary key default gen_random_uuid(),
  service_id uuid not null references public.services(id) on delete cascade,
  storage_path text not null,
  media_type public.media_type not null default 'image',
  sort_order int not null default 0
);

create table public.portfolio_items (
  id uuid primary key default gen_random_uuid(),
  professional_id uuid not null references public.professional_profiles(user_id) on delete cascade,
  title text check (char_length(title) <= 120),
  description text check (char_length(description) <= 1000),
  storage_path text not null,
  media_type public.media_type not null default 'image',
  taken_on date,
  created_at timestamptz not null default now()
);
create index portfolio_pro_idx on public.portfolio_items (professional_id);

-- ───────────── Mise en relation ─────────────
create table public.service_requests (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references public.profiles(id) on delete cascade,
  professional_id uuid not null references public.professional_profiles(user_id) on delete cascade,
  service_id uuid references public.services(id) on delete set null,
  category_id uuid references public.categories(id) on delete set null,
  title text not null check (char_length(title) between 2 and 120),
  description text not null check (char_length(description) between 5 and 2000),
  location_id uuid references public.locations(id) on delete set null,
  address_hint text check (char_length(address_hint) <= 200), -- repère, jamais publié
  desired_date date,
  budget_min int check (budget_min >= 0),
  budget_max int check (budget_max >= 0),
  status public.request_status not null default 'pending',
  completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (client_id <> professional_id)
);
create index requests_client_idx on public.service_requests (client_id, created_at desc);
create index requests_pro_idx on public.service_requests (professional_id, status, created_at desc);

create table public.request_status_history (
  id bigint generated always as identity primary key,
  request_id uuid not null references public.service_requests(id) on delete cascade,
  from_status public.request_status,
  to_status public.request_status not null,
  changed_by uuid references public.profiles(id) on delete set null,
  note text check (char_length(note) <= 500),
  created_at timestamptz not null default now()
);
create index req_hist_idx on public.request_status_history (request_id, created_at);

create table public.request_attachments (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null references public.service_requests(id) on delete cascade,
  storage_path text not null,
  mime text not null check (mime in ('image/jpeg', 'image/png', 'image/webp')),
  size_bytes int not null check (size_bytes between 1 and 5242880)
);

-- ───────────── Messagerie ─────────────
create table public.conversations (
  id uuid primary key default gen_random_uuid(),
  request_id uuid unique references public.service_requests(id) on delete set null,
  client_id uuid not null references public.profiles(id) on delete cascade,
  professional_id uuid not null references public.profiles(id) on delete cascade,
  created_by uuid not null references public.profiles(id) on delete cascade,
  last_message_at timestamptz,
  last_message_preview text,
  created_at timestamptz not null default now(),
  check (client_id <> professional_id)
);
-- Une seule conversation "directe" (sans demande) par couple client/pro.
create unique index conversations_direct_uniq on public.conversations (client_id, professional_id) where request_id is null;

create table public.conversation_members (
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  member_role public.app_role not null check (member_role in ('client', 'professional')),
  last_read_at timestamptz,
  archived boolean not null default false,
  primary key (conversation_id, user_id)
);
create index conv_members_user_idx on public.conversation_members (user_id);

create table public.messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  sender_id uuid not null references public.profiles(id) on delete cascade,
  client_message_id uuid, -- idempotence : renvoi après coupure réseau
  type public.message_type not null default 'text',
  body text check (char_length(body) <= 4000),
  attachment_path text,
  attachment_mime text,
  attachment_size int check (attachment_size between 1 and 10485760),
  duration_ms int check (duration_ms between 0 and 300000),
  created_at timestamptz not null default now(),
  unique (sender_id, client_message_id),
  check (
    (type = 'text' and body is not null and char_length(btrim(body)) > 0 and attachment_path is null)
    or (type = 'image' and attachment_path is not null and attachment_mime in ('image/jpeg', 'image/png', 'image/webp'))
    or (type = 'audio' and attachment_path is not null and attachment_mime in ('audio/aac', 'audio/mp4', 'audio/m4a', 'audio/mpeg', 'audio/ogg'))
  )
);
create index messages_conv_idx on public.messages (conversation_id, created_at desc);

create table public.user_blocks (
  blocker_id uuid not null references public.profiles(id) on delete cascade,
  blocked_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  check (blocker_id <> blocked_id)
);

-- ───────────── Confiance ─────────────
create table public.favorites (
  client_id uuid not null references public.profiles(id) on delete cascade,
  professional_id uuid not null references public.professional_profiles(user_id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (client_id, professional_id)
);

create table public.reviews (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null unique references public.service_requests(id) on delete cascade,
  client_id uuid not null references public.profiles(id) on delete cascade,
  professional_id uuid not null references public.professional_profiles(user_id) on delete cascade,
  rating smallint not null check (rating between 1 and 5),
  comment text check (char_length(comment) <= 1000),
  status public.review_status not null default 'published',
  moderation_note text,
  created_at timestamptz not null default now()
);
create index reviews_pro_idx on public.reviews (professional_id, created_at desc);

create table public.review_replies (
  review_id uuid primary key references public.reviews(id) on delete cascade,
  professional_id uuid not null references public.professional_profiles(user_id) on delete cascade,
  body text not null check (char_length(body) between 1 and 1000),
  created_at timestamptz not null default now()
);

create table public.reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references public.profiles(id) on delete cascade,
  target_type public.report_target not null,
  target_id uuid not null,
  reason text not null check (reason in ('spam', 'fraud', 'harassment', 'inappropriate', 'fake_profile', 'other')),
  description text check (char_length(description) <= 1000),
  status public.report_status not null default 'open',
  handled_by uuid references public.profiles(id) on delete set null,
  resolution text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Copie des seuls messages joints par la personne qui signale :
-- le modérateur ne lit jamais la conversation entière.
create table public.report_evidence (
  report_id uuid not null references public.reports(id) on delete cascade,
  message_id uuid not null,
  sender_id uuid,
  body text,
  message_type public.message_type,
  sent_at timestamptz,
  primary key (report_id, message_id)
);

create table public.verification_documents (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  doc_type public.doc_type not null,
  storage_path text not null,
  status public.doc_status not null default 'pending',
  reviewed_by uuid references public.profiles(id) on delete set null,
  reviewed_at timestamptz,
  rejection_reason text,
  created_at timestamptz not null default now()
);

-- ───────────── Notifications ─────────────
create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  type text not null check (type in ('new_request', 'request_update', 'new_message', 'new_review', 'review_reply', 'security', 'account', 'product')),
  title text not null,
  body text,
  entity_type text,
  entity_id uuid,
  read_at timestamptz,
  created_at timestamptz not null default now()
);
create index notifications_user_idx on public.notifications (user_id, created_at desc);

create table public.device_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  token text not null unique,
  platform text not null check (platform in ('android', 'ios', 'web')),
  updated_at timestamptz not null default now()
);

-- ───────────── IA / analytics / audit ─────────────
create table public.recommendation_events (
  id bigint generated always as identity primary key,
  user_hash text not null,            -- pseudonymisé
  professional_id uuid references public.professional_profiles(user_id) on delete cascade,
  action public.reco_action not null,
  position int,
  context jsonb not null default '{}', -- contexte minimal : catégorie, rayon, moteur
  created_at timestamptz not null default now()
);

create table public.audit_logs (
  id bigint generated always as identity primary key,
  actor_id uuid references public.profiles(id) on delete set null,
  action text not null,
  target_type text,
  target_id uuid,
  metadata jsonb not null default '{}',
  created_at timestamptz not null default now()
);
create index audit_logs_created_idx on public.audit_logs (created_at desc);

-- Compteur anti-abus générique (messages, demandes, signalements…)
create table public.rate_limits (
  user_id uuid not null,
  bucket text not null,
  window_start timestamptz not null,
  hits int not null default 0,
  primary key (user_id, bucket, window_start)
);

-- ═══════ migrations/20261121000003_helpers_triggers.sql ═══════
-- BALLAL — 0003 : fonctions utilitaires et déclencheurs
-- Toutes les fonctions SECURITY DEFINER fixent search_path = '' et qualifient les objets.

-- ───────────── Rôles et état du compte ─────────────
create or replace function public.has_role(r public.app_role)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.user_roles where user_id = auth.uid() and role = r)
$$;

create or replace function public.is_staff()
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.user_roles
                 where user_id = auth.uid() and role in ('moderator', 'admin', 'super_admin'))
$$;

create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.user_roles
                 where user_id = auth.uid() and role in ('admin', 'super_admin'))
$$;

create or replace function public.is_active_user()
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.profiles where id = auth.uid() and status = 'active')
$$;

create or replace function public.is_conversation_member(conv uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.conversation_members
                 where conversation_id = conv and user_id = auth.uid())
$$;

create or replace function public.is_blocked_between(a uuid, b uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.user_blocks
                 where (blocker_id = a and blocked_id = b) or (blocker_id = b and blocked_id = a))
$$;

-- Vrai si l'appelant est un client connecté direct (pas une fonction serveur de confiance).
create or replace function public.is_end_user_session()
returns boolean language sql stable set search_path = '' as $$
  select current_user in ('authenticated', 'anon')
$$;

-- ───────────── Anti-abus ─────────────
create or replace function public.enforce_rate_limit(p_bucket text, p_max int, p_window interval)
returns void language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := auth.uid();
  v_start timestamptz;
  v_hits int;
begin
  if v_uid is null then return; end if;
  v_start := to_timestamp(floor(extract(epoch from now()) / extract(epoch from p_window)) * extract(epoch from p_window));
  insert into public.rate_limits (user_id, bucket, window_start, hits)
  values (v_uid, p_bucket, v_start, 1)
  on conflict (user_id, bucket, window_start) do update set hits = public.rate_limits.hits + 1
  returning hits into v_hits;
  if v_hits > p_max then
    raise exception 'rate_limited:%', p_bucket using errcode = 'P0429';
  end if;
end $$;

-- ───────────── Audit ─────────────
create or replace function public.log_audit(p_action text, p_target_type text, p_target_id uuid, p_meta jsonb default '{}')
returns void language sql security definer set search_path = '' as $$
  insert into public.audit_logs (actor_id, action, target_type, target_id, metadata)
  values (auth.uid(), p_action, p_target_type, p_target_id, coalesce(p_meta, '{}'))
$$;

-- ───────────── Notifications (respecte les préférences) ─────────────
create or replace function public.notify(p_user uuid, p_type text, p_title text, p_body text,
                                         p_entity_type text, p_entity_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare
  p public.user_preferences;
begin
  select * into p from public.user_preferences where user_id = p_user;
  if found then
    if p_type = 'new_message' and not p.notify_messages then return; end if;
    if p_type in ('new_request', 'request_update') and not p.notify_requests then return; end if;
    if p_type in ('new_review', 'review_reply', 'account') and not p.notify_account then return; end if;
    if p_type = 'product' and not p.notify_product then return; end if;
  end if;
  insert into public.notifications (user_id, type, title, body, entity_type, entity_id)
  values (p_user, p_type, p_title, left(p_body, 200), p_entity_type, p_entity_id);
end $$;

-- ───────────── Création de compte ─────────────
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.profiles (id, full_name, phone_verified)
  values (new.id,
          nullif(left(coalesce(new.raw_user_meta_data ->> 'full_name', ''), 120), ''),
          new.phone_confirmed_at is not null)
  on conflict (id) do nothing;
  insert into public.user_preferences (user_id) values (new.id) on conflict do nothing;
  return new;
end $$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

create or replace function public.handle_user_phone_confirmed()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.phone_confirmed_at is distinct from old.phone_confirmed_at then
    update public.profiles set phone_verified = new.phone_confirmed_at is not null where id = new.id;
  end if;
  return new;
end $$;

create trigger on_auth_user_updated
  after update on auth.users
  for each row execute function public.handle_user_phone_confirmed();

-- ───────────── updated_at ─────────────
create or replace function public.touch_updated_at()
returns trigger language plpgsql set search_path = '' as $$
begin new.updated_at := now(); return new; end $$;

create trigger profiles_touch before update on public.profiles for each row execute function public.touch_updated_at();
create trigger prefs_touch before update on public.user_preferences for each row execute function public.touch_updated_at();
create trigger services_touch before update on public.services for each row execute function public.touch_updated_at();
create trigger requests_touch before update on public.service_requests for each row execute function public.touch_updated_at();
create trigger reports_touch before update on public.reports for each row execute function public.touch_updated_at();

-- ───────────── Colonnes protégées ─────────────
create or replace function public.protect_profile_columns()
returns trigger language plpgsql set search_path = '' as $$
begin
  if public.is_end_user_session() then
    new.phone_verified := old.phone_verified;
    new.status := old.status;
    new.id := old.id;
  end if;
  return new;
end $$;
create trigger profiles_protect before update on public.profiles for each row execute function public.protect_profile_columns();

-- ───────────── Zones : chemin matérialisé ─────────────
create or replace function public.locations_set_path()
returns trigger language plpgsql set search_path = '' as $$
declare parent_path text;
begin
  if new.parent_id is null then
    new.path := '/' || new.slug || '/';
  else
    select path into parent_path from public.locations where id = new.parent_id;
    new.path := parent_path || new.slug || '/';
  end if;
  return new;
end $$;
create trigger locations_path before insert or update of slug, parent_id on public.locations
  for each row execute function public.locations_set_path();

create or replace function public.locations_cascade_path()
returns trigger language plpgsql set search_path = '' as $$
begin
  if new.path is distinct from old.path then
    update public.locations set slug = slug where parent_id = new.id; -- relance le calcul des enfants
  end if;
  return null;
end $$;
create trigger locations_path_cascade after update of path on public.locations
  for each row execute function public.locations_cascade_path();

-- ───────────── Profil pro : slug, coordonnées, recherche, publication ─────────────
-- 1) Protection (SECURITY INVOKER : current_user reste celui du client)
create or replace function public.pro_protect_columns()
returns trigger language plpgsql set search_path = '' as $$
begin
  if public.is_end_user_session() then
    if tg_op = 'UPDATE' then
      new.identity_verified := old.identity_verified;
      new.company_verified := old.company_verified;
      new.rating_avg := old.rating_avg;
      new.rating_count := old.rating_count;
      new.profile_views := old.profile_views;
      new.user_id := old.user_id;
    else
      new.identity_verified := false;
      new.company_verified := false;
      new.rating_avg := 0;
      new.rating_count := 0;
      new.profile_views := 0;
    end if;
  end if;
  return new;
end $$;
create trigger pro_a_protect before insert or update on public.professional_profiles
  for each row execute function public.pro_protect_columns();

-- 2) Calculs (slug, coordonnées, publication, recherche)
create or replace function public.pro_before_write()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  v_loc record;
  v_cats text;
  v_services text;
begin
  if new.slug is null and char_length(btrim(new.display_name)) > 0 then
    new.slug := trim(both '-' from regexp_replace(public.f_norm(new.display_name), '[^a-z0-9]+', '-', 'g'))
                || '-' || left(new.user_id::text, 6);
  end if;

  if new.location_id is not null
     and (tg_op = 'INSERT' or new.location_id is distinct from old.location_id or new.lat is null) then
    select name, lat, lng into v_loc from public.locations where id = new.location_id;
    if new.lat is null or (tg_op = 'UPDATE' and new.location_id is distinct from old.location_id
                           and new.lat is not distinct from old.lat) then
      new.lat := v_loc.lat;
      new.lng := v_loc.lng;
    end if;
  end if;

  if tg_op = 'UPDATE' and new.availability is distinct from old.availability then
    new.availability_updated_at := now();
  end if;

  if new.is_published and (tg_op = 'INSERT' or not old.is_published) then
    if char_length(btrim(new.display_name)) = 0 or char_length(btrim(new.headline)) = 0
       or new.location_id is null then
      raise exception 'profile_incomplete' using errcode = 'P0001',
        hint = 'Nom, métier principal et zone sont obligatoires pour publier.';
    end if;
  end if;

  -- Document de recherche normalisé (nom, métier, compétences, catégories, services, zone)
  select string_agg(c.name, ' ') into v_cats
    from public.professional_categories pc
    join public.categories c on c.id = pc.category_id
   where pc.professional_id = new.user_id;
  select string_agg(s.title, ' ') into v_services
    from public.services s
   where s.professional_id = new.user_id and s.status = 'published';
  select name into v_loc from public.locations where id = new.location_id;

  new.search_document := public.f_norm(concat_ws(' ',
    new.display_name, new.headline, array_to_string(new.skills, ' '),
    v_cats, v_services, v_loc.name, left(new.description, 500)));
  new.updated_at := now();
  return new;
end $$;
create trigger pro_b_compute before insert or update on public.professional_profiles
  for each row execute function public.pro_before_write();

-- Rafraîchit le document de recherche quand les catégories ou services changent.
create or replace function public.pro_refresh_from_child()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  update public.professional_profiles set updated_at = now()
   where user_id = coalesce(new.professional_id, old.professional_id);
  return null;
end $$;
create trigger pro_cat_refresh after insert or delete on public.professional_categories
  for each row execute function public.pro_refresh_from_child();
create trigger services_refresh after insert or update or delete on public.services
  for each row execute function public.pro_refresh_from_child();

-- ───────────── Demandes : historique + notifications ─────────────
create or replace function public.request_after_write()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  v_client_name text;
  v_label text;
  v_target uuid;
begin
  if tg_op = 'INSERT' then
    insert into public.request_status_history (request_id, from_status, to_status, changed_by)
    values (new.id, null, new.status, auth.uid());
    select coalesce(full_name, 'Un client') into v_client_name from public.profiles where id = new.client_id;
    perform public.notify(new.professional_id, 'new_request', 'Nouvelle demande',
                          v_client_name || ' : ' || new.title, 'service_request', new.id);
  elsif new.status is distinct from old.status then
    insert into public.request_status_history (request_id, from_status, to_status, changed_by, note)
    values (new.id, old.status, new.status, auth.uid(), current_setting('ballal.status_note', true));
    v_label := case new.status
      when 'accepted' then 'Votre demande a été acceptée'
      when 'declined' then 'Votre demande a été refusée'
      when 'needs_info' then 'Le professionnel demande des précisions'
      when 'in_discussion' then 'Votre demande est en discussion'
      when 'cancelled' then 'La demande a été annulée'
      when 'completed' then 'La prestation est marquée terminée'
      else 'Mise à jour de votre demande' end;
    v_target := case when auth.uid() = new.professional_id then new.client_id else new.professional_id end;
    perform public.notify(v_target, 'request_update', v_label, new.title, 'service_request', new.id);
  end if;
  return null;
end $$;
create trigger requests_after_write after insert or update on public.service_requests
  for each row execute function public.request_after_write();

-- ───────────── Messages : anti-spam, aperçu, notification ─────────────
create or replace function public.message_before_insert()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  perform public.enforce_rate_limit('messages', 30, interval '1 minute');
  new.created_at := now();
  -- La pièce jointe doit être rangée sous le dossier de la conversation.
  if new.attachment_path is not null
     and split_part(new.attachment_path, '/', 1) <> new.conversation_id::text then
    raise exception 'invalid_attachment_path' using errcode = 'P0001';
  end if;
  return new;
end $$;
create trigger messages_before_insert before insert on public.messages
  for each row execute function public.message_before_insert();

create or replace function public.message_after_insert()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  v_preview text;
  v_sender text;
  m record;
begin
  v_preview := case new.type when 'text' then left(new.body, 80)
                             when 'image' then '📷 Photo' else '🎤 Message vocal' end;
  update public.conversations set last_message_at = new.created_at, last_message_preview = v_preview
   where id = new.conversation_id;
  update public.conversation_members set last_read_at = new.created_at, archived = false
   where conversation_id = new.conversation_id and user_id = new.sender_id;
  select coalesce(pp.display_name, p.full_name, 'Nouveau message') into v_sender
    from public.profiles p left join public.professional_profiles pp on pp.user_id = p.id
   where p.id = new.sender_id;
  for m in select user_id from public.conversation_members
            where conversation_id = new.conversation_id and user_id <> new.sender_id loop
    update public.conversation_members set archived = false
     where conversation_id = new.conversation_id and user_id = m.user_id;
    perform public.notify(m.user_id, 'new_message', v_sender, v_preview, 'conversation', new.conversation_id);
  end loop;
  return null;
end $$;
create trigger messages_after_insert after insert on public.messages
  for each row execute function public.message_after_insert();

-- ───────────── Avis : note moyenne + notification ─────────────
create or replace function public.refresh_pro_rating(p_pro uuid)
returns void language sql security definer set search_path = '' as $$
  update public.professional_profiles pp
     set rating_avg = coalesce(s.avg, 0), rating_count = coalesce(s.cnt, 0)
    from (select round(avg(rating)::numeric, 2) as avg, count(*)::int as cnt
            from public.reviews where professional_id = p_pro and status = 'published') s
   where pp.user_id = p_pro
$$;

create or replace function public.review_after_write()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  perform public.refresh_pro_rating(coalesce(new.professional_id, old.professional_id));
  if tg_op = 'INSERT' then
    perform public.notify(new.professional_id, 'new_review', 'Nouvel avis',
                          new.rating || '/5' || coalesce(' — ' || left(new.comment, 80), ''), 'review', new.id);
  end if;
  return null;
end $$;
create trigger reviews_after_write after insert or update or delete on public.reviews
  for each row execute function public.review_after_write();

create or replace function public.review_reply_after_insert()
returns trigger language plpgsql security definer set search_path = '' as $$
declare v_client uuid;
begin
  select client_id into v_client from public.reviews where id = new.review_id;
  perform public.notify(v_client, 'review_reply', 'Le professionnel a répondu à votre avis',
                        left(new.body, 80), 'review', new.review_id);
  return null;
end $$;
create trigger review_replies_after_insert after insert on public.review_replies
  for each row execute function public.review_reply_after_insert();

-- ═══════ migrations/20261121000004_rls.sql ═══════
-- BALLAL — 0004 : Row Level Security
-- Règle d'or : toute table exposée a RLS activé. Les écritures sensibles passent par des fonctions.

-- ───────────── Helpers de visibilité ─────────────
create or replace function public.is_user_active(p_user uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.profiles where id = p_user and status = 'active')
$$;

create or replace function public.is_public_pro(p_pro uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.professional_profiles pp
                 join public.profiles p on p.id = pp.user_id
                 where pp.user_id = p_pro and pp.is_published and p.status = 'active')
$$;

-- Un profil (nom, photo) est visible par soi, le staff, ou une personne avec qui on a un lien.
create or replace function public.can_view_profile(p_target uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select p_target = auth.uid()
      or public.is_staff()
      or public.is_public_pro(p_target)
      or exists (select 1 from public.conversation_members a
                 join public.conversation_members b on b.conversation_id = a.conversation_id
                 where a.user_id = auth.uid() and b.user_id = p_target)
      or exists (select 1 from public.service_requests r
                 where (r.client_id = auth.uid() and r.professional_id = p_target)
                    or (r.professional_id = auth.uid() and r.client_id = p_target))
$$;

create or replace function public.can_send_message(p_conv uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select public.is_conversation_member(p_conv)
     and public.is_active_user()
     and not exists (
       select 1 from public.conversation_members m
        where m.conversation_id = p_conv and m.user_id <> auth.uid()
          and (public.is_blocked_between(auth.uid(), m.user_id) or not public.is_user_active(m.user_id)))
$$;

-- ───────────── Activation RLS ─────────────
do $$
declare t text;
begin
  foreach t in array array[
    'profiles','user_roles','user_preferences','user_consents','locations','categories',
    'client_profiles','professional_profiles','professional_contacts','professional_categories',
    'service_areas','opening_hours','availability_exceptions','services','service_media',
    'portfolio_items','service_requests','request_status_history','request_attachments',
    'conversations','conversation_members','messages','user_blocks','favorites','reviews',
    'review_replies','reports','report_evidence','verification_documents','notifications',
    'device_tokens','recommendation_events','audit_logs','rate_limits']
  loop
    execute format('alter table public.%I enable row level security', t);
  end loop;
end $$;

-- Colonnes modifiables directement par les utilisateurs
revoke update on public.profiles from anon, authenticated;
grant update (full_name, avatar_path) on public.profiles to authenticated;
revoke update on public.conversation_members from anon, authenticated;
grant update (last_read_at, archived) on public.conversation_members to authenticated;
revoke update on public.notifications from anon, authenticated;
grant update (read_at) on public.notifications to authenticated;
revoke update on public.user_preferences from anon, authenticated;
grant update (locale, active_mode, preferred_radius_km, personalization_enabled, notify_messages,
              notify_requests, notify_account, notify_product, quiet_hours_start, quiet_hours_end)
  on public.user_preferences to authenticated;

-- ───────────── Comptes ─────────────
create policy profiles_select on public.profiles for select using (public.can_view_profile(id));
create policy profiles_update on public.profiles for update to authenticated
  using (id = auth.uid()) with check (id = auth.uid());

create policy roles_select on public.user_roles for select to authenticated
  using (user_id = auth.uid() or public.is_staff());
create policy roles_insert_self on public.user_roles for insert to authenticated
  with check (user_id = auth.uid() and role in ('client', 'professional') and public.is_active_user());

create policy prefs_select on public.user_preferences for select to authenticated using (user_id = auth.uid());
create policy prefs_update on public.user_preferences for update to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy consents_select on public.user_consents for select to authenticated using (user_id = auth.uid());
create policy consents_insert on public.user_consents for insert to authenticated with check (user_id = auth.uid());

-- ───────────── Référentiels ─────────────
create policy locations_select on public.locations for select using (is_active or public.is_admin());
create policy locations_admin on public.locations for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

create policy categories_select on public.categories for select using (is_active or public.is_admin());
create policy categories_admin on public.categories for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

-- ───────────── Clients ─────────────
create policy client_select on public.client_profiles for select to authenticated
  using (user_id = auth.uid() or public.is_staff());
create policy client_insert on public.client_profiles for insert to authenticated
  with check (user_id = auth.uid() and public.has_role('client'));
create policy client_update on public.client_profiles for update to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- ───────────── Professionnels ─────────────
create policy pro_select on public.professional_profiles for select
  using (public.is_public_pro(user_id) or user_id = auth.uid() or public.is_staff());
create policy pro_insert on public.professional_profiles for insert to authenticated
  with check (user_id = auth.uid() and public.has_role('professional') and public.is_active_user());
create policy pro_update on public.professional_profiles for update to authenticated
  using (user_id = auth.uid() or public.is_admin()) with check (user_id = auth.uid() or public.is_admin());

create policy contacts_own on public.professional_contacts for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- Sous-ressources publiques d'un pro : lecture si le pro est publié, écriture par le pro lui-même.
do $$
declare t text;
begin
  foreach t in array array['professional_categories','service_areas','opening_hours',
                           'availability_exceptions','portfolio_items']
  loop
    execute format($f$create policy %1$s_select on public.%1$I for select
      using (public.is_public_pro(professional_id) or professional_id = auth.uid() or public.is_staff())$f$, t);
    execute format($f$create policy %1$s_write on public.%1$I for all to authenticated
      using (professional_id = auth.uid()) with check (professional_id = auth.uid())$f$, t);
  end loop;
end $$;

create policy services_select on public.services for select
  using ((status = 'published' and public.is_public_pro(professional_id))
         or professional_id = auth.uid() or public.is_staff());
create policy services_write on public.services for all to authenticated
  using (professional_id = auth.uid()) with check (professional_id = auth.uid());

create policy service_media_select on public.service_media for select
  using (exists (select 1 from public.services s where s.id = service_id));
create policy service_media_write on public.service_media for all to authenticated
  using (exists (select 1 from public.services s where s.id = service_id and s.professional_id = auth.uid()))
  with check (exists (select 1 from public.services s where s.id = service_id and s.professional_id = auth.uid()));

-- ───────────── Demandes ─────────────
create policy requests_select on public.service_requests for select to authenticated
  using (client_id = auth.uid() or professional_id = auth.uid() or public.is_staff());
create policy requests_insert on public.service_requests for insert to authenticated
  with check (client_id = auth.uid() and status = 'pending' and completed_at is null
              and public.is_active_user() and public.is_public_pro(professional_id)
              and not public.is_blocked_between(auth.uid(), professional_id));
-- Pas de UPDATE direct : changement de statut via public.update_request_status()

create or replace function public.request_before_insert()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  perform public.enforce_rate_limit('requests', 20, interval '1 day');
  return new;
end $$;
create trigger requests_before_insert before insert on public.service_requests
  for each row execute function public.request_before_insert();

create policy req_hist_select on public.request_status_history for select to authenticated
  using (exists (select 1 from public.service_requests r where r.id = request_id));

create policy req_att_select on public.request_attachments for select to authenticated
  using (exists (select 1 from public.service_requests r where r.id = request_id));
create policy req_att_insert on public.request_attachments for insert to authenticated
  with check (exists (select 1 from public.service_requests r
                      where r.id = request_id and r.client_id = auth.uid() and r.status = 'pending')
              and split_part(storage_path, '/', 1) = request_id::text);

-- ───────────── Messagerie ─────────────
create policy conv_select on public.conversations for select to authenticated
  using (public.is_conversation_member(id));
create policy conv_members_select on public.conversation_members for select to authenticated
  using (public.is_conversation_member(conversation_id));
create policy conv_members_update on public.conversation_members for update to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy messages_select on public.messages for select to authenticated
  using (public.is_conversation_member(conversation_id));
create policy messages_insert on public.messages for insert to authenticated
  with check (sender_id = auth.uid() and public.can_send_message(conversation_id));

create policy blocks_own on public.user_blocks for all to authenticated
  using (blocker_id = auth.uid()) with check (blocker_id = auth.uid());

-- ───────────── Confiance ─────────────
create policy favorites_own on public.favorites for all to authenticated
  using (client_id = auth.uid()) with check (client_id = auth.uid());

create policy reviews_select on public.reviews for select
  using (status = 'published' or client_id = auth.uid() or professional_id = auth.uid() or public.is_staff());
create policy reviews_insert on public.reviews for insert to authenticated
  with check (client_id = auth.uid() and status = 'published' and moderation_note is null
              and public.is_active_user()
              and exists (select 1 from public.service_requests r
                          where r.id = request_id and r.client_id = auth.uid()
                            and r.professional_id = reviews.professional_id
                            and r.status = 'completed'));

create policy replies_select on public.review_replies for select
  using (exists (select 1 from public.reviews rv where rv.id = review_id));
create policy replies_insert on public.review_replies for insert to authenticated
  with check (professional_id = auth.uid()
              and exists (select 1 from public.reviews rv where rv.id = review_id and rv.professional_id = auth.uid()));

create policy reports_select on public.reports for select to authenticated
  using (reporter_id = auth.uid() or public.is_staff());
create policy reports_insert on public.reports for insert to authenticated
  with check (reporter_id = auth.uid() and status = 'open' and handled_by is null and resolution is null);
create policy reports_staff_update on public.reports for update to authenticated
  using (public.is_staff()) with check (public.is_staff());

create or replace function public.report_before_insert()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  perform public.enforce_rate_limit('reports', 10, interval '1 day');
  return new;
end $$;
create trigger reports_before_insert before insert on public.reports
  for each row execute function public.report_before_insert();

create policy evidence_staff on public.report_evidence for select to authenticated using (public.is_staff());

create policy verif_select on public.verification_documents for select to authenticated
  using (user_id = auth.uid() or public.is_admin());
create policy verif_insert on public.verification_documents for insert to authenticated
  with check (user_id = auth.uid() and status = 'pending' and reviewed_by is null
              and split_part(storage_path, '/', 1) = auth.uid()::text);

-- ───────────── Notifications ─────────────
create policy notif_select on public.notifications for select to authenticated using (user_id = auth.uid());
create policy notif_update on public.notifications for update to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy notif_delete on public.notifications for delete to authenticated using (user_id = auth.uid());

create policy tokens_own on public.device_tokens for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- ───────────── Audit ─────────────
create policy audit_select on public.audit_logs for select to authenticated using (public.is_admin());
-- recommendation_events, rate_limits : aucune policy → inaccessibles hors fonctions serveur.

-- ═══════ migrations/20261121000005_api_functions.sql ═══════
-- BALLAL — 0005 : fonctions appelées par les applications (RPC)

-- ═════════════ Comptes ═════════════

-- Active le mode client ou professionnel (un compte peut avoir les deux).
create or replace function public.activate_role(p_role public.app_role)
returns void language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := auth.uid();
  v_phone text;
begin
  if v_uid is null then raise exception 'not_authenticated' using errcode = '28000'; end if;
  if p_role not in ('client', 'professional') then raise exception 'forbidden_role' using errcode = '42501'; end if;
  if not public.is_active_user() then raise exception 'account_inactive' using errcode = '42501'; end if;

  insert into public.user_roles (user_id, role) values (v_uid, p_role) on conflict do nothing;
  if p_role = 'client' then
    insert into public.client_profiles (user_id) values (v_uid) on conflict do nothing;
  else
    insert into public.professional_profiles (user_id, display_name)
    select v_uid, coalesce(full_name, '') from public.profiles where id = v_uid
    on conflict do nothing;
    select case when phone is null or phone = '' then null
                when left(phone, 1) = '+' then phone else '+' || phone end
      into v_phone from auth.users where id = v_uid;
    insert into public.professional_contacts (user_id, phone, whatsapp)
    values (v_uid, v_phone, v_phone) on conflict do nothing;
  end if;
  update public.user_preferences set active_mode = p_role where user_id = v_uid;
end $$;

-- Coordonnées d'un pro : seulement pour un utilisateur connecté, actif, non bloqué,
-- et seulement ce que le pro a accepté de montrer.
create or replace function public.get_professional_contact(p_pro uuid)
returns table (phone text, whatsapp text)
language plpgsql stable security definer set search_path = '' as $$
begin
  if auth.uid() is null or not public.is_active_user() then
    raise exception 'not_authenticated' using errcode = '28000';
  end if;
  if not public.is_public_pro(p_pro) or public.is_blocked_between(auth.uid(), p_pro) then
    return;
  end if;
  return query
    select case when c.show_phone then c.phone end, case when c.show_whatsapp then c.whatsapp end
      from public.professional_contacts c where c.user_id = p_pro;
end $$;

-- Vue de profil comptée une fois par heure et par visiteur connecté.
create or replace function public.record_profile_view(p_pro uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare v_inserted int;
begin
  if auth.uid() is null or auth.uid() = p_pro or not public.is_public_pro(p_pro) then return; end if;
  insert into public.rate_limits (user_id, bucket, window_start, hits)
  values (auth.uid(), 'view:' || p_pro, date_trunc('hour', now()), 1)
  on conflict do nothing;
  get diagnostics v_inserted = row_count;
  if v_inserted = 1 then
    update public.professional_profiles set profile_views = profile_views + 1 where user_id = p_pro;
  end if;
end $$;

-- Suppression de compte : anonymisation immédiate ; la suppression auth.users est faite
-- par la fonction Edge "delete-account" (clé service) après ce RPC.
create or replace function public.delete_my_account()
returns void language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := auth.uid();
begin
  if v_uid is null then raise exception 'not_authenticated' using errcode = '28000'; end if;
  update public.profiles set status = 'deleted', full_name = null, avatar_path = null where id = v_uid;
  update public.professional_profiles set is_published = false where user_id = v_uid;
  delete from public.professional_contacts where user_id = v_uid;
  delete from public.device_tokens where user_id = v_uid;
  delete from public.favorites where client_id = v_uid;
  perform public.log_audit('account.delete_requested', 'user', v_uid);
end $$;

-- ═════════════ Demandes ═════════════

create or replace function public.update_request_status(p_request uuid, p_status public.request_status,
                                                        p_note text default null)
returns public.service_requests
language plpgsql security definer set search_path = '' as $$
declare
  r public.service_requests;
  v_uid uuid := auth.uid();
  v_actor text;
  v_ok boolean := false;
begin
  select * into r from public.service_requests where id = p_request for update;
  if not found then raise exception 'not_found' using errcode = 'P0002'; end if;
  if v_uid = r.professional_id then v_actor := 'pro';
  elsif v_uid = r.client_id then v_actor := 'client';
  else raise exception 'forbidden' using errcode = '42501';
  end if;
  if not public.is_active_user() then raise exception 'account_inactive' using errcode = '42501'; end if;

  -- Transitions autorisées
  if v_actor = 'pro' then
    v_ok := (r.status in ('pending', 'needs_info') and p_status in ('needs_info', 'in_discussion', 'accepted', 'declined'))
         or (r.status = 'in_discussion' and p_status in ('needs_info', 'accepted', 'declined'))
         or (r.status = 'accepted' and p_status = 'completed');
  else
    -- Le client peut aussi clôturer : le pro ne peut pas bloquer un avis négatif.
    v_ok := (r.status in ('pending', 'needs_info', 'in_discussion', 'accepted') and p_status = 'cancelled')
         or (r.status = 'needs_info' and p_status = 'pending')
         or (r.status = 'accepted' and p_status = 'completed');
  end if;
  if not v_ok then
    raise exception 'invalid_transition:% -> %', r.status, p_status using errcode = 'P0001';
  end if;

  perform set_config('ballal.status_note', left(coalesce(p_note, ''), 500), true);
  update public.service_requests
     set status = p_status,
         completed_at = case when p_status = 'completed' then now() else completed_at end
   where id = p_request
  returning * into r;
  return r;
end $$;

-- Clôture automatique des demandes acceptées sans nouvelle depuis 14 jours (pg_cron, quotidien).
create or replace function public.auto_complete_stale_requests()
returns int language plpgsql security definer set search_path = '' as $$
declare v_count int;
begin
  perform set_config('ballal.status_note', 'Clôture automatique après 14 jours', true);
  update public.service_requests set status = 'completed', completed_at = now()
   where status = 'accepted'
     and greatest(updated_at, coalesce(desired_date::timestamptz, updated_at)) < now() - interval '14 days';
  get diagnostics v_count = row_count;
  return v_count;
end $$;
revoke execute on function public.auto_complete_stale_requests() from public, anon, authenticated;

-- ═════════════ Messagerie ═════════════

-- Ouvre (ou retrouve) une conversation. Seul le client peut démarrer une conversation directe ;
-- pour une demande, les deux parties peuvent l'ouvrir.
create or replace function public.start_conversation(p_professional uuid default null, p_request uuid default null)
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := auth.uid();
  v_client uuid;
  v_pro uuid;
  v_conv uuid;
begin
  if v_uid is null or not public.is_active_user() then
    raise exception 'not_authenticated' using errcode = '28000';
  end if;

  if p_request is not null then
    select client_id, professional_id into v_client, v_pro from public.service_requests where id = p_request;
    if not found or v_uid not in (v_client, v_pro) then raise exception 'forbidden' using errcode = '42501'; end if;
    select id into v_conv from public.conversations where request_id = p_request;
  else
    if p_professional is null or p_professional = v_uid then raise exception 'invalid_target' using errcode = 'P0001'; end if;
    if not public.is_public_pro(p_professional) then raise exception 'pro_not_available' using errcode = 'P0001'; end if;
    v_client := v_uid; v_pro := p_professional;
    select id into v_conv from public.conversations
     where client_id = v_client and professional_id = v_pro and request_id is null;
  end if;

  if public.is_blocked_between(v_client, v_pro) then raise exception 'blocked' using errcode = '42501'; end if;

  if v_conv is null then
    perform public.enforce_rate_limit('new_conversations', 30, interval '1 day');
    insert into public.conversations (request_id, client_id, professional_id, created_by)
    values (p_request, v_client, v_pro, v_uid)
    returning id into v_conv;
    insert into public.conversation_members (conversation_id, user_id, member_role) values
      (v_conv, v_client, 'client'), (v_conv, v_pro, 'professional');
  end if;
  return v_conv;
end $$;

create or replace function public.mark_conversation_read(p_conv uuid)
returns void language sql security definer set search_path = '' as $$
  update public.conversation_members set last_read_at = now()
   where conversation_id = p_conv and user_id = auth.uid()
$$;

-- Liste des conversations de l'utilisateur, prête pour l'écran « Messages ».
create or replace function public.list_my_conversations(p_limit int default 30, p_before timestamptz default null)
returns table (conversation_id uuid, request_id uuid, other_user_id uuid, other_name text, other_avatar text,
               other_is_pro boolean, last_message_at timestamptz, last_message_preview text,
               unread_count int, other_last_read_at timestamptz, archived boolean)
language sql stable security definer set search_path = '' as $$
  select c.id, c.request_id, o.user_id,
         coalesce(nullif(pp.display_name, ''), p.full_name, 'Utilisateur'),
         coalesce(pp.logo_path, p.avatar_path),
         o.member_role = 'professional',
         c.last_message_at, c.last_message_preview,
         (select count(*)::int from public.messages m
           where m.conversation_id = c.id and m.sender_id <> auth.uid()
             and m.created_at > coalesce(me.last_read_at, '-infinity'::timestamptz)),
         o.last_read_at, me.archived
    from public.conversation_members me
    join public.conversations c on c.id = me.conversation_id
    join public.conversation_members o on o.conversation_id = c.id and o.user_id <> me.user_id
    join public.profiles p on p.id = o.user_id
    left join public.professional_profiles pp on pp.user_id = o.user_id and o.member_role = 'professional'
   where me.user_id = auth.uid()
     and (p_before is null or coalesce(c.last_message_at, c.created_at) < p_before)
   order by coalesce(c.last_message_at, c.created_at) desc
   limit least(greatest(p_limit, 1), 100)
$$;

create or replace function public.get_unread_counts()
returns table (messages int, notifications int)
language sql stable security definer set search_path = '' as $$
  select
    (select count(*)::int from public.messages m
       join public.conversation_members me on me.conversation_id = m.conversation_id and me.user_id = auth.uid()
      where m.sender_id <> auth.uid() and m.created_at > coalesce(me.last_read_at, '-infinity'::timestamptz)),
    (select count(*)::int from public.notifications where user_id = auth.uid() and read_at is null)
$$;

-- ═════════════ Signalements ═════════════

-- Les messages joints sont copiés dans report_evidence : le modérateur ne voit que ce qui est signalé.
create or replace function public.report_content(p_target_type public.report_target, p_target_id uuid,
                                                 p_reason text, p_description text default null,
                                                 p_message_ids uuid[] default '{}')
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  v_report uuid;
  v_bad int;
begin
  if auth.uid() is null or not public.is_active_user() then
    raise exception 'not_authenticated' using errcode = '28000';
  end if;
  if coalesce(array_length(p_message_ids, 1), 0) > 20 then
    raise exception 'too_many_messages' using errcode = 'P0001';
  end if;
  select count(*) into v_bad from unnest(coalesce(p_message_ids, '{}')) mid
   where not exists (select 1 from public.messages m
                      join public.conversation_members cm
                        on cm.conversation_id = m.conversation_id and cm.user_id = auth.uid()
                     where m.id = mid);
  if v_bad > 0 then raise exception 'forbidden' using errcode = '42501'; end if;

  insert into public.reports (reporter_id, target_type, target_id, reason, description)
  values (auth.uid(), p_target_type, p_target_id, p_reason, p_description)
  returning id into v_report;

  insert into public.report_evidence (report_id, message_id, sender_id, body, message_type, sent_at)
  select v_report, m.id, m.sender_id, m.body, m.type, m.created_at
    from public.messages m where m.id = any(coalesce(p_message_ids, '{}'));
  return v_report;
end $$;

-- ═════════════ Recherche et recommandation ═════════════

create or replace function public.haversine_km(lat1 double precision, lng1 double precision,
                                               lat2 double precision, lng2 double precision)
returns double precision language sql immutable parallel safe set search_path = '' as $$
  select case when lat1 is null or lat2 is null then null else
    2 * 6371 * asin(sqrt(power(sin(radians(lat2 - lat1) / 2), 2)
      + cos(radians(lat1)) * cos(radians(lat2)) * power(sin(radians(lng2 - lng1) / 2), 2))) end
$$;

-- Le pro intervient-il dans la zone choisie (zone de base ou zones d'intervention,
-- en tenant compte de la hiérarchie pays > ville > commune > quartier) ?
create or replace function public.pro_serves_location(p_pro uuid, p_location uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1
      from public.locations sel,
           (select pp.location_id as loc from public.professional_profiles pp where pp.user_id = p_pro
            union
            select sa.location_id from public.service_areas sa where sa.professional_id = p_pro) a
      join public.locations l on l.id = a.loc
     where sel.id = p_location
       and (l.path like sel.path || '%' or sel.path like l.path || '%'))
$$;

create type public.pro_card as (
  professional_id uuid,
  display_name text,
  slug text,
  headline text,
  logo_path text,
  location_name text,
  availability public.availability_status,
  rating_avg numeric,
  rating_count int,
  identity_verified boolean,
  company_verified boolean,
  phone_verified boolean,
  distance_km double precision,
  score double precision,
  reasons text[]
);

create or replace function public.search_professionals(
  p_query text default null,
  p_category uuid default null,
  p_location uuid default null,
  p_lat double precision default null,
  p_lng double precision default null,
  p_radius_km int default null,
  p_available_only boolean default false,
  p_min_rating numeric default null,
  p_verified_only boolean default false,
  p_min_experience int default null,
  p_sort text default 'relevance',
  p_limit int default 20,
  p_offset int default 0)
returns setof public.pro_card
language plpgsql stable security definer set search_path = '' as $$
declare
  q text := nullif(btrim(public.f_norm(p_query)), '');
  words text[];
  r numeric := least(coalesce(p_radius_km, 0), 200);
begin
  if q is not null then
    select coalesce(array_agg(w), '{}') into words
      from unnest(regexp_split_to_array(q, '\s+')) w
     where char_length(w) >= 3 and w not in ('les', 'des', 'une', 'pour', 'dans', 'avec', 'sur');
    if array_length(words, 1) is null then words := array[q]; end if;
  end if;

  return query
  with base as (
    select pp.*, l.name as loc_name, pr.phone_verified as phone_ok,
           public.haversine_km(p_lat, p_lng, pp.lat, pp.lng) as dist,
           case when q is null then 0
                else (select avg(extensions.word_similarity(w, pp.search_document)) from unnest(words) w) end as txt
      from public.professional_profiles pp
      join public.profiles pr on pr.id = pp.user_id and pr.status = 'active'
      left join public.locations l on l.id = pp.location_id
     where pp.is_published
       -- Texte : chaque mot doit correspondre (tolérance aux fautes via trigrammes, accents ignorés)
       and (q is null or not exists (
             select 1 from unnest(words) w
              where not (pp.search_document like '%' || w || '%'
                         or extensions.word_similarity(w, pp.search_document) >= 0.5)))
       and (p_category is null or exists (
             select 1 from public.professional_categories pc
               join public.categories c on c.id = pc.category_id
              where pc.professional_id = pp.user_id and (c.id = p_category or c.parent_id = p_category)))
       and (p_location is null or public.pro_serves_location(pp.user_id, p_location))
       and (not coalesce(p_available_only, false) or pp.availability = 'available')
       and (p_min_rating is null or pp.rating_avg >= p_min_rating)
       and (not coalesce(p_verified_only, false) or pp.identity_verified or pp.company_verified)
       and (p_min_experience is null or coalesce(pp.experience_years, 0) >= p_min_experience)
       -- Rayon : préfiltre par boîte englobante, puis distance exacte
       and (r = 0 or p_lat is null or (
             pp.lat between p_lat - r / 111.0 and p_lat + r / 111.0
             and pp.lng between p_lng - r / (111.0 * greatest(cos(radians(p_lat)), 0.01))
                            and p_lng + r / (111.0 * greatest(cos(radians(p_lat)), 0.01))
             and public.haversine_km(p_lat, p_lng, pp.lat, pp.lng) <= r))
  ), scored as (
    select b.*,
      (b.rating_avg * b.rating_count + 3.5 * 3) / (b.rating_count + 3) / 5.0 as bayes,
      case when b.availability = 'available' and b.availability_updated_at > now() - interval '7 days' then 1.0
           when b.availability = 'by_appointment' then 0.6
           when b.availability = 'busy' then 0.3 else 0.0 end as avail,
      case when b.dist is null then 0.5 else 1.0 / (1.0 + b.dist / 5.0) end as near
    from base b
  )
  select s.user_id, s.display_name, s.slug, s.headline, s.logo_path, s.loc_name, s.availability,
         s.rating_avg, s.rating_count, s.identity_verified, s.company_verified, s.phone_ok,
         round(s.dist::numeric, 1)::double precision,
         (0.40 * s.txt + 0.20 * s.bayes + 0.15 * s.avail + 0.15 * s.near
          + 0.10 * ((s.logo_path is not null)::int + (char_length(s.description) > 80)::int) / 2.0)::double precision,
         array_remove(array[
           case when q is not null then 'Correspond à votre recherche' end,
           case when p_location is not null then 'Intervient dans votre zone' end,
           case when s.dist is not null then 'À ' || round(s.dist::numeric, 1) || ' km' end,
           case when s.avail = 1.0 then 'Disponible' end
         ], null)
    from scored s
   order by
     case when p_sort = 'distance' then s.dist end asc nulls last,
     case when p_sort = 'rating' then s.bayes end desc,
     case when p_sort not in ('distance', 'rating') or p_sort is null then
       0.40 * s.txt + 0.20 * s.bayes + 0.15 * s.avail + 0.15 * s.near end desc,
     s.user_id
   limit least(greatest(coalesce(p_limit, 20), 1), 50)
   offset greatest(coalesce(p_offset, 0), 0);
end $$;

-- Recommandations explicables, moteur déterministe "rules-v1".
-- Le service IA externe (fonction Edge "recommend") peut le remplacer ; ce RPC reste le secours.
create or replace function public.recommend_professionals(
  p_location uuid default null,
  p_lat double precision default null,
  p_lng double precision default null,
  p_radius_km int default 25,
  p_limit int default 10)
returns setof public.pro_card
language plpgsql stable security definer set search_path = '' as $$
declare
  v_uid uuid := auth.uid();
  v_personal boolean := false;
  v_cats uuid[] := '{}';
begin
  if v_uid is not null then
    select coalesce(personalization_enabled, false) into v_personal
      from public.user_preferences where user_id = v_uid;
  end if;
  if v_personal then
    select coalesce(array_agg(distinct pc.category_id), '{}') into v_cats
      from public.professional_categories pc
     where pc.professional_id in (
       select professional_id from public.favorites where client_id = v_uid
       union select professional_id from public.service_requests where client_id = v_uid);
  end if;

  return query
  with base as (
    select pp.*, l.name as loc_name, pr.phone_verified as phone_ok,
           public.haversine_km(p_lat, p_lng, pp.lat, pp.lng) as dist,
           (p_location is not null and public.pro_serves_location(pp.user_id, p_location)) as in_zone,
           exists (select 1 from public.professional_categories pc
                    where pc.professional_id = pp.user_id and pc.category_id = any(v_cats)) as affinity,
           (select pc.category_id from public.professional_categories pc
             where pc.professional_id = pp.user_id order by pc.is_primary desc limit 1) as main_cat
      from public.professional_profiles pp
      join public.profiles pr on pr.id = pp.user_id and pr.status = 'active'
      left join public.locations l on l.id = pp.location_id
     where pp.is_published
       and pp.user_id is distinct from v_uid
       and pp.availability <> 'unavailable'
       and (v_uid is null or not public.is_blocked_between(v_uid, pp.user_id))
  ), scored as (
    select b.*,
      (b.rating_avg * b.rating_count + 3.5 * 3) / (b.rating_count + 3) / 5.0 as bayes,
      (b.availability = 'available' and b.availability_updated_at > now() - interval '7 days') as avail_fresh,
      case when b.in_zone then 1.0
           when b.dist is not null and b.dist <= coalesce(p_radius_km, 25) then 1.0 / (1.0 + b.dist / 5.0)
           else 0.0 end as zone_score
    from base b
    where p_location is null or b.in_zone
       or (b.dist is not null and b.dist <= coalesce(p_radius_km, 25))
  ), ranked as (
    select s.*,
      (0.30 * s.zone_score + 0.25 * s.bayes + 0.15 * s.avail_fresh::int + 0.15 * s.affinity::int
       + 0.15 * (case when s.updated_at > now() - interval '30 days' then 1 else 0.5 end)
         * ((s.logo_path is not null)::int + (char_length(s.description) > 80)::int + 1) / 3.0) as sc,
      row_number() over (partition by s.main_cat order by s.bayes desc, s.user_id) as rank_in_cat
    from scored s
  )
  select r.user_id, r.display_name, r.slug, r.headline, r.logo_path, r.loc_name, r.availability,
         r.rating_avg, r.rating_count, r.identity_verified, r.company_verified, r.phone_ok,
         round(r.dist::numeric, 1)::double precision, r.sc::double precision,
         array_remove(array[
           case when r.in_zone then 'Intervient dans votre zone'
                when r.dist is not null then 'À ' || round(r.dist::numeric, 1) || ' km' end,
           case when r.avail_fresh then 'Disponible maintenant' end,
           case when r.affinity then 'Proche de vos centres d''intérêt' end,
           case when r.rating_count >= 3 and r.rating_avg >= 4.5 then 'Très bien noté' end,
           case when r.identity_verified or r.company_verified then 'Profil vérifié' end
         ], null)
    from ranked r
   where r.rank_in_cat <= 3 -- diversité : 3 pros max par catégorie
   order by r.sc desc, r.user_id
   limit least(greatest(coalesce(p_limit, 10), 1), 30);
end $$;

-- Journal des interactions avec les recommandations (pseudonymisé, minimal, avec consentement).
create or replace function public.log_recommendation_event(p_pro uuid, p_action public.reco_action,
                                                           p_position int default null, p_context jsonb default '{}')
returns void language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null then return; end if;
  if not coalesce((select personalization_enabled from public.user_preferences where user_id = auth.uid()), false) then
    return;
  end if;
  perform public.enforce_rate_limit('reco_events', 300, interval '1 hour');
  insert into public.recommendation_events (user_hash, professional_id, action, position, context)
  values (encode(extensions.digest(auth.uid()::text || coalesce(current_setting('app.reco_salt', true), 'ballal'), 'sha256'), 'hex'),
          p_pro, p_action, p_position,
          jsonb_strip_nulls(jsonb_build_object('category', p_context ->> 'category',
                                               'radius_km', p_context ->> 'radius_km',
                                               'engine', p_context ->> 'engine')));
end $$;

-- ═════════════ Administration ═════════════

create or replace function public.admin_set_user_status(p_user uuid, p_status public.account_status, p_reason text)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if not public.is_staff() then raise exception 'forbidden' using errcode = '42501'; end if;
  if p_user = auth.uid() then raise exception 'cannot_moderate_self' using errcode = 'P0001'; end if;
  if exists (select 1 from public.user_roles where user_id = p_user and role in ('admin', 'super_admin'))
     and not public.has_role('super_admin') then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  if coalesce(btrim(p_reason), '') = '' then raise exception 'reason_required' using errcode = 'P0001'; end if;
  update public.profiles set status = p_status where id = p_user;
  if p_status <> 'active' then
    update public.professional_profiles set is_published = false where user_id = p_user;
  end if;
  perform public.log_audit('user.set_status', 'user', p_user, jsonb_build_object('status', p_status, 'reason', p_reason));
  perform public.notify(p_user, 'account', 'Statut du compte modifié', p_reason, 'user', p_user);
end $$;

create or replace function public.admin_review_verification(p_doc uuid, p_status public.doc_status, p_reason text default null)
returns void language plpgsql security definer set search_path = '' as $$
declare d public.verification_documents;
begin
  if not public.is_admin() then raise exception 'forbidden' using errcode = '42501'; end if;
  update public.verification_documents
     set status = p_status, reviewed_by = auth.uid(), reviewed_at = now(),
         rejection_reason = case when p_status = 'rejected' then p_reason end
   where id = p_doc returning * into d;
  if not found then raise exception 'not_found' using errcode = 'P0002'; end if;
  if d.doc_type = 'identity' then
    update public.professional_profiles set identity_verified = (p_status = 'approved') where user_id = d.user_id;
  else
    update public.professional_profiles set company_verified = (p_status = 'approved') where user_id = d.user_id;
  end if;
  perform public.log_audit('verification.review', 'verification_document', p_doc,
                           jsonb_build_object('status', p_status, 'type', d.doc_type));
  perform public.notify(d.user_id, 'account',
    case when p_status = 'approved' then 'Vérification acceptée' else 'Vérification refusée' end,
    p_reason, 'verification_document', p_doc);
end $$;

create or replace function public.admin_moderate_review(p_review uuid, p_status public.review_status, p_note text)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if not public.is_staff() then raise exception 'forbidden' using errcode = '42501'; end if;
  update public.reviews set status = p_status, moderation_note = p_note where id = p_review;
  if not found then raise exception 'not_found' using errcode = 'P0002'; end if;
  perform public.log_audit('review.moderate', 'review', p_review, jsonb_build_object('status', p_status, 'note', p_note));
end $$;

create or replace function public.admin_resolve_report(p_report uuid, p_status public.report_status, p_resolution text)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if not public.is_staff() then raise exception 'forbidden' using errcode = '42501'; end if;
  update public.reports set status = p_status, resolution = p_resolution, handled_by = auth.uid() where id = p_report;
  if not found then raise exception 'not_found' using errcode = 'P0002'; end if;
  perform public.log_audit('report.resolve', 'report', p_report, jsonb_build_object('status', p_status));
end $$;

create or replace function public.grant_staff_role(p_user uuid, p_role public.app_role)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if not public.has_role('super_admin') then raise exception 'forbidden' using errcode = '42501'; end if;
  if p_role not in ('moderator', 'admin', 'super_admin') then raise exception 'invalid_role' using errcode = 'P0001'; end if;
  insert into public.user_roles (user_id, role) values (p_user, p_role) on conflict do nothing;
  perform public.log_audit('role.grant', 'user', p_user, jsonb_build_object('role', p_role));
end $$;

create or replace function public.revoke_staff_role(p_user uuid, p_role public.app_role)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if not public.has_role('super_admin') then raise exception 'forbidden' using errcode = '42501'; end if;
  if p_role not in ('moderator', 'admin', 'super_admin') then raise exception 'invalid_role' using errcode = 'P0001'; end if;
  if p_user = auth.uid() and p_role = 'super_admin' then raise exception 'cannot_revoke_self' using errcode = 'P0001'; end if;
  delete from public.user_roles where user_id = p_user and role = p_role;
  perform public.log_audit('role.revoke', 'user', p_user, jsonb_build_object('role', p_role));
end $$;

-- Fonctions internes : pas d'appel direct depuis les applications.
revoke execute on function public.notify(uuid, text, text, text, text, uuid) from public, anon, authenticated;
revoke execute on function public.log_audit(text, text, uuid, jsonb) from public, anon, authenticated;
revoke execute on function public.enforce_rate_limit(text, int, interval) from public, anon, authenticated;
revoke execute on function public.refresh_pro_rating(uuid) from public, anon, authenticated;

-- ═══════ migrations/20261121000006_storage.sql ═══════
-- BALLAL — 0006 : stockage des fichiers (buckets publics et privés séparés)
-- Convention de chemins :
--   avatars/{user_id}/…               public
--   pro-media/{user_id}/…             public (logo, couverture, portfolio, services)
--   request-attachments/{request_id}/… privé (client + pro de la demande)
--   message-attachments/{conversation_id}/… privé (membres de la conversation)
--   verification-docs/{user_id}/…     privé (propriétaire + administrateurs)

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types) values
  ('avatars', 'avatars', true, 2097152, array['image/jpeg', 'image/png', 'image/webp']),
  ('pro-media', 'pro-media', true, 5242880, array['image/jpeg', 'image/png', 'image/webp', 'video/mp4']),
  ('request-attachments', 'request-attachments', false, 5242880, array['image/jpeg', 'image/png', 'image/webp']),
  ('message-attachments', 'message-attachments', false, 10485760,
     array['image/jpeg', 'image/png', 'image/webp', 'audio/aac', 'audio/mp4', 'audio/m4a', 'audio/mpeg', 'audio/ogg']),
  ('verification-docs', 'verification-docs', false, 5242880, array['image/jpeg', 'image/png', 'application/pdf'])
on conflict (id) do nothing;

-- Lecture des buckets publics
create policy "public read" on storage.objects for select
  using (bucket_id in ('avatars', 'pro-media'));

-- Écriture dans son propre dossier (buckets publics)
create policy "own folder write" on storage.objects for insert to authenticated
  with check (bucket_id in ('avatars', 'pro-media') and (storage.foldername(name))[1] = auth.uid()::text);
create policy "own folder update" on storage.objects for update to authenticated
  using (bucket_id in ('avatars', 'pro-media') and (storage.foldername(name))[1] = auth.uid()::text);
create policy "own folder delete" on storage.objects for delete to authenticated
  using (bucket_id in ('avatars', 'pro-media') and (storage.foldername(name))[1] = auth.uid()::text);

-- Pièces jointes de demande
create policy "request attachments read" on storage.objects for select to authenticated
  using (bucket_id = 'request-attachments' and exists (
    select 1 from public.service_requests r
     where r.id::text = (storage.foldername(name))[1]
       and (r.client_id = auth.uid() or r.professional_id = auth.uid())));
create policy "request attachments write" on storage.objects for insert to authenticated
  with check (bucket_id = 'request-attachments' and exists (
    select 1 from public.service_requests r
     where r.id::text = (storage.foldername(name))[1] and r.client_id = auth.uid() and r.status = 'pending'));

-- Pièces jointes de messagerie
create policy "message attachments read" on storage.objects for select to authenticated
  using (bucket_id = 'message-attachments'
         and public.is_conversation_member(((storage.foldername(name))[1])::uuid));
create policy "message attachments write" on storage.objects for insert to authenticated
  with check (bucket_id = 'message-attachments'
              and public.can_send_message(((storage.foldername(name))[1])::uuid));

-- Justificatifs (jamais publics)
create policy "verification read" on storage.objects for select to authenticated
  using (bucket_id = 'verification-docs'
         and ((storage.foldername(name))[1] = auth.uid()::text or public.is_admin()));
create policy "verification write" on storage.objects for insert to authenticated
  with check (bucket_id = 'verification-docs' and (storage.foldername(name))[1] = auth.uid()::text);

-- ═══════ migrations/20261121000007_realtime.sql ═══════
-- BALLAL — 0007 : temps réel (messagerie, notifications, accusés de lecture)
-- Supabase Realtime respecte les politiques RLS pour postgres_changes.
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    alter publication supabase_realtime add table public.messages, public.notifications, public.conversation_members;
  end if;
end $$;

-- ═══════ migrations/20261121000008_pro_stats.sql ═══════
-- BALLAL — 0008 : statistiques du tableau de bord pro (données réelles uniquement)
create or replace function public.count_my_followers()
returns int language sql stable security definer set search_path = '' as $$
  select count(*)::int from public.favorites where professional_id = auth.uid()
$$;

-- ═══════ migrations/20261122000009_tighten_execute.sql ═══════
-- BALLAL — 0009 : réduit qui peut appeler quoi (alertes du conseiller sécurité Supabase)

-- Fonctions de déclencheur : jamais appelables via l'API.
revoke execute on function
  public.handle_new_user(), public.handle_user_phone_confirmed(),
  public.message_before_insert(), public.message_after_insert(),
  public.pro_before_write(), public.pro_refresh_from_child(),
  public.report_before_insert(), public.request_before_insert(), public.request_after_write(),
  public.review_after_write(), public.review_reply_after_insert()
from public, anon, authenticated;

-- Fonctions réservées aux utilisateurs connectés (elles vérifient aussi auth.uid() en interne).
revoke execute on function
  public.activate_role(public.app_role),
  public.admin_moderate_review(uuid, public.review_status, text),
  public.admin_resolve_report(uuid, public.report_status, text),
  public.admin_review_verification(uuid, public.doc_status, text),
  public.admin_set_user_status(uuid, public.account_status, text),
  public.grant_staff_role(uuid, public.app_role),
  public.revoke_staff_role(uuid, public.app_role),
  public.count_my_followers(), public.delete_my_account(),
  public.get_professional_contact(uuid), public.get_unread_counts(),
  public.list_my_conversations(int, timestamptz), public.log_recommendation_event(uuid, public.reco_action, int, jsonb),
  public.mark_conversation_read(uuid), public.record_profile_view(uuid),
  public.report_content(public.report_target, uuid, text, text, uuid[]),
  public.start_conversation(uuid, uuid),
  public.update_request_status(uuid, public.request_status, text),
  public.can_send_message(uuid), public.is_conversation_member(uuid), public.is_blocked_between(uuid, uuid),
  public.has_role(public.app_role), public.is_active_user(), public.is_user_active(uuid)
from public, anon;

grant execute on function
  public.activate_role(public.app_role),
  public.admin_moderate_review(uuid, public.review_status, text),
  public.admin_resolve_report(uuid, public.report_status, text),
  public.admin_review_verification(uuid, public.doc_status, text),
  public.admin_set_user_status(uuid, public.account_status, text),
  public.grant_staff_role(uuid, public.app_role),
  public.revoke_staff_role(uuid, public.app_role),
  public.count_my_followers(), public.delete_my_account(),
  public.get_professional_contact(uuid), public.get_unread_counts(),
  public.list_my_conversations(int, timestamptz), public.log_recommendation_event(uuid, public.reco_action, int, jsonb),
  public.mark_conversation_read(uuid), public.record_profile_view(uuid),
  public.report_content(public.report_target, uuid, text, text, uuid[]),
  public.start_conversation(uuid, uuid),
  public.update_request_status(uuid, public.request_status, text),
  public.can_send_message(uuid), public.is_conversation_member(uuid), public.is_blocked_between(uuid, uuid),
  public.has_role(public.app_role), public.is_active_user(), public.is_user_active(uuid)
to authenticated;

-- Restent publics volontairement (visiteurs sans compte) : search_professionals, recommend_professionals,
-- et les helpers utilisés par les politiques de lecture publiques : is_public_pro, can_view_profile,
-- is_staff, is_admin, pro_serves_location, f_norm, haversine_km.

-- ═══════ migrations/20261123000010_communes_free_entry.sql ═══════
-- BALLAL — 0010 : 13 communes de Conakry, quartiers officiels, ajout manuel de quartier,
-- publication sans blocage.
-- Sources : redécoupage du Ministère de l'Administration du Territoire (avril 2024, via Guinéenews)
-- et annuaire statistique INS (Dixinn, Kaloum, Matam). Coordonnées = centres approximatifs.

alter table public.locations add column if not exists user_added boolean not null default false;
alter table public.locations add column if not exists created_by uuid references public.profiles(id) on delete set null;

-- ───────────── Remplacement des communes de Conakry ─────────────
-- Fonction réutilisée par seed.sql (installation neuve) et appliquée ici aux bases existantes.
create or replace function public.seed_conakry_communes()
returns void language plpgsql security definer set search_path = '' as $$
declare
  v_city uuid;
begin
  select c.id into v_city
    from public.locations c join public.locations r on r.id = c.parent_id
   where c.level = 'city' and c.slug = 'conakry' and r.slug = 'conakry';
  if v_city is null then return; end if;

  -- Détache ce qui pointe encore vers les anciennes zones (aucune donnée attendue à ce stade).
  update public.professional_profiles set location_id = null
   where location_id in (select id from public.locations where path like (select path from public.locations where id = v_city) || '_%');
  delete from public.service_areas
   where location_id in (select id from public.locations where path like (select path from public.locations where id = v_city) || '_%');
  update public.service_requests set location_id = null
   where location_id in (select id from public.locations where path like (select path from public.locations where id = v_city) || '_%');
  update public.client_profiles set favorite_location_id = null
   where favorite_location_id in (select id from public.locations where path like (select path from public.locations where id = v_city) || '_%');
  delete from public.locations where level = 'quartier'
     and parent_id in (select id from public.locations where parent_id = v_city);
  delete from public.locations where parent_id = v_city;

  insert into public.locations (parent_id, level, name, slug, lat, lng)
  select v_city, 'commune', v.name, v.slug, v.lat, v.lng from (values
    ('Kaloum', 'kaloum', 9.5092, -13.7122), ('Kassa', 'kassa', 9.4700, -13.7500),
    ('Dixinn', 'dixinn', 9.5450, -13.6720), ('Matam', 'matam', 9.5560, -13.6450),
    ('Ratoma', 'ratoma', 9.6000, -13.6500), ('Lambanyi', 'lambanyi', 9.6600, -13.6000),
    ('Sonfonia', 'sonfonia', 9.6800, -13.5600), ('Matoto', 'matoto', 9.5950, -13.6000),
    ('Gbessia', 'gbessia', 9.5800, -13.6200), ('Tombolia', 'tombolia', 9.6100, -13.5500),
    ('Kagbélen', 'kagbelen', 9.7200, -13.4700), ('Manéah', 'maneah', 9.7300, -13.4000),
    ('Sanoyah', 'sanoyah', 9.7000, -13.4400)
  ) as v(name, slug, lat, lng);

  insert into public.locations (parent_id, level, name, slug, lat, lng)
  select cm.id, 'quartier', q.name,
         trim(both '-' from regexp_replace(public.f_norm(q.name), '[^a-z0-9]+', '-', 'g')),
         cm.lat, cm.lng
    from (values
      ('kaloum','Almamya I'),('kaloum','Almamya II'),('kaloum','Boulbinet'),('kaloum','Coronthie I'),
      ('kaloum','Coronthie II'),('kaloum','Koulewondy'),('kaloum','Manquepas'),('kaloum','Sandervalia'),
      ('kaloum','Sans Fil'),('kaloum','Tamara'),('kaloum','Téminetaye'),('kaloum','Tombo'),
      ('dixinn','Belle Vue École'),('dixinn','Belle Vue Marché I'),('dixinn','Belle Vue Marché II'),
      ('dixinn','Camayenne'),('dixinn','Cameroun'),('dixinn','Dixinn Centre I'),('dixinn','Dixinn Centre II'),
      ('dixinn','Dixinn Gare'),('dixinn','Dixinn Gare Rails'),('dixinn','Dixinn Mosquée'),('dixinn','Dixinn Port'),
      ('dixinn','Hafia Château d''eau'),('dixinn','Hafia I'),('dixinn','Hafia II'),('dixinn','Hafia III'),
      ('dixinn','Hafia Minière I'),('dixinn','Hafia Minière II'),('dixinn','Hafia Minière Centre'),
      ('dixinn','Hafia Mosquée Kénien'),('dixinn','Landréah'),('dixinn','Minière Cité'),
      ('matam','Bonfi'),('matam','Bonfi Marché'),('matam','Bonfi Routière'),('matam','Boussoura'),
      ('matam','Carrière Centre'),('matam','Carrière Cité'),('matam','Coléah Centre'),('matam','Coléah Cité'),
      ('matam','Coléah Domino'),('matam','Coléah Imprimerie'),('matam','Hermakonon Mosquée'),
      ('matam','Hermakonon Permanence'),('matam','Lanseboundji'),('matam','Madina Centre'),
      ('matam','Madina Cité'),('matam','Madina Marché'),('matam','Madina Mosquée'),('matam','Madina École'),
      ('matam','Mafanco'),('matam','Mafanco Centre'),('matam','Matam'),('matam','Matam Centre'),
      ('matam','Matam Lido'),('matam','Touguiwondy'),
      ('ratoma','Taouyah'),('ratoma','Ratoma Dispensaire'),('ratoma','Ratoma Centre'),('ratoma','Kaporo Rails'),
      ('ratoma','Hamdallaye 1'),('ratoma','Hamdallaye 2'),('ratoma','Koloma Soloprimo'),('ratoma','Kipé'),
      ('ratoma','Kaporo Centre'),
      ('lambanyi','Nongo Centre'),('lambanyi','Nongo Taady'),('lambanyi','Lambanyi'),('lambanyi','Yembeya'),
      ('lambanyi','Waréah'),('lambanyi','Simbaya Gare'),('lambanyi','Yattaya Centre'),('lambanyi','Nassouroulaye'),
      ('lambanyi','Bantounka 1'),('lambanyi','Bantounka 2'),('lambanyi','Soumambossia'),('lambanyi','Wanindara'),
      ('lambanyi','Wanindara Rails'),('lambanyi','Kinifi'),
      ('sonfonia','Kobayah'),('sonfonia','Yattaya Fossidet'),('sonfonia','Yattaya Centre'),
      ('sonfonia','Sonfonia Gare 1'),('sonfonia','Sonfonia Gare 2'),('sonfonia','Sonfonia Centre 1'),
      ('sonfonia','Sonfonia Centre 2'),
      ('gbessia','Dabondy 1'),('gbessia','Dabondy 2'),('gbessia','Dabondy 3'),('gbessia','Dabondy École'),
      ('gbessia','Dabondy Rails'),('gbessia','Gbessia Cité 1'),('gbessia','Gbessia Cité 2'),('gbessia','Gbessia Cité 3'),
      ('gbessia','Gbessia École'),('gbessia','Gbessia Centre'),('gbessia','Gbessia Port 1'),('gbessia','Gbessia Port 2'),
      ('gbessia','Dar-Es-Salam'),('gbessia','Cité de l''air'),('gbessia','Béhanzin'),('gbessia','Tanènè Marché'),
      ('gbessia','Tanènè Mosquée'),('gbessia','Yimbaya École'),('gbessia','Yimbaya Permanence'),
      ('gbessia','Yimbaya Port'),('gbessia','Hamdallaye Mosquée'),('gbessia','Yimbaya Tannerie'),
      ('gbessia','Simbaya 1'),('gbessia','Koloma 1'),('gbessia','Koloma 2'),('gbessia','Nassouroulaye'),
      ('matoto','Matoto Centre'),('matoto','Simbaya 2'),('matoto','Simbaya École'),('matoto','Matoto Marché'),
      ('matoto','Matoto Khabitaya'),('matoto','Sangoyah Mosquée'),('matoto','Sangoyah Marché'),('matoto','Kissosso'),
      ('matoto','Kissosso Plateau'),('matoto','Marché Enco 5'),('matoto','Wanindara Dispensaire'),
      ('matoto','Wanindara Marché'),
      ('tombolia','Enta Marché'),('tombolia','Enta Fassa'),('tombolia','Tombolia'),('tombolia','Tombolia Plateau'),
      ('tombolia','Dabompa Village'),('tombolia','Dabompa Plateau'),('tombolia','Lansanayah')
    ) as q(commune, name)
    join public.locations cm on cm.parent_id = v_city and cm.slug = q.commune
  on conflict (parent_id, slug) do nothing;
end $$;
revoke execute on function public.seed_conakry_communes() from public, anon, authenticated;

select public.seed_conakry_communes();

-- ───────────── Ajout manuel d'un quartier par un utilisateur ─────────────
-- Si le quartier existe déjà (même nom, accents ignorés), on renvoie l'existant.
create or replace function public.add_location(p_parent uuid, p_name text)
returns public.locations
language plpgsql security definer set search_path = '' as $$
declare
  v_parent public.locations;
  v_name text := left(btrim(regexp_replace(coalesce(p_name, ''), '\s+', ' ', 'g')), 80);
  v_slug text;
  v_loc public.locations;
begin
  if auth.uid() is null or not public.is_active_user() then
    raise exception 'not_authenticated' using errcode = '28000';
  end if;
  if char_length(v_name) < 2 then raise exception 'name_too_short' using errcode = 'P0001'; end if;
  select * into v_parent from public.locations where id = p_parent and is_active;
  if not found or v_parent.level not in ('city', 'commune', 'prefecture') then
    raise exception 'invalid_parent' using errcode = 'P0001';
  end if;
  v_slug := trim(both '-' from regexp_replace(public.f_norm(v_name), '[^a-z0-9]+', '-', 'g'));
  select * into v_loc from public.locations where parent_id = p_parent and slug = v_slug;
  if found then return v_loc; end if;

  perform public.enforce_rate_limit('add_location', 10, interval '1 day');
  insert into public.locations (parent_id, level, name, slug, lat, lng, user_added, created_by)
  values (p_parent, case when v_parent.level = 'city' then 'commune'::public.location_level else 'quartier'::public.location_level end,
          v_name, v_slug, v_parent.lat, v_parent.lng, true, auth.uid())
  returning * into v_loc;
  perform public.log_audit('location.user_added', 'location', v_loc.id, jsonb_build_object('name', v_name));
  return v_loc;
end $$;
revoke execute on function public.add_location(uuid, text) from public, anon;
grant execute on function public.add_location(uuid, text) to authenticated;

-- ───────────── Publication sans blocage ─────────────
-- Seul le nom affiché est obligatoire. Si le métier principal est vide, on reprend le premier métier choisi.
create or replace function public.pro_before_write()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  v_loc record;
  v_cats text;
  v_first_cat text;
  v_services text;
begin
  if new.slug is null and char_length(btrim(new.display_name)) > 0 then
    new.slug := trim(both '-' from regexp_replace(public.f_norm(new.display_name), '[^a-z0-9]+', '-', 'g'))
                || '-' || left(new.user_id::text, 6);
  end if;

  if new.location_id is not null
     and (tg_op = 'INSERT' or new.location_id is distinct from old.location_id or new.lat is null) then
    select name, lat, lng into v_loc from public.locations where id = new.location_id;
    if new.lat is null or (tg_op = 'UPDATE' and new.location_id is distinct from old.location_id
                           and new.lat is not distinct from old.lat) then
      new.lat := v_loc.lat;
      new.lng := v_loc.lng;
    end if;
  end if;

  if tg_op = 'UPDATE' and new.availability is distinct from old.availability then
    new.availability_updated_at := now();
  end if;

  select string_agg(c.name, ' '),
         (array_agg(c.name order by pc.is_primary desc, c.name))[1]
    into v_cats, v_first_cat
    from public.professional_categories pc
    join public.categories c on c.id = pc.category_id
   where pc.professional_id = new.user_id;

  if char_length(btrim(new.headline)) = 0 and v_first_cat is not null then
    new.headline := v_first_cat;
  end if;

  if new.is_published and (tg_op = 'INSERT' or not old.is_published)
     and char_length(btrim(new.display_name)) = 0 then
    raise exception 'profile_incomplete' using errcode = 'P0001', hint = 'Le nom affiché est obligatoire.';
  end if;

  select string_agg(s.title, ' ') into v_services
    from public.services s
   where s.professional_id = new.user_id and s.status = 'published';
  select name into v_loc from public.locations where id = new.location_id;

  new.search_document := public.f_norm(concat_ws(' ',
    new.display_name, new.headline, array_to_string(new.skills, ' '),
    v_cats, v_services, v_loc.name, left(new.description, 500)));
  new.updated_at := now();
  return new;
end $$;
revoke execute on function public.pro_before_write() from public, anon, authenticated;

-- Le métier principal peut faire jusqu'à 200 caractères.
alter table public.professional_profiles drop constraint if exists professional_profiles_headline_check;
alter table public.professional_profiles add constraint professional_profiles_headline_check check (char_length(headline) <= 200);

-- ═══════ migrations/20261123000011_hardening_perf.sql ═══════
-- BALLAL — 0011 : durcissement et performances
-- 1) Compte obligatoire : la recherche et les recommandations ne sont plus ouvertes aux visiteurs anonymes
--    (empêche l'aspiration de l'annuaire sans compte).
-- 2) RLS : auth.uid() évalué une seule fois par requête (« (select auth.uid()) ») au lieu d'une fois par ligne.
-- 3) Index sur les clés étrangères utilisées dans les jointures et suppressions en cascade.

revoke execute on function public.search_professionals(text, uuid, uuid, double precision, double precision, integer,
  boolean, numeric, boolean, integer, text, integer, integer) from anon;
revoke execute on function public.recommend_professionals(uuid, double precision, double precision, integer, integer) from anon;

do $$
declare
  p record;
  q text;
  c text;
  stmt text;
begin
  for p in
    select schemaname, tablename, policyname, qual, with_check
    from pg_policies
    where schemaname = 'public'
      and (coalesce(qual, '') ~ 'auth\.uid\(\)' or coalesce(with_check, '') ~ 'auth\.uid\(\)')
  loop
    q := p.qual;
    c := p.with_check;
    if q is not null then
      q := replace(replace(q, '( SELECT auth.uid() AS uid)', '§UID§'), 'auth.uid()', '(select auth.uid())');
      q := replace(q, '§UID§', '(select auth.uid())');
    end if;
    if c is not null then
      c := replace(replace(c, '( SELECT auth.uid() AS uid)', '§UID§'), 'auth.uid()', '(select auth.uid())');
      c := replace(c, '§UID§', '(select auth.uid())');
    end if;
    stmt := format('alter policy %I on %I.%I', p.policyname, p.schemaname, p.tablename);
    if q is not null then stmt := stmt || format(' using (%s)', q); end if;
    if c is not null then stmt := stmt || format(' with check (%s)', c); end if;
    execute stmt;
  end loop;
end $$;

create index if not exists service_media_service_idx on public.service_media (service_id, sort_order);
create index if not exists favorites_pro_idx on public.favorites (professional_id);
create index if not exists conversations_pro_idx on public.conversations (professional_id);
create index if not exists conversations_created_by_idx on public.conversations (created_by);
create index if not exists request_attachments_req_idx on public.request_attachments (request_id);
create index if not exists services_category_idx on public.services (category_id);
create index if not exists service_requests_service_idx on public.service_requests (service_id);
create index if not exists service_requests_category_idx on public.service_requests (category_id);
create index if not exists service_requests_location_idx on public.service_requests (location_id);
create index if not exists reviews_client_idx on public.reviews (client_id);
create index if not exists review_replies_pro_idx on public.review_replies (professional_id);
create index if not exists user_blocks_blocked_idx on public.user_blocks (blocked_id);
create index if not exists reports_reporter_idx on public.reports (reporter_id);
create index if not exists reports_handled_by_idx on public.reports (handled_by);
create index if not exists device_tokens_user_idx on public.device_tokens (user_id);
create index if not exists user_consents_user_idx on public.user_consents (user_id);
create index if not exists verification_documents_user_idx on public.verification_documents (user_id);
create index if not exists verification_documents_reviewer_idx on public.verification_documents (reviewed_by);
create index if not exists recommendation_events_pro_idx on public.recommendation_events (professional_id);
create index if not exists request_status_history_by_idx on public.request_status_history (changed_by);
create index if not exists audit_logs_actor_idx on public.audit_logs (actor_id);
create index if not exists client_profiles_fav_loc_idx on public.client_profiles (favorite_location_id);
create index if not exists locations_created_by_idx on public.locations (created_by);

-- ═══════ migrations/20261123000012_map_boost_admin.sql ═══════
-- BALLAL — 0012 : carte, mise en avant, Premium, vérification, administration
-- • Les cartes de pros renvoient les coordonnées (centre du quartier, jamais l'adresse exacte).
-- • featured_until / premium_until : options payantes, activées uniquement par l'administration.
-- • Outils d'administration : statistiques, utilisateurs, mise en avant.

alter table public.professional_profiles
  add column if not exists featured_until timestamptz,
  add column if not exists premium_until timestamptz;

-- Ces colonnes ne peuvent pas être modifiées par l'utilisateur lui-même.
create or replace function public.pro_protect_columns()
returns trigger language plpgsql set search_path = '' as $$
begin
  if public.is_end_user_session() then
    if tg_op = 'UPDATE' then
      new.identity_verified := old.identity_verified;
      new.company_verified := old.company_verified;
      new.rating_avg := old.rating_avg;
      new.rating_count := old.rating_count;
      new.profile_views := old.profile_views;
      new.user_id := old.user_id;
      new.featured_until := old.featured_until;
      new.premium_until := old.premium_until;
    else
      new.identity_verified := false;
      new.company_verified := false;
      new.rating_avg := 0;
      new.rating_count := 0;
      new.profile_views := 0;
      new.featured_until := null;
      new.premium_until := null;
    end if;
  end if;
  return new;
end $$;
revoke execute on function public.pro_protect_columns() from public, anon, authenticated;

alter type public.pro_card add attribute lat double precision;
alter type public.pro_card add attribute lng double precision;
alter type public.pro_card add attribute is_featured boolean;
alter type public.pro_card add attribute is_premium boolean;

create or replace function public.search_professionals(
  p_query text default null,
  p_category uuid default null,
  p_location uuid default null,
  p_lat double precision default null,
  p_lng double precision default null,
  p_radius_km int default null,
  p_available_only boolean default false,
  p_min_rating numeric default null,
  p_verified_only boolean default false,
  p_min_experience int default null,
  p_sort text default 'relevance',
  p_limit int default 20,
  p_offset int default 0)
returns setof public.pro_card
language plpgsql stable security definer set search_path = '' as $$
declare
  q text := nullif(btrim(public.f_norm(p_query)), '');
  words text[];
  r numeric := least(coalesce(p_radius_km, 0), 200);
begin
  if q is not null then
    select coalesce(array_agg(w), '{}') into words
      from unnest(regexp_split_to_array(q, '\s+')) w
     where char_length(w) >= 3 and w not in ('les', 'des', 'une', 'pour', 'dans', 'avec', 'sur');
    if array_length(words, 1) is null then words := array[q]; end if;
  end if;

  return query
  with base as (
    select pp.*, l.name as loc_name, pr.phone_verified as phone_ok,
           public.haversine_km(p_lat, p_lng, pp.lat, pp.lng) as dist,
           case when q is null then 0
                else (select avg(extensions.word_similarity(w, pp.search_document)) from unnest(words) w) end as txt
      from public.professional_profiles pp
      join public.profiles pr on pr.id = pp.user_id and pr.status = 'active'
      left join public.locations l on l.id = pp.location_id
     where pp.is_published
       -- Texte : chaque mot doit correspondre (tolérance aux fautes via trigrammes, accents ignorés)
       and (q is null or not exists (
             select 1 from unnest(words) w
              where not (pp.search_document like '%' || w || '%'
                         or extensions.word_similarity(w, pp.search_document) >= 0.5)))
       and (p_category is null or exists (
             select 1 from public.professional_categories pc
               join public.categories c on c.id = pc.category_id
              where pc.professional_id = pp.user_id and (c.id = p_category or c.parent_id = p_category)))
       and (p_location is null or public.pro_serves_location(pp.user_id, p_location))
       and (not coalesce(p_available_only, false) or pp.availability = 'available')
       and (p_min_rating is null or pp.rating_avg >= p_min_rating)
       and (not coalesce(p_verified_only, false) or pp.identity_verified or pp.company_verified)
       and (p_min_experience is null or coalesce(pp.experience_years, 0) >= p_min_experience)
       -- Rayon : préfiltre par boîte englobante, puis distance exacte
       and (r = 0 or p_lat is null or (
             pp.lat between p_lat - r / 111.0 and p_lat + r / 111.0
             and pp.lng between p_lng - r / (111.0 * greatest(cos(radians(p_lat)), 0.01))
                            and p_lng + r / (111.0 * greatest(cos(radians(p_lat)), 0.01))
             and public.haversine_km(p_lat, p_lng, pp.lat, pp.lng) <= r))
  ), scored as (
    select b.*,
      (b.rating_avg * b.rating_count + 3.5 * 3) / (b.rating_count + 3) / 5.0 as bayes,
      case when b.availability = 'available' and b.availability_updated_at > now() - interval '7 days' then 1.0
           when b.availability = 'by_appointment' then 0.6
           when b.availability = 'busy' then 0.3 else 0.0 end as avail,
      case when b.dist is null then 0.5 else 1.0 / (1.0 + b.dist / 5.0) end as near
    from base b
  )
  select s.user_id, s.display_name, s.slug, s.headline, s.logo_path, s.loc_name, s.availability,
         s.rating_avg, s.rating_count, s.identity_verified, s.company_verified, s.phone_ok,
         round(s.dist::numeric, 1)::double precision,
         (0.40 * s.txt + 0.20 * s.bayes + 0.15 * s.avail + 0.15 * s.near
          + 0.10 * ((s.logo_path is not null)::int + (char_length(s.description) > 80)::int) / 2.0)::double precision,
         array_remove(array[
           case when q is not null then 'Correspond à votre recherche' end,
           case when p_location is not null then 'Intervient dans votre zone' end,
           case when s.dist is not null then 'À ' || round(s.dist::numeric, 1) || ' km' end,
           case when s.avail = 1.0 then 'Disponible' end
         ], null),
         s.lat, s.lng, coalesce(s.featured_until > now(), false), coalesce(s.premium_until > now(), false)
    from scored s
   order by
     -- Pros mis en avant (option payante) en tête, sauf tri par distance
     case when p_sort is distinct from 'distance' and s.featured_until > now() then 0 else 1 end,
     case when p_sort = 'distance' then s.dist end asc nulls last,
     case when p_sort = 'rating' then s.bayes end desc,
     case when p_sort not in ('distance', 'rating') or p_sort is null then
       0.40 * s.txt + 0.20 * s.bayes + 0.15 * s.avail + 0.15 * s.near
       + case when s.premium_until > now() then 0.05 else 0 end end desc,
     s.user_id
   limit least(greatest(coalesce(p_limit, 20), 1), 50)
   offset greatest(coalesce(p_offset, 0), 0);
end $$;


create or replace function public.recommend_professionals(
  p_location uuid default null,
  p_lat double precision default null,
  p_lng double precision default null,
  p_radius_km int default 25,
  p_limit int default 10)
returns setof public.pro_card
language plpgsql stable security definer set search_path = '' as $$
declare
  v_uid uuid := auth.uid();
  v_personal boolean := false;
  v_cats uuid[] := '{}';
begin
  if v_uid is not null then
    select coalesce(personalization_enabled, false) into v_personal
      from public.user_preferences where user_id = v_uid;
  end if;
  if v_personal then
    select coalesce(array_agg(distinct pc.category_id), '{}') into v_cats
      from public.professional_categories pc
     where pc.professional_id in (
       select professional_id from public.favorites where client_id = v_uid
       union select professional_id from public.service_requests where client_id = v_uid);
  end if;

  return query
  with base as (
    select pp.*, l.name as loc_name, pr.phone_verified as phone_ok,
           public.haversine_km(p_lat, p_lng, pp.lat, pp.lng) as dist,
           (p_location is not null and public.pro_serves_location(pp.user_id, p_location)) as in_zone,
           exists (select 1 from public.professional_categories pc
                    where pc.professional_id = pp.user_id and pc.category_id = any(v_cats)) as affinity,
           (select pc.category_id from public.professional_categories pc
             where pc.professional_id = pp.user_id order by pc.is_primary desc limit 1) as main_cat
      from public.professional_profiles pp
      join public.profiles pr on pr.id = pp.user_id and pr.status = 'active'
      left join public.locations l on l.id = pp.location_id
     where pp.is_published
       and pp.user_id is distinct from v_uid
       and pp.availability <> 'unavailable'
       and (v_uid is null or not public.is_blocked_between(v_uid, pp.user_id))
  ), scored as (
    select b.*,
      (b.rating_avg * b.rating_count + 3.5 * 3) / (b.rating_count + 3) / 5.0 as bayes,
      (b.availability = 'available' and b.availability_updated_at > now() - interval '7 days') as avail_fresh,
      case when b.in_zone then 1.0
           when b.dist is not null and b.dist <= coalesce(p_radius_km, 25) then 1.0 / (1.0 + b.dist / 5.0)
           else 0.0 end as zone_score
    from base b
    where p_location is null or b.in_zone
       or (b.dist is not null and b.dist <= coalesce(p_radius_km, 25))
  ), ranked as (
    select s.*,
      (0.30 * s.zone_score + 0.25 * s.bayes + 0.15 * s.avail_fresh::int + 0.15 * s.affinity::int
       + case when s.featured_until > now() then 0.10 when s.premium_until > now() then 0.05 else 0 end
       + 0.15 * (case when s.updated_at > now() - interval '30 days' then 1 else 0.5 end)
         * ((s.logo_path is not null)::int + (char_length(s.description) > 80)::int + 1) / 3.0) as sc,
      row_number() over (partition by s.main_cat order by s.bayes desc, s.user_id) as rank_in_cat
    from scored s
  )
  select r.user_id, r.display_name, r.slug, r.headline, r.logo_path, r.loc_name, r.availability,
         r.rating_avg, r.rating_count, r.identity_verified, r.company_verified, r.phone_ok,
         round(r.dist::numeric, 1)::double precision, r.sc::double precision,
         array_remove(array[
           case when r.in_zone then 'Intervient dans votre zone'
                when r.dist is not null then 'À ' || round(r.dist::numeric, 1) || ' km' end,
           case when r.avail_fresh then 'Disponible maintenant' end,
           case when r.affinity then 'Proche de vos centres d''intérêt' end,
           case when r.rating_count >= 3 and r.rating_avg >= 4.5 then 'Très bien noté' end,
           case when r.identity_verified or r.company_verified then 'Profil vérifié' end
         ], null),
         r.lat, r.lng, coalesce(r.featured_until > now(), false), coalesce(r.premium_until > now(), false)
    from ranked r
   where r.rank_in_cat <= 3 -- diversité : 3 pros max par catégorie
   order by r.sc desc, r.user_id
   limit least(greatest(coalesce(p_limit, 10), 1), 30);
end $$;


revoke execute on function public.search_professionals(text, uuid, uuid, double precision, double precision, integer,
  boolean, numeric, boolean, integer, text, integer, integer) from public, anon;
grant execute on function public.search_professionals(text, uuid, uuid, double precision, double precision, integer,
  boolean, numeric, boolean, integer, text, integer, integer) to authenticated;
revoke execute on function public.recommend_professionals(uuid, double precision, double precision, integer, integer) from public, anon;
grant execute on function public.recommend_professionals(uuid, double precision, double precision, integer, integer) to authenticated;

-- ───────────── Administration ─────────────
create or replace function public.admin_set_pro_boost(p_pro uuid, p_featured_days int default null, p_premium_days int default null)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if not public.is_admin() then raise exception 'forbidden' using errcode = '42501'; end if;
  update public.professional_profiles
     set featured_until = case when p_featured_days is null then featured_until
                               when p_featured_days <= 0 then null
                               else greatest(coalesce(featured_until, now()), now()) + make_interval(days => p_featured_days) end,
         premium_until = case when p_premium_days is null then premium_until
                              when p_premium_days <= 0 then null
                              else greatest(coalesce(premium_until, now()), now()) + make_interval(days => p_premium_days) end
   where user_id = p_pro;
  if not found then raise exception 'not_found' using errcode = 'P0002'; end if;
  perform public.log_audit('pro.boost', 'professional', p_pro,
                           jsonb_build_object('featured_days', p_featured_days, 'premium_days', p_premium_days));
  if coalesce(p_featured_days, 0) > 0 or coalesce(p_premium_days, 0) > 0 then
    perform public.notify(p_pro, 'account', 'Votre option BALLAL est active',
      case when coalesce(p_premium_days, 0) > 0 then 'Premium activé pour ' || p_premium_days || ' jours.'
           else 'Votre profil est mis en avant pendant ' || p_featured_days || ' jours.' end,
      'professional', p_pro);
  end if;
end $$;

create or replace function public.admin_stats()
returns jsonb language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.is_staff() then raise exception 'forbidden' using errcode = '42501'; end if;
  return jsonb_build_object(
    'users', (select count(*) from public.profiles),
    'users_7d', (select count(*) from public.profiles where created_at > now() - interval '7 days'),
    'pros', (select count(*) from public.professional_profiles),
    'pros_published', (select count(*) from public.professional_profiles where is_published),
    'pros_verified', (select count(*) from public.professional_profiles where identity_verified or company_verified),
    'featured', (select count(*) from public.professional_profiles where featured_until > now()),
    'premium', (select count(*) from public.professional_profiles where premium_until > now()),
    'requests', (select count(*) from public.service_requests),
    'requests_7d', (select count(*) from public.service_requests where created_at > now() - interval '7 days'),
    'messages_7d', (select count(*) from public.messages where created_at > now() - interval '7 days'),
    'reports_open', (select count(*) from public.reports where status in ('open', 'in_review')),
    'verifications_pending', (select count(*) from public.verification_documents where status = 'pending')
  );
end $$;

create or replace function public.admin_list_users(p_search text default null, p_limit int default 50, p_offset int default 0)
returns table (id uuid, full_name text, email text, status public.account_status, created_at timestamptz,
               roles text[], pro_name text, is_published boolean, identity_verified boolean,
               featured_until timestamptz, premium_until timestamptz)
language plpgsql stable security definer set search_path = '' as $$
declare q text := nullif(btrim(public.f_norm(p_search)), '');
begin
  if not public.is_staff() then raise exception 'forbidden' using errcode = '42501'; end if;
  return query
  select p.id, p.full_name, u.email::text, p.status, p.created_at,
         coalesce((select array_agg(r.role::text order by r.role::text) from public.user_roles r where r.user_id = p.id), '{}'),
         pp.display_name, pp.is_published, pp.identity_verified, pp.featured_until, pp.premium_until
    from public.profiles p
    left join auth.users u on u.id = p.id
    left join public.professional_profiles pp on pp.user_id = p.id
   where q is null
      or public.f_norm(coalesce(p.full_name, '') || ' ' || coalesce(u.email::text, '') || ' ' || coalesce(pp.display_name, ''))
         like '%' || q || '%'
   order by p.created_at desc
   limit least(greatest(coalesce(p_limit, 50), 1), 200) offset greatest(coalesce(p_offset, 0), 0);
end $$;

revoke execute on function public.admin_set_pro_boost(uuid, int, int) from public, anon;
revoke execute on function public.admin_stats() from public, anon;
revoke execute on function public.admin_list_users(text, int, int) from public, anon;
grant execute on function public.admin_set_pro_boost(uuid, int, int) to authenticated;
grant execute on function public.admin_stats() to authenticated;
grant execute on function public.admin_list_users(text, int, int) to authenticated;

-- Un seul dossier de vérification en attente par type et par pro (évite les envois en boucle).
create unique index if not exists verification_one_pending
  on public.verification_documents (user_id, doc_type) where status = 'pending';

-- ═══════ migrations/20261123000013_push_ads_paid_verification.sql ═══════
-- BALLAL — 0013 : notifications push, réglages, vérification payante, annonces sponsorisées

-- ───────────── Réglages de l'application ─────────────
create table if not exists public.app_settings (
  key text primary key,
  value jsonb not null,
  is_public boolean not null default false,
  updated_at timestamptz not null default now()
);
alter table public.app_settings enable row level security;
drop policy if exists app_settings_read on public.app_settings;
create policy app_settings_read on public.app_settings for select
  using (is_public or public.is_admin());

insert into public.app_settings (key, value, is_public) values
  ('verification_fee_gnf', 'null', true),                     -- montant fixé par l'administration
  ('payment_numbers', '{"orange_money": "620657693", "mtn_momo": null}', true),
  ('functions_url', '"https://lpoetkfxmaiqxoanhpum.supabase.co/functions/v1"', false)
on conflict (key) do nothing;

create or replace function public.admin_set_setting(p_key text, p_value jsonb)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if not public.is_admin() then raise exception 'forbidden' using errcode = '42501'; end if;
  if p_key not in ('verification_fee_gnf', 'payment_numbers') then
    raise exception 'unknown_setting' using errcode = '22023';
  end if;
  update public.app_settings set value = coalesce(p_value, 'null'::jsonb), updated_at = now() where key = p_key;
  perform public.log_audit('settings.update', 'app_setting', null, jsonb_build_object('key', p_key, 'value', p_value));
end $$;
revoke execute on function public.admin_set_setting(text, jsonb) from public, anon;
grant execute on function public.admin_set_setting(text, jsonb) to authenticated;

-- ───────────── Vérification payante ─────────────
-- Le pro envoie ses documents ET la référence de son paiement (Orange Money / MTN).
-- L'équipe contrôle le paiement et les documents : payer ne suffit pas, les documents doivent être valides.
alter table public.verification_documents
  add column if not exists payment_reference text check (char_length(payment_reference) <= 80),
  add column if not exists payment_method text check (payment_method in ('orange_money', 'mtn_momo', 'cash', 'other')),
  add column if not exists amount_gnf int check (amount_gnf >= 0);

-- ───────────── Jetons d'appareil (notifications push) ─────────────
create or replace function public.register_device_token(p_token text, p_platform text)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null then raise exception 'not_authenticated' using errcode = '42501'; end if;
  if p_token is null or char_length(p_token) < 20 or char_length(p_token) > 4096 then
    raise exception 'invalid_token' using errcode = '22023';
  end if;
  -- Un appareil ne reçoit les notifications que du dernier compte connecté dessus.
  insert into public.device_tokens (user_id, token, platform, updated_at)
  values (auth.uid(), p_token, p_platform, now())
  on conflict (token) do update set user_id = excluded.user_id, platform = excluded.platform, updated_at = now();
  -- 10 appareils maximum par compte : on garde les plus récents.
  delete from public.device_tokens d
   where d.user_id = auth.uid()
     and d.id not in (select id from public.device_tokens where user_id = auth.uid() order by updated_at desc limit 10);
end $$;

create or replace function public.unregister_device_token(p_token text)
returns void language sql security definer set search_path = '' as $$
  delete from public.device_tokens where token = p_token and user_id = auth.uid();
$$;
revoke execute on function public.register_device_token(text, text) from public, anon;
revoke execute on function public.unregister_device_token(text) from public, anon;
grant execute on function public.register_device_token(text, text) to authenticated;
grant execute on function public.unregister_device_token(text) to authenticated;

alter table public.notifications add column if not exists pushed_at timestamptz;

-- À chaque notification créée, on demande à la fonction « push » de l'envoyer sur le téléphone.
-- La fonction relit la notification en base : un appel forgé ne peut rien envoyer d'autre qu'une vraie
-- notification récente, et une seule fois.
do $$ begin
  create extension if not exists pg_net with schema extensions;
exception when others then
  raise notice 'pg_net indisponible : notifications push désactivées sur cette base';
end $$;

create or replace function public.notifications_push_hook()
returns trigger language plpgsql security definer set search_path = '' as $$
declare v_url text;
begin
  select value #>> '{}' into v_url from public.app_settings where key = 'functions_url';
  if v_url is null then return new; end if;
  begin
    execute 'select net.http_post(url := $1, body := $2, headers := $3, timeout_milliseconds := 5000)'
      using v_url || '/push', jsonb_build_object('notification_id', new.id), '{"Content-Type": "application/json"}'::jsonb;
  exception when others then
    null; -- la notification reste visible dans l'application même si l'envoi push échoue
  end;
  return new;
end $$;
revoke execute on function public.notifications_push_hook() from public, anon, authenticated;

drop trigger if exists notifications_push on public.notifications;
create trigger notifications_push after insert on public.notifications
  for each row execute function public.notifications_push_hook();

-- ───────────── Annonces sponsorisées (publicités discrètes) ─────────────
create table if not exists public.ads (
  id uuid primary key default gen_random_uuid(),
  title text not null check (char_length(title) between 2 and 80),
  body text check (char_length(body) <= 160),
  image_path text,
  link_url text check (link_url ~ '^https://'),
  cta text check (char_length(cta) <= 24),
  is_active boolean not null default true,
  starts_at timestamptz not null default now(),
  ends_at timestamptz,
  impressions int not null default 0,
  clicks int not null default 0,
  created_at timestamptz not null default now()
);
alter table public.ads enable row level security;
drop policy if exists ads_read on public.ads;
drop policy if exists ads_admin on public.ads;
create policy ads_read on public.ads for select to authenticated
  using ((is_active and starts_at <= now() and (ends_at is null or ends_at > now())) or public.is_admin());
create policy ads_admin on public.ads for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

create or replace function public.track_ad(p_ad uuid, p_click boolean default false)
returns void language sql security definer set search_path = '' as $$
  update public.ads
     set impressions = impressions + (not p_click)::int, clicks = clicks + p_click::int
   where id = p_ad and is_active and auth.uid() is not null;
$$;
revoke execute on function public.track_ad(uuid, boolean) from public, anon;
grant execute on function public.track_ad(uuid, boolean) to authenticated;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('ads', 'ads', true, 2097152, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do nothing;
drop policy if exists "ads admin write" on storage.objects;
drop policy if exists "ads admin update" on storage.objects;
drop policy if exists "ads admin delete" on storage.objects;
create policy "ads admin write" on storage.objects for insert to authenticated
  with check (bucket_id = 'ads' and public.is_admin());
create policy "ads admin update" on storage.objects for update to authenticated
  using (bucket_id = 'ads' and public.is_admin());
create policy "ads admin delete" on storage.objects for delete to authenticated
  using (bucket_id = 'ads' and public.is_admin());

-- Statistiques admin : annonces actives
create or replace function public.admin_stats()
returns jsonb language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.is_staff() then raise exception 'forbidden' using errcode = '42501'; end if;
  return jsonb_build_object(
    'users', (select count(*) from public.profiles),
    'users_7d', (select count(*) from public.profiles where created_at > now() - interval '7 days'),
    'pros', (select count(*) from public.professional_profiles),
    'pros_published', (select count(*) from public.professional_profiles where is_published),
    'pros_verified', (select count(*) from public.professional_profiles where identity_verified or company_verified),
    'featured', (select count(*) from public.professional_profiles where featured_until > now()),
    'premium', (select count(*) from public.professional_profiles where premium_until > now()),
    'requests', (select count(*) from public.service_requests),
    'requests_7d', (select count(*) from public.service_requests where created_at > now() - interval '7 days'),
    'messages_7d', (select count(*) from public.messages where created_at > now() - interval '7 days'),
    'reports_open', (select count(*) from public.reports where status in ('open', 'in_review')),
    'verifications_pending', (select count(*) from public.verification_documents where status = 'pending'),
    'ads_active', (select count(*) from public.ads where is_active and (ends_at is null or ends_at > now())),
    'push_devices', (select count(*) from public.device_tokens)
  );
end $$;

create index if not exists device_tokens_user_updated_idx on public.device_tokens (user_id, updated_at desc);

-- ═══════ seed.sql ═══════
-- BALLAL — données de référence (catégories + zones Guinée)
-- Coordonnées : centres APPROXIMATIFS, à corriger par l'administration (écran Zones).
-- Les quartiers héritent du centre de leur commune tant qu'ils ne sont pas corrigés.

-- ───────────── Catégories (famille > métier) ─────────────
insert into public.categories (name, slug, icon, sort_order) values
  ('Bâtiment', 'batiment', 'construction', 1),
  ('Maison', 'maison', 'home', 2),
  ('Technologie', 'technologie', 'computer', 3),
  ('Transport', 'transport', 'local_shipping', 4),
  ('Beauté', 'beaute', 'face', 5),
  ('Éducation', 'education', 'school', 6),
  ('Création', 'creation', 'palette', 7),
  ('Entreprises', 'entreprises', 'business_center', 8),
  ('Événementiel', 'evenementiel', 'celebration', 9)
on conflict (slug) do nothing;

insert into public.categories (parent_id, name, slug, sort_order)
select p.id, v.name, v.slug, v.ord
from (values
  ('batiment', 'Plomberie', 'plomberie', 1), ('batiment', 'Électricité', 'electricite', 2),
  ('batiment', 'Maçonnerie', 'maconnerie', 3), ('batiment', 'Peinture', 'peinture', 4),
  ('batiment', 'Menuiserie', 'menuiserie', 5), ('batiment', 'Climatisation', 'climatisation', 6),
  ('batiment', 'Carrelage', 'carrelage', 7), ('batiment', 'Soudure', 'soudure', 8),
  ('maison', 'Ménage', 'menage', 1), ('maison', 'Cuisine à domicile', 'cuisine', 2),
  ('maison', 'Jardinage', 'jardinage', 3), ('maison', 'Réparation domestique', 'reparation-domestique', 4),
  ('maison', 'Garde d''enfants', 'garde-enfants', 5), ('maison', 'Électroménager', 'electromenager', 6),
  ('technologie', 'Développement Web et mobile', 'developpement', 1), ('technologie', 'Réseau et internet', 'reseau', 2),
  ('technologie', 'Maintenance informatique', 'maintenance-informatique', 3), ('technologie', 'Réparation téléphone', 'reparation-telephone', 4),
  ('technologie', 'Cybersécurité', 'cybersecurite', 5), ('technologie', 'Design UI', 'design-ui', 6),
  ('transport', 'Mécanique auto', 'mecanique', 1), ('transport', 'Chauffeur', 'chauffeur', 2),
  ('transport', 'Lavage auto', 'lavage', 3), ('transport', 'Réparation moto', 'reparation-moto', 4),
  ('transport', 'Transport de marchandises', 'transport-marchandises', 5), ('transport', 'Déménagement', 'demenagement', 6),
  ('beaute', 'Coiffure', 'coiffure', 1), ('beaute', 'Tresses', 'tresses', 2), ('beaute', 'Maquillage', 'maquillage', 3),
  ('beaute', 'Esthétique', 'esthetique', 4), ('beaute', 'Couture', 'couture', 5),
  ('education', 'Cours particuliers', 'cours-particuliers', 1), ('education', 'Langues', 'langues', 2),
  ('education', 'Informatique', 'cours-informatique', 3), ('education', 'Formation professionnelle', 'formation-pro', 4),
  ('creation', 'Photographie', 'photographie', 1), ('creation', 'Vidéo', 'video', 2), ('creation', 'Graphisme', 'graphisme', 3),
  ('creation', 'Marketing digital', 'marketing', 4), ('creation', 'Rédaction', 'redaction', 5), ('creation', 'Impression', 'impression', 6),
  ('entreprises', 'Comptabilité', 'comptabilite', 1), ('entreprises', 'Conseil', 'conseil', 2),
  ('entreprises', 'Traduction', 'traduction', 3), ('entreprises', 'Ressources humaines', 'rh', 4),
  ('entreprises', 'Gestion administrative', 'gestion-administrative', 5),
  ('evenementiel', 'Décoration', 'decoration', 1), ('evenementiel', 'Traiteur', 'traiteur', 2),
  ('evenementiel', 'Sonorisation', 'sonorisation', 3), ('evenementiel', 'Animation / DJ', 'animation', 4),
  ('evenementiel', 'Organisation d''événements', 'organisation-evenements', 5)
) as v(parent_slug, name, slug, ord)
join public.categories p on p.slug = v.parent_slug
on conflict (slug) do nothing;

-- ───────────── Zones ─────────────
insert into public.locations (level, name, slug, lat, lng)
values ('country', 'Guinée', 'guinee', 9.9456, -9.6966)
on conflict do nothing;

-- Régions / zone spéciale de Conakry
insert into public.locations (parent_id, level, name, slug, lat, lng)
select g.id, 'region', v.name, v.slug, v.lat, v.lng
from public.locations g,
(values ('Conakry', 'conakry', 9.6412, -13.5784), ('Kindia', 'kindia', 10.0569, -12.8658),
        ('Boké', 'boke', 10.9409, -14.2967), ('Mamou', 'mamou', 10.3755, -12.0915),
        ('Labé', 'labe', 11.3182, -12.2833), ('Faranah', 'faranah', 10.0404, -10.7434),
        ('Kankan', 'kankan', 10.3854, -9.3057), ('N''Zérékoré', 'nzerekore', 7.7562, -8.8179)
) as v(name, slug, lat, lng)
where g.slug = 'guinee' and g.parent_id is null
on conflict do nothing;

-- Villes principales (une par région ; Conakry est la ville de la zone spéciale)
insert into public.locations (parent_id, level, name, slug, lat, lng)
select r.id, 'city', r.name, r.slug, r.lat, r.lng
from public.locations r
where r.level = 'region'
on conflict do nothing;

-- Communes et quartiers de Conakry (13 communes, liste officielle) : voir migration 0010
select public.seed_conakry_communes();

