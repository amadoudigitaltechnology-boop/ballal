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
