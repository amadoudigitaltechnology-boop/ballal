-- BALLAL — 0021 : application multi-pays (CEDEAO + RD Congo, Angola, Cameroun, Gabon, Congo-Brazzaville).
-- Chaque utilisateur a un pays ; recherche et marketplace montrent les pros et annonces de son pays.
create table if not exists public.countries (
  code text primary key check (code ~ '^[A-Z]{2}$'),
  name text not null,
  dial_code text not null,
  currency text not null,
  sort int not null default 100,
  online_payment boolean not null default false,
  is_active boolean not null default true
);
alter table public.countries enable row level security;
drop policy if exists countries_read on public.countries;
create policy countries_read on public.countries for select to anon, authenticated using (is_active);
revoke insert, update, delete, truncate on public.countries from anon, authenticated;
grant select on public.countries to anon, authenticated;

insert into public.countries (code, name, dial_code, currency, sort) values
  ('GN', $$Guinée$$, '+224', 'GNF', 1),
  ('CD', $$RD Congo$$, '+243', 'CDF', 2),
  ('SN', $$Sénégal$$, '+221', 'XOF', 3),
  ('CI', $$Côte d’Ivoire$$, '+225', 'XOF', 4),
  ('AO', $$Angola$$, '+244', 'AOA', 5),
  ('ML', $$Mali$$, '+223', 'XOF', 6),
  ('CM', $$Cameroun$$, '+237', 'XAF', 7),
  ('BF', $$Burkina Faso$$, '+226', 'XOF', 8),
  ('TG', $$Togo$$, '+228', 'XOF', 9),
  ('BJ', $$Bénin$$, '+229', 'XOF', 10),
  ('GA', $$Gabon$$, '+241', 'XAF', 11),
  ('CG', $$Congo-Brazzaville$$, '+242', 'XAF', 12),
  ('NG', $$Nigeria$$, '+234', 'NGN', 13),
  ('GH', $$Ghana$$, '+233', 'GHS', 14),
  ('NE', $$Niger$$, '+227', 'XOF', 15),
  ('SL', $$Sierra Leone$$, '+232', 'SLE', 16),
  ('LR', $$Liberia$$, '+231', 'LRD', 17),
  ('GM', $$Gambie$$, '+220', 'GMD', 18),
  ('GW', $$Guinée-Bissau$$, '+245', 'XOF', 19),
  ('CV', $$Cap-Vert$$, '+238', 'CVE', 20)
on conflict (code) do update set name = excluded.name, dial_code = excluded.dial_code, currency = excluded.currency, sort = excluded.sort;
-- Paiement en ligne (Djomy) : Guinée uniquement pour le moment.
update public.countries set online_payment = (code = 'GN');

alter table public.profiles add column if not exists country_code text not null default 'GN' references public.countries(code);
grant update (country_code) on public.profiles to authenticated;
create index if not exists profiles_country_idx on public.profiles (country_code);

-- Villes principales de chaque pays (la Guinée garde ses régions et communes).
insert into public.locations (level, name, slug, path) values ('country', $$RD Congo$$, 'rd-congo', '/rd-congo/') on conflict do nothing;
insert into public.locations (parent_id, level, name, slug, path, lat, lng) select id, 'region', $$Kinshasa$$, 'kinshasa', '/rd-congo/kinshasa/', -4.3217, 15.3126 from public.locations where level = 'country' and slug = 'rd-congo' and parent_id is null on conflict do nothing;
insert into public.locations (parent_id, level, name, slug, path, lat, lng) select id, 'region', $$Lubumbashi$$, 'lubumbashi', '/rd-congo/lubumbashi/', -11.6609, 27.4794 from public.locations where level = 'country' and slug = 'rd-congo' and parent_id is null on conflict do nothing;
insert into public.locations (parent_id, level, name, slug, path, lat, lng) select id, 'region', $$Goma$$, 'goma', '/rd-congo/goma/', -1.6585, 29.2205 from public.locations where level = 'country' and slug = 'rd-congo' and parent_id is null on conflict do nothing;
insert into public.locations (level, name, slug, path) values ('country', $$Sénégal$$, 'senegal', '/senegal/') on conflict do nothing;
insert into public.locations (parent_id, level, name, slug, path, lat, lng) select id, 'region', $$Dakar$$, 'dakar', '/senegal/dakar/', 14.7167, -17.4677 from public.locations where level = 'country' and slug = 'senegal' and parent_id is null on conflict do nothing;
insert into public.locations (parent_id, level, name, slug, path, lat, lng) select id, 'region', $$Thiès$$, 'thies', '/senegal/thies/', 14.791, -16.9256 from public.locations where level = 'country' and slug = 'senegal' and parent_id is null on conflict do nothing;
insert into public.locations (parent_id, level, name, slug, path, lat, lng) select id, 'region', $$Saint-Louis$$, 'saint-louis', '/senegal/saint-louis/', 16.0179, -16.4896 from public.locations where level = 'country' and slug = 'senegal' and parent_id is null on conflict do nothing;
insert into public.locations (level, name, slug, path) values ('country', $$Côte d’Ivoire$$, 'cote-divoire', '/cote-divoire/') on conflict do nothing;
insert into public.locations (parent_id, level, name, slug, path, lat, lng) select id, 'region', $$Abidjan$$, 'abidjan', '/cote-divoire/abidjan/', 5.36, -4.0083 from public.locations where level = 'country' and slug = 'cote-divoire' and parent_id is null on conflict do nothing;
insert into public.locations (parent_id, level, name, slug, path, lat, lng) select id, 'region', $$Bouaké$$, 'bouake', '/cote-divoire/bouake/', 7.6906, -5.0391 from public.locations where level = 'country' and slug = 'cote-divoire' and parent_id is null on conflict do nothing;
insert into public.locations (parent_id, level, name, slug, path, lat, lng) select id, 'region', $$Yamoussoukro$$, 'yamoussoukro', '/cote-divoire/yamoussoukro/', 6.8276, -5.2893 from public.locations where level = 'country' and slug = 'cote-divoire' and parent_id is null on conflict do nothing;
insert into public.locations (level, name, slug, path) values ('country', $$Angola$$, 'angola', '/angola/') on conflict do nothing;
insert into public.locations (parent_id, level, name, slug, path, lat, lng) select id, 'region', $$Luanda$$, 'luanda', '/angola/luanda/', -8.839, 13.2894 from public.locations where level = 'country' and slug = 'angola' and parent_id is null on conflict do nothing;
insert into public.locations (parent_id, level, name, slug, path, lat, lng) select id, 'region', $$Huambo$$, 'huambo', '/angola/huambo/', -12.7761, 15.7392 from public.locations where level = 'country' and slug = 'angola' and parent_id is null on conflict do nothing;
insert into public.locations (parent_id, level, name, slug, path, lat, lng) select id, 'region', $$Benguela$$, 'benguela', '/angola/benguela/', -12.5763, 13.4055 from public.locations where level = 'country' and slug = 'angola' and parent_id is null on conflict do nothing;
insert into public.locations (level, name, slug, path) values ('country', $$Mali$$, 'mali', '/mali/') on conflict do nothing;
insert into public.locations (parent_id, level, name, slug, path, lat, lng) select id, 'region', $$Bamako$$, 'bamako', '/mali/bamako/', 12.6392, -8.0029 from public.locations where level = 'country' and slug = 'mali' and parent_id is null on conflict do nothing;
insert into public.locations (parent_id, level, name, slug, path, lat, lng) select id, 'region', $$Sikasso$$, 'sikasso', '/mali/sikasso/', 11.3176, -5.6665 from public.locations where level = 'country' and slug = 'mali' and parent_id is null on conflict do nothing;
insert into public.locations (level, name, slug, path) values ('country', $$Cameroun$$, 'cameroun', '/cameroun/') on conflict do nothing;
insert into public.locations (parent_id, level, name, slug, path, lat, lng) select id, 'region', $$Douala$$, 'douala', '/cameroun/douala/', 4.0511, 9.7679 from public.locations where level = 'country' and slug = 'cameroun' and parent_id is null on conflict do nothing;
insert into public.locations (parent_id, level, name, slug, path, lat, lng) select id, 'region', $$Yaoundé$$, 'yaounde', '/cameroun/yaounde/', 3.848, 11.5021 from public.locations where level = 'country' and slug = 'cameroun' and parent_id is null on conflict do nothing;
insert into public.locations (level, name, slug, path) values ('country', $$Burkina Faso$$, 'burkina-faso', '/burkina-faso/') on conflict do nothing;
insert into public.locations (parent_id, level, name, slug, path, lat, lng) select id, 'region', $$Ouagadougou$$, 'ouagadougou', '/burkina-faso/ouagadougou/', 12.3714, -1.5197 from public.locations where level = 'country' and slug = 'burkina-faso' and parent_id is null on conflict do nothing;
insert into public.locations (parent_id, level, name, slug, path, lat, lng) select id, 'region', $$Bobo-Dioulasso$$, 'bobo-dioulasso', '/burkina-faso/bobo-dioulasso/', 11.1771, -4.2979 from public.locations where level = 'country' and slug = 'burkina-faso' and parent_id is null on conflict do nothing;
insert into public.locations (level, name, slug, path) values ('country', $$Togo$$, 'togo', '/togo/') on conflict do nothing;
insert into public.locations (parent_id, level, name, slug, path, lat, lng) select id, 'region', $$Lomé$$, 'lome', '/togo/lome/', 6.1725, 1.2314 from public.locations where level = 'country' and slug = 'togo' and parent_id is null on conflict do nothing;
insert into public.locations (parent_id, level, name, slug, path, lat, lng) select id, 'region', $$Kara$$, 'kara', '/togo/kara/', 9.5511, 1.1861 from public.locations where level = 'country' and slug = 'togo' and parent_id is null on conflict do nothing;
insert into public.locations (level, name, slug, path) values ('country', $$Bénin$$, 'benin', '/benin/') on conflict do nothing;
insert into public.locations (parent_id, level, name, slug, path, lat, lng) select id, 'region', $$Cotonou$$, 'cotonou', '/benin/cotonou/', 6.3703, 2.3912 from public.locations where level = 'country' and slug = 'benin' and parent_id is null on conflict do nothing;
insert into public.locations (parent_id, level, name, slug, path, lat, lng) select id, 'region', $$Porto-Novo$$, 'porto-novo', '/benin/porto-novo/', 6.4969, 2.6289 from public.locations where level = 'country' and slug = 'benin' and parent_id is null on conflict do nothing;
insert into public.locations (parent_id, level, name, slug, path, lat, lng) select id, 'region', $$Parakou$$, 'parakou', '/benin/parakou/', 9.3372, 2.6303 from public.locations where level = 'country' and slug = 'benin' and parent_id is null on conflict do nothing;
insert into public.locations (level, name, slug, path) values ('country', $$Gabon$$, 'gabon', '/gabon/') on conflict do nothing;
insert into public.locations (parent_id, level, name, slug, path, lat, lng) select id, 'region', $$Libreville$$, 'libreville', '/gabon/libreville/', 0.4162, 9.4673 from public.locations where level = 'country' and slug = 'gabon' and parent_id is null on conflict do nothing;
insert into public.locations (parent_id, level, name, slug, path, lat, lng) select id, 'region', $$Port-Gentil$$, 'port-gentil', '/gabon/port-gentil/', -0.7193, 8.7815 from public.locations where level = 'country' and slug = 'gabon' and parent_id is null on conflict do nothing;
insert into public.locations (level, name, slug, path) values ('country', $$Congo-Brazzaville$$, 'congo-brazzaville', '/congo-brazzaville/') on conflict do nothing;
insert into public.locations (parent_id, level, name, slug, path, lat, lng) select id, 'region', $$Brazzaville$$, 'brazzaville', '/congo-brazzaville/brazzaville/', -4.2634, 15.2429 from public.locations where level = 'country' and slug = 'congo-brazzaville' and parent_id is null on conflict do nothing;
insert into public.locations (parent_id, level, name, slug, path, lat, lng) select id, 'region', $$Pointe-Noire$$, 'pointe-noire', '/congo-brazzaville/pointe-noire/', -4.7692, 11.8664 from public.locations where level = 'country' and slug = 'congo-brazzaville' and parent_id is null on conflict do nothing;
insert into public.locations (level, name, slug, path) values ('country', $$Nigeria$$, 'nigeria', '/nigeria/') on conflict do nothing;
insert into public.locations (parent_id, level, name, slug, path, lat, lng) select id, 'region', $$Lagos$$, 'lagos', '/nigeria/lagos/', 6.5244, 3.3792 from public.locations where level = 'country' and slug = 'nigeria' and parent_id is null on conflict do nothing;
insert into public.locations (parent_id, level, name, slug, path, lat, lng) select id, 'region', $$Abuja$$, 'abuja', '/nigeria/abuja/', 9.0765, 7.3986 from public.locations where level = 'country' and slug = 'nigeria' and parent_id is null on conflict do nothing;
insert into public.locations (level, name, slug, path) values ('country', $$Ghana$$, 'ghana', '/ghana/') on conflict do nothing;
insert into public.locations (parent_id, level, name, slug, path, lat, lng) select id, 'region', $$Accra$$, 'accra', '/ghana/accra/', 5.6037, -0.187 from public.locations where level = 'country' and slug = 'ghana' and parent_id is null on conflict do nothing;
insert into public.locations (parent_id, level, name, slug, path, lat, lng) select id, 'region', $$Kumasi$$, 'kumasi', '/ghana/kumasi/', 6.6885, -1.6244 from public.locations where level = 'country' and slug = 'ghana' and parent_id is null on conflict do nothing;
insert into public.locations (level, name, slug, path) values ('country', $$Niger$$, 'niger', '/niger/') on conflict do nothing;
insert into public.locations (parent_id, level, name, slug, path, lat, lng) select id, 'region', $$Niamey$$, 'niamey', '/niger/niamey/', 13.5116, 2.1254 from public.locations where level = 'country' and slug = 'niger' and parent_id is null on conflict do nothing;
insert into public.locations (level, name, slug, path) values ('country', $$Sierra Leone$$, 'sierra-leone', '/sierra-leone/') on conflict do nothing;
insert into public.locations (parent_id, level, name, slug, path, lat, lng) select id, 'region', $$Freetown$$, 'freetown', '/sierra-leone/freetown/', 8.4657, -13.2317 from public.locations where level = 'country' and slug = 'sierra-leone' and parent_id is null on conflict do nothing;
insert into public.locations (level, name, slug, path) values ('country', $$Liberia$$, 'liberia', '/liberia/') on conflict do nothing;
insert into public.locations (parent_id, level, name, slug, path, lat, lng) select id, 'region', $$Monrovia$$, 'monrovia', '/liberia/monrovia/', 6.3156, -10.8074 from public.locations where level = 'country' and slug = 'liberia' and parent_id is null on conflict do nothing;
insert into public.locations (level, name, slug, path) values ('country', $$Gambie$$, 'gambie', '/gambie/') on conflict do nothing;
insert into public.locations (parent_id, level, name, slug, path, lat, lng) select id, 'region', $$Banjul$$, 'banjul', '/gambie/banjul/', 13.4549, -16.579 from public.locations where level = 'country' and slug = 'gambie' and parent_id is null on conflict do nothing;
insert into public.locations (parent_id, level, name, slug, path, lat, lng) select id, 'region', $$Serrekunda$$, 'serrekunda', '/gambie/serrekunda/', 13.4382, -16.6781 from public.locations where level = 'country' and slug = 'gambie' and parent_id is null on conflict do nothing;
insert into public.locations (level, name, slug, path) values ('country', $$Guinée-Bissau$$, 'guinee-bissau', '/guinee-bissau/') on conflict do nothing;
insert into public.locations (parent_id, level, name, slug, path, lat, lng) select id, 'region', $$Bissau$$, 'bissau', '/guinee-bissau/bissau/', 11.8817, -15.6178 from public.locations where level = 'country' and slug = 'guinee-bissau' and parent_id is null on conflict do nothing;
insert into public.locations (level, name, slug, path) values ('country', $$Cap-Vert$$, 'cap-vert', '/cap-vert/') on conflict do nothing;
insert into public.locations (parent_id, level, name, slug, path, lat, lng) select id, 'region', $$Praia$$, 'praia', '/cap-vert/praia/', 14.933, -23.5133 from public.locations where level = 'country' and slug = 'cap-vert' and parent_id is null on conflict do nothing;

-- Recherche : seulement les pros du pays de l'utilisateur.
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
  v_cc text := coalesce((select pr0.country_code from public.profiles pr0 where pr0.id = auth.uid()), 'GN');
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
      join public.profiles pr on pr.id = pp.user_id and pr.status = 'active' and pr.country_code = v_cc
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

-- Marketplace : seulement les annonces du pays de l'utilisateur.
create or replace function public.market_feed(p_category text default null, p_query text default null,
                                              p_seller uuid default null, p_limit int default 30, p_offset int default 0,
                                              p_id uuid default null)
returns table (id uuid, seller_id uuid, seller_name text, seller_avatar text, title text, description text,
               price_gnf bigint, category text, condition text, location_name text, photos text[],
               status text, views int, created_at timestamptz)
language sql stable security definer set search_path = '' as $$
  select l.id, l.seller_id,
         coalesce(nullif(pp.display_name, ''), p.full_name, 'Vendeur'),
         coalesce(pp.logo_path, p.avatar_path),
         l.title, l.description, l.price_gnf, l.category, l.condition, l.location_name, l.photos,
         l.status, l.views, l.created_at
    from public.listings l
    join public.profiles p on p.id = l.seller_id
     and p.country_code = coalesce((select me.country_code from public.profiles me where me.id = auth.uid()), 'GN')
    left join public.professional_profiles pp on pp.user_id = l.seller_id
   where auth.uid() is not null
     and ((l.status = 'active' and p.status = 'active') or l.seller_id = auth.uid())
     and (p_seller is null or l.seller_id = p_seller)
     and (p_id is null or l.id = p_id)
     and (p_category is null or l.category = p_category)
     and (p_query is null or l.title ilike '%' || replace(replace(left(p_query, 60), '%', ''), '_', '') || '%')
     and not public.is_blocked_between(auth.uid(), l.seller_id)
   order by l.created_at desc
   limit least(greatest(p_limit, 1), 60) offset greatest(p_offset, 0)
$$;
