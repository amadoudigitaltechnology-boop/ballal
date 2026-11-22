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
