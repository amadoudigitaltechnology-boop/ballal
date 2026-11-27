-- BALLAL — 0020 : vérification simplifiée, sponsorisation payante, rappels, pros vérifiés en premier.

-- ═══ 1. Vérification : questions sur l'entreprise ; pièce d'identité et RCCM facultatifs ═══
alter table public.verification_documents alter column storage_path drop not null;
alter table public.verification_documents
  add column if not exists company_name text check (company_name is null or char_length(company_name) between 2 and 120),
  add column if not exists main_trade text check (main_trade is null or char_length(main_trade) between 2 and 80),
  add column if not exists quartier text check (quartier is null or char_length(quartier) <= 80),
  add column if not exists experience_years int check (experience_years is null or experience_years between 0 and 70),
  add column if not exists rccm text check (rccm is null or rccm ~ '^[A-Za-z0-9 ./-]{4,40}$');

-- ═══ 2. Sponsorisation payante (comme les publicités sponsorisées) ═══
insert into public.app_settings (key, value, is_public)
values ('boost_plans', '[{"days":3,"price_gnf":15000},{"days":7,"price_gnf":30000},{"days":30,"price_gnf":100000}]'::jsonb, true)
on conflict (key) do nothing;

do $$
declare c text;
begin
  for c in select conname from pg_constraint
            where conrelid = 'public.payments'::regclass and contype = 'c' and pg_get_constraintdef(oid) ilike '%purpose%'
  loop
    execute format('alter table public.payments drop constraint %I', c);
  end loop;
  alter table public.payments add constraint payments_purpose_chk check (purpose in ('verification', 'boost'));
end $$;
alter table public.payments add column if not exists boost_days int check (boost_days is null or boost_days between 1 and 90);

create or replace function public.admin_set_setting(p_key text, p_value jsonb)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if not public.is_admin() then raise exception 'forbidden' using errcode = '42501'; end if;
  if p_key not in ('verification_fee_gnf', 'payment_numbers', 'boost_plans') then
    raise exception 'unknown_setting' using errcode = '22023';
  end if;
  update public.app_settings set value = coalesce(p_value, 'null'::jsonb), updated_at = now() where key = p_key;
  perform public.log_audit('settings.update', 'app_setting', null, jsonb_build_object('key', p_key, 'value', p_value));
end $$;

create or replace function public.payment_mark_success(p_payment uuid, p_tx text, p_paid int, p_method text)
returns void language plpgsql security definer set search_path = '' as $$
declare v public.payments;
begin
  select * into v from public.payments where id = p_payment for update;
  if v.id is null or v.status = 'success' then return; end if;
  if p_paid is not null and p_paid < v.amount_gnf then
    perform public.security_flag('payment_underpaid', jsonb_build_object('payment', p_payment, 'paid', p_paid, 'expected', v.amount_gnf));
    update public.payments set status = 'failed', paid_amount = p_paid, updated_at = now() where id = p_payment;
    return;
  end if;
  update public.payments
     set status = 'success', provider_tx_id = coalesce(p_tx, provider_tx_id), paid_amount = coalesce(p_paid, amount_gnf),
         payment_method = p_method, paid_at = now(), updated_at = now()
   where id = p_payment;
  if v.purpose = 'verification' and v.verification_id is not null then
    update public.verification_documents
       set payment_reference = 'DJOMY-' || coalesce(p_tx, p_payment::text), payment_method = 'djomy', amount_gnf = v.amount_gnf
     where id = v.verification_id and user_id = v.user_id;
  elsif v.purpose = 'boost' and v.boost_days is not null then
    -- La sponsorisation s'ajoute à la période en cours.
    update public.professional_profiles
       set featured_until = greatest(coalesce(featured_until, now()), now()) + make_interval(days => v.boost_days)
     where user_id = v.user_id;
    insert into public.notifications (user_id, type, title, body, entity_type)
    values (v.user_id, 'account', 'Votre profil est sponsorisé',
            'Votre profil apparaît en tête des résultats pendant ' || v.boost_days || ' jours.', 'professional');
  end if;
  insert into public.audit_logs (actor_id, action, target_type, target_id, metadata)
  values (v.user_id, 'payment_success', 'payment', p_payment,
          jsonb_build_object('purpose', v.purpose, 'amount_gnf', v.amount_gnf, 'days', v.boost_days, 'tx', p_tx, 'method', p_method));
end $$;
revoke execute on function public.payment_mark_success(uuid, text, int, text) from public, anon, authenticated;
grant execute on function public.payment_mark_success(uuid, text, int, text) to service_role;

-- ═══ 3. Pros vérifiés recommandés en premier ═══
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
     -- Puis les pros vérifiés : un compte vérifié est toujours recommandé en premier
     case when p_sort is distinct from 'distance' and (s.identity_verified or s.company_verified) then 0 else 1 end,
     case when p_sort = 'distance' then s.dist end asc nulls last,
     case when p_sort = 'rating' then s.bayes end desc,
     case when p_sort not in ('distance', 'rating') or p_sort is null then
       0.40 * s.txt + 0.20 * s.bayes + 0.15 * s.avail + 0.15 * s.near
       + case when s.premium_until > now() then 0.05 else 0 end end desc,
     s.user_id
   limit least(greatest(coalesce(p_limit, 20), 1), 50)
   offset greatest(coalesce(p_offset, 0), 0);
end $$;

-- ═══ 4. Rappel de vérification : 3 fois par semaine (lundi, mercredi, vendredi à 10 h) ═══
create or replace function public.send_verification_reminders()
returns int language plpgsql security definer set search_path = '' as $$
declare n int;
begin
  insert into public.notifications (user_id, type, title, body, entity_type)
  select pp.user_id, 'account', 'Vérifiez votre compte',
         'Les comptes vérifiés sont recommandés en premier aux clients. Vérifiez le vôtre en quelques minutes.',
         'professional'
    from public.professional_profiles pp
    join public.profiles p on p.id = pp.user_id and p.status = 'active'
   where not (pp.identity_verified or pp.company_verified)
     and not exists (select 1 from public.verification_documents d where d.user_id = pp.user_id and d.status = 'pending');
  get diagnostics n = row_count;
  return n;
end $$;
revoke execute on function public.send_verification_reminders() from public, anon, authenticated;

do $$
begin
  create extension if not exists pg_cron;
  perform cron.unschedule('ballal-verification-reminders') where exists (select 1 from cron.job where jobname = 'ballal-verification-reminders');
  perform cron.schedule('ballal-verification-reminders', '0 10 * * 1,3,5', 'select public.send_verification_reminders()');
exception when others then
  raise notice 'pg_cron indisponible ici (base de test) : rappels non planifiés';
end $$;
