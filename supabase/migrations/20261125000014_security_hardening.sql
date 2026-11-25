-- BALLAL — 0014 : blindage avant lancement
--  1. Paiement de la vérification : le montant est imposé par le serveur (jamais par l'application)
--  2. Contrôles serveur des champs (longueurs, formats, chemins de fichiers dans son propre dossier)
--  3. Plafonds de requêtes sur toutes les actions d'écriture restantes
--  4. Journal de sécurité : actions sensibles tracées, tentatives bloquées signalées dans les logs
--  5. Privilèges minimum : anon ne peut plus rien écrire, plus de TRUNCATE nulle part
--  6. Fonction push protégée par un secret partagé

-- ═════════════ 1. Paiement de la vérification ═════════════
create or replace function public.verification_before_insert()
returns trigger language plpgsql security definer set search_path = '' as $$
declare v_fee int;
begin
  perform public.enforce_rate_limit('verification', 5, interval '1 day');
  -- Le prix vient UNIQUEMENT des réglages serveur : la valeur envoyée par l'application est ignorée.
  select (value #>> '{}')::int into v_fee from public.app_settings where key = 'verification_fee_gnf';
  new.amount_gnf := v_fee;
  new.status := 'pending';
  new.reviewed_by := null;
  new.reviewed_at := null;
  new.rejection_reason := null;
  new.created_at := now();
  new.payment_reference := nullif(btrim(new.payment_reference), '');
  if new.payment_reference is not null and new.payment_reference !~ '^[A-Za-z0-9 ._/:#-]{4,80}$' then
    raise exception 'invalid_payment_reference' using errcode = '22023';
  end if;
  -- Une même référence de paiement ne peut servir qu'une fois (anti-réutilisation d'un reçu).
  if new.payment_reference is not null and exists (
       select 1 from public.verification_documents
        where lower(payment_reference) = lower(new.payment_reference) and user_id <> new.user_id) then
    perform public.security_flag('payment_reference_reuse', jsonb_build_object('ref', new.payment_reference));
    raise exception 'payment_reference_already_used' using errcode = '23505';
  end if;
  return new;
end $$;
revoke execute on function public.verification_before_insert() from public, anon, authenticated;

-- ═════════════ 4. Journal de sécurité (créé avant usage) ═════════════
-- Les tentatives bloquées sont annulées par la base (transaction) : elles sont donc écrites
-- dans les journaux Postgres (Supabase > Logs, rechercher « BALLAL_SECURITY »).
-- Les actions sensibles réussies sont gardées dans audit_logs (lecture réservée à l'équipe).
create or replace function public.security_flag(p_kind text, p_detail jsonb default '{}')
returns void language plpgsql security definer set search_path = '' as $$
begin
  raise warning 'BALLAL_SECURITY %', jsonb_build_object('kind', p_kind, 'uid', auth.uid(), 'at', now(), 'detail', coalesce(p_detail, '{}'));
end $$;
revoke execute on function public.security_flag(text, jsonb) from public, anon, authenticated;

drop trigger if exists verification_before_insert on public.verification_documents;
create trigger verification_before_insert before insert on public.verification_documents
  for each row execute function public.verification_before_insert();

-- Les tentatives au-delà des plafonds sont signalées.
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
    perform public.security_flag('rate_limited', jsonb_build_object('bucket', p_bucket, 'hits', v_hits, 'max', p_max));
    raise exception 'rate_limited:%', p_bucket using errcode = 'P0429';
  end if;
end $$;

-- Traces des changements sensibles (rôles, statut de compte, réglages, vérifications, options payantes).
create or replace function public.audit_sensitive_change()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if tg_table_name = 'user_roles' then
    insert into public.audit_logs (actor_id, action, target_type, target_id, metadata)
    values (auth.uid(), 'role_' || lower(tg_op), 'user', coalesce(new.user_id, old.user_id),
            jsonb_build_object('role', coalesce(new.role, old.role)));
    if coalesce(new.role, old.role)::text in ('admin', 'super_admin', 'moderator', 'support') then
      perform public.security_flag('staff_role_change', jsonb_build_object('op', tg_op, 'user', coalesce(new.user_id, old.user_id), 'role', coalesce(new.role, old.role)));
    end if;
  elsif tg_table_name = 'profiles' then
    if new.status is distinct from old.status then
      insert into public.audit_logs (actor_id, action, target_type, target_id, metadata)
      values (auth.uid(), 'account_status', 'user', new.id, jsonb_build_object('from', old.status, 'to', new.status));
    end if;
  elsif tg_table_name = 'app_settings' then
    insert into public.audit_logs (actor_id, action, target_type, metadata)
    values (auth.uid(), 'setting_' || lower(tg_op), 'setting',
            jsonb_build_object('key', coalesce(new.key, old.key),
                               'value', case when coalesce(new.key, old.key) like '%secret%' then '"***"'::jsonb else new.value end));
  elsif tg_table_name = 'professional_profiles' then
    if (new.identity_verified, new.company_verified, new.featured_until, new.premium_until, new.is_published)
       is distinct from (old.identity_verified, old.company_verified, old.featured_until, old.premium_until, old.is_published) then
      insert into public.audit_logs (actor_id, action, target_type, target_id, metadata)
      values (auth.uid(), 'pro_flags', 'professional', new.user_id, jsonb_build_object(
        'identity_verified', new.identity_verified, 'company_verified', new.company_verified,
        'featured_until', new.featured_until, 'premium_until', new.premium_until, 'is_published', new.is_published));
    end if;
  elsif tg_table_name = 'verification_documents' then
    if new.status is distinct from old.status then
      insert into public.audit_logs (actor_id, action, target_type, target_id, metadata)
      values (auth.uid(), 'verification_' || new.status, 'verification', new.id,
              jsonb_build_object('user', new.user_id, 'amount_gnf', new.amount_gnf, 'ref', new.payment_reference));
    end if;
  end if;
  return coalesce(new, old);
end $$;
revoke execute on function public.audit_sensitive_change() from public, anon, authenticated;

drop trigger if exists audit_roles on public.user_roles;
create trigger audit_roles after insert or delete on public.user_roles for each row execute function public.audit_sensitive_change();
drop trigger if exists audit_profiles on public.profiles;
create trigger audit_profiles after update of status on public.profiles for each row execute function public.audit_sensitive_change();
drop trigger if exists audit_settings on public.app_settings;
create trigger audit_settings after insert or update or delete on public.app_settings for each row execute function public.audit_sensitive_change();
drop trigger if exists audit_pro_flags on public.professional_profiles;
create trigger audit_pro_flags after update on public.professional_profiles for each row execute function public.audit_sensitive_change();
drop trigger if exists audit_verification on public.verification_documents;
create trigger audit_verification after update of status on public.verification_documents for each row execute function public.audit_sensitive_change();

-- Le journal est en ajout seul : personne ne peut le modifier ou l'effacer depuis l'application.
revoke insert, update, delete, truncate on public.audit_logs from anon, authenticated;
-- (lecture déjà réservée aux administrateurs par la règle audit_select)

-- Lecture du journal pour la page d'administration.
create or replace function public.admin_security_log(p_limit int default 100)
returns table (created_at timestamptz, action text, target_type text, target_id uuid, actor_name text, metadata jsonb)
language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.is_admin() then
    perform public.security_flag('forbidden_admin_call', jsonb_build_object('fn', 'admin_security_log'));
    raise exception 'forbidden' using errcode = '42501';
  end if;
  return query
    select a.created_at, a.action, a.target_type, a.target_id, p.full_name, a.metadata
      from public.audit_logs a left join public.profiles p on p.id = a.actor_id
     order by a.created_at desc
     limit least(greatest(p_limit, 1), 500);
end $$;
revoke execute on function public.admin_security_log(int) from public, anon;
grant execute on function public.admin_security_log(int) to authenticated;

-- ═════════════ 2. Contrôles serveur des champs ═════════════
-- NOT VALID : les lignes existantes (déjà conformes) ne sont pas relues, toutes les nouvelles le sont.
do $$
declare r record;
begin
  for r in select * from (values
    ('device_tokens', 'device_tokens_token_len', 'char_length(token) between 20 and 4096'),
    ('device_tokens', 'device_tokens_platform_chk', 'platform in (''android'', ''ios'', ''web'')'),
    ('portfolio_items', 'portfolio_path_owner', 'char_length(storage_path) <= 300 and storage_path like professional_id::text || ''/%'''),
    ('service_media', 'service_media_path_len', 'char_length(storage_path) <= 300'),
    ('request_attachments', 'request_att_path_len', 'char_length(storage_path) <= 300'),
    ('professional_profiles', 'pro_logo_owner', 'logo_path is null or (char_length(logo_path) <= 300 and logo_path like user_id::text || ''/%'')'),
    ('professional_profiles', 'pro_cover_owner', 'cover_path is null or (char_length(cover_path) <= 300 and cover_path like user_id::text || ''/%'')'),
    ('profiles', 'profiles_avatar_owner', 'avatar_path is null or (char_length(avatar_path) <= 300 and avatar_path like id::text || ''/%'')'),
    ('reports', 'reports_resolution_len', 'resolution is null or char_length(resolution) <= 2000'),
    ('reviews', 'reviews_moderation_len', 'moderation_note is null or char_length(moderation_note) <= 500'),
    ('verification_documents', 'verif_reason_len', 'rejection_reason is null or char_length(rejection_reason) <= 500'),
    ('verification_documents', 'verif_path_len', 'char_length(storage_path) <= 300'),
    ('ads', 'ads_image_len', 'image_path is null or char_length(image_path) <= 300'),
    ('conversations', 'conv_preview_len', 'last_message_preview is null or char_length(last_message_preview) <= 200')
  ) as t(tbl, name, expr)
  loop
    if not exists (select 1 from pg_constraint where conname = r.name) then
      execute format('alter table public.%I add constraint %I check (%s) not valid', r.tbl, r.name, r.expr);
    end if;
  end loop;
end $$;

-- ═════════════ 3. Plafonds de requêtes manquants ═════════════
create or replace function public.rate_limit_trigger()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  perform public.enforce_rate_limit(tg_argv[0], tg_argv[1]::int, tg_argv[2]::interval);
  return new;
end $$;
revoke execute on function public.rate_limit_trigger() from public, anon, authenticated;

drop trigger if exists rl_reviews on public.reviews;
create trigger rl_reviews before insert on public.reviews for each row execute function public.rate_limit_trigger('reviews', '10', '1 day');
drop trigger if exists rl_review_replies on public.review_replies;
create trigger rl_review_replies before insert on public.review_replies for each row execute function public.rate_limit_trigger('review_replies', '30', '1 day');
drop trigger if exists rl_services on public.services;
create trigger rl_services before insert on public.services for each row execute function public.rate_limit_trigger('services', '50', '1 day');
drop trigger if exists rl_service_media on public.service_media;
create trigger rl_service_media before insert on public.service_media for each row execute function public.rate_limit_trigger('service_media', '200', '1 day');
drop trigger if exists rl_portfolio on public.portfolio_items;
create trigger rl_portfolio before insert on public.portfolio_items for each row execute function public.rate_limit_trigger('portfolio', '100', '1 day');
drop trigger if exists rl_favorites on public.favorites;
create trigger rl_favorites before insert on public.favorites for each row execute function public.rate_limit_trigger('favorites', '300', '1 day');
drop trigger if exists rl_device_tokens on public.device_tokens;
create trigger rl_device_tokens before insert on public.device_tokens for each row execute function public.rate_limit_trigger('device_tokens', '30', '1 day');
drop trigger if exists rl_blocks on public.user_blocks;
create trigger rl_blocks before insert on public.user_blocks for each row execute function public.rate_limit_trigger('blocks', '50', '1 day');

-- ═════════════ 5. Privilèges minimum ═════════════
-- anon (non connecté) : lecture seule, et seulement là où une règle RLS l'autorise. Aucune écriture.
revoke insert, update, delete, truncate, references, trigger on all tables in schema public from anon;
-- TRUNCATE contourne les règles RLS : interdit à tout le monde côté application.
revoke truncate, references, trigger on all tables in schema public from authenticated;
alter default privileges in schema public revoke insert, update, delete, truncate, references, trigger on tables from anon;
alter default privileges in schema public revoke truncate, references, trigger on tables from authenticated;
-- anon ne garde la lecture que des tables qui ont une règle de lecture publique (catégories, communes…).
do $$
declare t text;
begin
  for t in
    select c.relname from pg_class c join pg_namespace n on n.oid = c.relnamespace
     where n.nspname = 'public' and c.relkind in ('r', 'v', 'm')
       and not exists (select 1 from pg_policies p where p.schemaname = 'public' and p.tablename = c.relname
                          and p.cmd in ('SELECT', 'ALL') and (p.roles && array['anon', 'public']::name[]))
  loop
    execute format('revoke select on public.%I from anon', t);
  end loop;
end $$;
-- Les compteurs de limites ne sont jamais modifiables par l'application.
revoke insert, update, delete on public.rate_limits from authenticated;

-- ═════════════ 6. Secret partagé pour la fonction push ═════════════
insert into public.app_settings (key, value, is_public)
values ('push_hook_secret', to_jsonb(replace(gen_random_uuid()::text || gen_random_uuid()::text, '-', '')), false)
on conflict (key) do nothing;

create or replace function public.notifications_push_hook()
returns trigger language plpgsql security definer set search_path = '' as $$
declare v_url text; v_secret text;
begin
  select value #>> '{}' into v_url from public.app_settings where key = 'functions_url';
  select value #>> '{}' into v_secret from public.app_settings where key = 'push_hook_secret';
  if v_url is null then return new; end if;
  begin
    execute 'select net.http_post(url := $1, body := $2, headers := $3, timeout_milliseconds := 5000)'
      using v_url || '/push', jsonb_build_object('notification_id', new.id),
            jsonb_build_object('Content-Type', 'application/json', 'x-ballal-hook', coalesce(v_secret, ''));
  exception when others then
    null;
  end;
  return new;
end $$;
revoke execute on function public.notifications_push_hook() from public, anon, authenticated;

-- ═════════════ 7. Aucun accès sans compte (sauf listes de référence) ═════════════
-- L'application exige un compte : sans connexion, seules les catégories et les communes restent lisibles.
do $$
declare t text;
begin
  for t in
    select c.relname from pg_class c join pg_namespace n on n.oid = c.relnamespace
     where n.nspname = 'public' and c.relkind in ('r', 'v', 'm') and c.relname not in ('categories', 'locations')
  loop
    execute format('revoke select on public.%I from anon', t);
  end loop;
end $$;
revoke execute on function public.is_staff() from public, anon;
revoke execute on function public.can_view_profile(uuid) from public, anon;
revoke execute on function public.is_public_pro(uuid) from public, anon;
revoke execute on function public.pro_serves_location(uuid, uuid) from public, anon;
grant execute on function public.is_staff(), public.can_view_profile(uuid), public.is_public_pro(uuid),
  public.pro_serves_location(uuid, uuid) to authenticated;
