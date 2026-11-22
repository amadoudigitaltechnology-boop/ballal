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
