-- BALLAL — 0015 : bouton Marketplace (lien vers la boutique Chariow, modifiable par l'admin)
insert into public.app_settings (key, value, is_public)
values ('marketplace_url', '"https://chariow.com"', true)
on conflict (key) do nothing;

create or replace function public.admin_set_setting(p_key text, p_value jsonb)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if not public.is_admin() then raise exception 'forbidden' using errcode = '42501'; end if;
  if p_key not in ('verification_fee_gnf', 'payment_numbers', 'marketplace_url') then
    raise exception 'unknown_setting' using errcode = '22023';
  end if;
  -- Le lien Marketplace doit être une vraie adresse https (pas de javascript:, pas de http).
  if p_key = 'marketplace_url' and (jsonb_typeof(p_value) <> 'string'
       or (p_value #>> '{}') !~ '^https://[A-Za-z0-9.-]+\.[A-Za-z]{2,}(/[A-Za-z0-9._~:/?#@!$&''()*+,;=%-]*)?$'
       or char_length(p_value #>> '{}') > 300) then
    raise exception 'invalid_url' using errcode = '22023';
  end if;
  update public.app_settings set value = coalesce(p_value, 'null'::jsonb), updated_at = now() where key = p_key;
  perform public.log_audit('settings.update', 'app_setting', null, jsonb_build_object('key', p_key, 'value', p_value));
end $$;
revoke execute on function public.admin_set_setting(text, jsonb) from public, anon;
grant execute on function public.admin_set_setting(text, jsonb) to authenticated;
