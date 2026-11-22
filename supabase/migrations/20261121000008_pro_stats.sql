-- BALLAL — 0008 : statistiques du tableau de bord pro (données réelles uniquement)
create or replace function public.count_my_followers()
returns int language sql stable security definer set search_path = '' as $$
  select count(*)::int from public.favorites where professional_id = auth.uid()
$$;
