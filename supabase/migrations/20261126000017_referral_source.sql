-- BALLAL — 0017 : « Où avez-vous entendu parler de Ballal ? » (choisi à la création du compte)
alter table public.profiles add column if not exists referral_source text
  check (referral_source is null or referral_source in
    ('facebook', 'tiktok', 'instagram', 'whatsapp', 'youtube', 'snapchat', 'linkedin', 'x', 'friend', 'other'));

-- Répartition des inscriptions par canal (administration).
create or replace function public.admin_referral_stats()
returns table (source text, users bigint)
language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.is_admin() then raise exception 'forbidden' using errcode = '42501'; end if;
  return query select coalesce(p.referral_source, 'inconnu'), count(*) from public.profiles p group by 1 order by 2 desc;
end $$;
revoke execute on function public.admin_referral_stats() from public, anon;
grant execute on function public.admin_referral_stats() to authenticated;
grant update (referral_source) on public.profiles to authenticated;
