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
