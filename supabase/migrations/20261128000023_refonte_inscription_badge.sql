-- BALLAL — refonte : ville et quartier à l'inscription, badge vérifié automatique après paiement,
-- retrait du badge par l'admin, rappel quotidien de sponsorisation, Marketplace réservé aux pros pour publier.

-- ═══ 1. Ville et quartier du profil ═══
alter table public.profiles add column if not exists city text check (city is null or char_length(city) between 2 and 60);
alter table public.profiles add column if not exists district text check (district is null or char_length(district) between 2 and 60);
grant update (city, district) on public.profiles to authenticated;

-- ═══ 2. Paiement de la vérification validé → profil vérifié automatiquement (badge + recommandation) ═══
create or replace function public.payment_mark_success(p_payment uuid, p_tx text, p_paid int, p_method text)
returns void language plpgsql security definer set search_path = '' as $$
declare v public.payments; v_due int; d public.verification_documents;
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
       set payment_reference = upper(v.provider) || '-' || coalesce(p_tx, p_payment::text), payment_method = v.provider,
           amount_gnf = v.amount_gnf, status = 'approved', reviewed_at = now(), rejection_reason = null
     where id = v.verification_id and user_id = v.user_id
    returning * into d;
    if d.id is not null then
      update public.professional_profiles
         set identity_verified = true,
             company_verified = company_verified or d.doc_type <> 'identity'
       where user_id = v.user_id;
      insert into public.notifications (user_id, type, title, body, entity_type, entity_id)
      values (v.user_id, 'account', 'Profil vérifié',
              'Votre badge vérifié est actif. Votre profil est maintenant recommandé en priorité aux clients.',
              'verification_document', d.id);
    end if;
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

-- ═══ 3. Retrait du badge par l'administration (non-respect des règles) ═══
create or replace function public.admin_revoke_verification(p_pro uuid, p_reason text)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if not public.is_admin() then raise exception 'forbidden' using errcode = '42501'; end if;
  if coalesce(trim(p_reason), '') = '' then raise exception 'reason_required' using errcode = '22023'; end if;
  update public.professional_profiles set identity_verified = false, company_verified = false where user_id = p_pro;
  if not found then raise exception 'not_found' using errcode = 'P0002'; end if;
  update public.verification_documents
     set status = 'rejected', rejection_reason = left(p_reason, 300), reviewed_by = auth.uid(), reviewed_at = now()
   where user_id = p_pro and status = 'approved';
  perform public.log_audit('verification.revoke', 'professional', p_pro, jsonb_build_object('reason', left(p_reason, 300)));
  perform public.notify(p_pro, 'account', 'Badge vérifié retiré', left(p_reason, 300), 'professional', p_pro);
end $$;
revoke execute on function public.admin_revoke_verification(uuid, text) from public, anon;
grant execute on function public.admin_revoke_verification(uuid, text) to authenticated;

-- ═══ 4. Rappel quotidien : sponsoriser son profil (jusqu'à ce que le pro soit sponsorisé) ═══
create or replace function public.send_boost_reminders()
returns int language plpgsql security definer set search_path = '' as $$
declare n int;
begin
  insert into public.notifications (user_id, type, title, body, entity_type)
  select pp.user_id, 'account', 'Recevez plus de clients',
         'Sponsorisez votre profil : il passe en tête des résultats et sur l''accueil de Ballal.', 'boost'
    from public.professional_profiles pp
    join public.profiles p on p.id = pp.user_id and p.status = 'active'
   where pp.featured_until is null or pp.featured_until < now();
  get diagnostics n = row_count;
  return n;
end $$;
revoke execute on function public.send_boost_reminders() from public, anon, authenticated;

do $$
begin
  create extension if not exists pg_cron;
  perform cron.unschedule('ballal-boost-reminders') where exists (select 1 from cron.job where jobname = 'ballal-boost-reminders');
  perform cron.schedule('ballal-boost-reminders', '0 17 * * *', 'select public.send_boost_reminders()');
exception when others then
  raise notice 'pg_cron indisponible ici (base de test) : rappels non planifiés';
end $$;

-- ═══ 5. Marketplace : seuls les comptes professionnels publient ; les clients consultent et commandent ═══
drop policy if exists listings_insert on public.listings;
create policy listings_insert on public.listings for insert to authenticated
  with check (seller_id = (select auth.uid()) and status = 'active' and public.is_active_user()
              and exists (select 1 from public.professional_profiles pp where pp.user_id = (select auth.uid())));
