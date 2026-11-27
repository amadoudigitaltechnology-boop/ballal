-- BALLAL — 0019 : paiements en ligne Djomy (Orange Money, MTN MoMo, carte)
-- Le paiement est créé par le serveur (fonction djomy-pay) au tarif des réglages,
-- et validé uniquement par Djomy : webhook signé + contrôle du statut auprès de Djomy.
-- L'application ne peut ni créer ni modifier un paiement.

create table if not exists public.payments (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  purpose text not null check (purpose in ('verification')),
  verification_id uuid references public.verification_documents(id) on delete set null,
  amount_gnf int not null check (amount_gnf > 0),
  status text not null default 'pending' check (status in ('pending', 'success', 'failed', 'cancelled')),
  provider text not null default 'djomy',
  provider_tx_id text unique,
  redirect_url text,
  paid_amount int,
  payment_method text,
  created_at timestamptz not null default now(),
  paid_at timestamptz,
  updated_at timestamptz not null default now()
);
create index if not exists payments_user_idx on public.payments (user_id, created_at desc);

alter table public.payments enable row level security;
revoke all on public.payments from anon, authenticated;
grant select on public.payments to authenticated;
drop policy if exists payments_own_read on public.payments;
create policy payments_own_read on public.payments for select to authenticated
  using (user_id = (select auth.uid()) or public.is_admin());

-- « djomy » devient un moyen de paiement accepté sur les demandes de vérification.
do $$
declare c text;
begin
  for c in select conname from pg_constraint
            where conrelid = 'public.verification_documents'::regclass and contype = 'c'
              and pg_get_constraintdef(oid) ilike '%payment_method%'
  loop
    execute format('alter table public.verification_documents drop constraint %I', c);
  end loop;
  alter table public.verification_documents add constraint verification_payment_method_chk
    check (payment_method is null or payment_method in ('orange_money', 'mtn_momo', 'cash', 'djomy', 'other'));
end $$;

-- Appelée par le serveur (clé service) quand Djomy confirme : enregistre le paiement sur la demande de vérification.
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
  if v.verification_id is not null then
    update public.verification_documents
       set payment_reference = 'DJOMY-' || coalesce(p_tx, p_payment::text), payment_method = 'djomy', amount_gnf = v.amount_gnf
     where id = v.verification_id and user_id = v.user_id;
  end if;
  insert into public.audit_logs (actor_id, action, target_type, target_id, metadata)
  values (v.user_id, 'payment_success', 'payment', p_payment,
          jsonb_build_object('purpose', v.purpose, 'amount_gnf', v.amount_gnf, 'tx', p_tx, 'method', p_method));
end $$;
revoke execute on function public.payment_mark_success(uuid, text, int, text) from public, anon, authenticated;

-- Le tarif payé figure dans la liste des vérifications de l'admin.
do $$
begin
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and tablename = 'payments')
     and exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    alter publication supabase_realtime add table public.payments;
  end if;
end $$;
grant execute on function public.payment_mark_success(uuid, text, int, text) to service_role;
grant select, insert, update on public.payments to service_role;
