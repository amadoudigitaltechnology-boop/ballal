-- BALLAL — 2e prestataire de paiement : GeniusPay (XOF) pour les pays hors Guinée.
-- Guinée → Djomy (GNF). SN, CI, BJ, CM, CD, CG, GA, SL → GeniusPay (montant converti en XOF).

alter table public.payments add column if not exists currency text not null default 'GNF' check (currency in ('GNF', 'XOF'));
alter table public.payments add column if not exists amount_charged int check (amount_charged is null or amount_charged > 0);
alter table public.payments add column if not exists provider_reference text;
create unique index if not exists payments_provider_ref_idx on public.payments (provider, provider_reference) where provider_reference is not null;

-- Taux de conversion modifiable depuis l'admin : combien de GNF pour 1 XOF.
insert into public.app_settings (key, value, is_public) values ('gnf_per_xof', '15'::jsonb, true)
on conflict (key) do nothing;

-- Pays servis par GeniusPay (modifiable).
insert into public.app_settings (key, value, is_public) values ('geniuspay_countries', '["SN","CI","BJ","CM","CD","CG","GA","SL"]'::jsonb, true)
on conflict (key) do nothing;

-- Mode de paiement « geniuspay » accepté sur les demandes de vérification.
do $$
declare c text;
begin
  select conname into c from pg_constraint
   where conrelid = 'public.verification_documents'::regclass and contype = 'c' and pg_get_constraintdef(oid) ilike '%payment_method%';
  if c is not null then execute format('alter table public.verification_documents drop constraint %I', c); end if;
  alter table public.verification_documents add constraint verification_documents_payment_method_chk
    check (payment_method is null or payment_method in ('orange_money', 'mtn_momo', 'cash', 'djomy', 'geniuspay', 'other'));
end $$;

-- Validation d'un paiement : compare au montant réellement facturé (GNF ou XOF) et note le bon prestataire.
create or replace function public.payment_mark_success(p_payment uuid, p_tx text, p_paid int, p_method text)
returns void language plpgsql security definer set search_path = '' as $$
declare v public.payments; v_due int;
begin
  select * into v from public.payments where id = p_payment for update;
  if v.id is null or v.status = 'success' then return; end if;
  v_due := coalesce(v.amount_charged, v.amount_gnf);
  if p_paid is not null and p_paid < v_due then
    perform public.security_flag('payment_underpaid', jsonb_build_object('payment', p_payment, 'paid', p_paid, 'expected', v_due, 'currency', v.currency));
    update public.payments set status = 'failed', paid_amount = p_paid, updated_at = now() where id = p_payment;
    return;
  end if;
  update public.payments
     set status = 'success', provider_tx_id = coalesce(p_tx, provider_tx_id), paid_amount = coalesce(p_paid, v_due),
         payment_method = p_method, paid_at = now(), updated_at = now()
   where id = p_payment;
  if v.purpose = 'verification' and v.verification_id is not null then
    update public.verification_documents
       set payment_reference = upper(v.provider) || '-' || coalesce(p_tx, p_payment::text), payment_method = v.provider, amount_gnf = v.amount_gnf
     where id = v.verification_id and user_id = v.user_id;
  elsif v.purpose = 'boost' and v.boost_days is not null then
    update public.professional_profiles
       set featured_until = greatest(coalesce(featured_until, now()), now()) + make_interval(days => v.boost_days)
     where user_id = v.user_id;
    insert into public.notifications (user_id, type, title, body, entity_type)
    values (v.user_id, 'account', 'Votre profil est sponsorisé',
            'Votre profil apparaît en tête des résultats pendant ' || v.boost_days || ' jours.', 'professional');
  end if;
  insert into public.audit_logs (actor_id, action, target_type, target_id, metadata)
  values (v.user_id, 'payment_success', 'payment', p_payment,
          jsonb_build_object('purpose', v.purpose, 'provider', v.provider, 'amount', v_due, 'currency', v.currency,
                             'days', v.boost_days, 'tx', p_tx, 'method', p_method));
end $$;
revoke execute on function public.payment_mark_success(uuid, text, int, text) from public, anon, authenticated;
grant execute on function public.payment_mark_success(uuid, text, int, text) to service_role;
