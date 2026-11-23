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
