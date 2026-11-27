-- BALLAL — 0018 : inscription sans code e-mail (exécuté par le PDG dans le SQL Editor le 27/11/2026).
-- Chaque compte est confirmé dès sa création ; le code e-mail reste utilisé pour « mot de passe oublié ».
create or replace function public.auto_confirm_email()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.email is not null and new.email_confirmed_at is null then
    new.email_confirmed_at := now();
  end if;
  return new;
end $$;
revoke execute on function public.auto_confirm_email() from public, anon, authenticated;
drop trigger if exists auto_confirm_email on auth.users;
create trigger auto_confirm_email before insert on auth.users
  for each row execute function public.auto_confirm_email();
update auth.users set email_confirmed_at = now() where email is not null and email_confirmed_at is null;
