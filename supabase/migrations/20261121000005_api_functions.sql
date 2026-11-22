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
