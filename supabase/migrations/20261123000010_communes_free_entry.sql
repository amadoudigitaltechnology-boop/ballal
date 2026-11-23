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
