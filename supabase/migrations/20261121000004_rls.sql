-- BALLAL — 0004 : Row Level Security
-- Règle d'or : toute table exposée a RLS activé. Les écritures sensibles passent par des fonctions.

-- ───────────── Helpers de visibilité ─────────────
create or replace function public.is_user_active(p_user uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.profiles where id = p_user and status = 'active')
$$;

create or replace function public.is_public_pro(p_pro uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.professional_profiles pp
                 join public.profiles p on p.id = pp.user_id
                 where pp.user_id = p_pro and pp.is_published and p.status = 'active')
$$;

-- Un profil (nom, photo) est visible par soi, le staff, ou une personne avec qui on a un lien.
create or replace function public.can_view_profile(p_target uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select p_target = auth.uid()
      or public.is_staff()
      or public.is_public_pro(p_target)
      or exists (select 1 from public.conversation_members a
                 join public.conversation_members b on b.conversation_id = a.conversation_id
                 where a.user_id = auth.uid() and b.user_id = p_target)
      or exists (select 1 from public.service_requests r
                 where (r.client_id = auth.uid() and r.professional_id = p_target)
                    or (r.professional_id = auth.uid() and r.client_id = p_target))
$$;

create or replace function public.can_send_message(p_conv uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select public.is_conversation_member(p_conv)
     and public.is_active_user()
     and not exists (
       select 1 from public.conversation_members m
        where m.conversation_id = p_conv and m.user_id <> auth.uid()
          and (public.is_blocked_between(auth.uid(), m.user_id) or not public.is_user_active(m.user_id)))
$$;

-- ───────────── Activation RLS ─────────────
do $$
declare t text;
begin
  foreach t in array array[
    'profiles','user_roles','user_preferences','user_consents','locations','categories',
    'client_profiles','professional_profiles','professional_contacts','professional_categories',
    'service_areas','opening_hours','availability_exceptions','services','service_media',
    'portfolio_items','service_requests','request_status_history','request_attachments',
    'conversations','conversation_members','messages','user_blocks','favorites','reviews',
    'review_replies','reports','report_evidence','verification_documents','notifications',
    'device_tokens','recommendation_events','audit_logs','rate_limits']
  loop
    execute format('alter table public.%I enable row level security', t);
  end loop;
end $$;

-- Colonnes modifiables directement par les utilisateurs
revoke update on public.profiles from anon, authenticated;
grant update (full_name, avatar_path) on public.profiles to authenticated;
revoke update on public.conversation_members from anon, authenticated;
grant update (last_read_at, archived) on public.conversation_members to authenticated;
revoke update on public.notifications from anon, authenticated;
grant update (read_at) on public.notifications to authenticated;
revoke update on public.user_preferences from anon, authenticated;
grant update (locale, active_mode, preferred_radius_km, personalization_enabled, notify_messages,
              notify_requests, notify_account, notify_product, quiet_hours_start, quiet_hours_end)
  on public.user_preferences to authenticated;

-- ───────────── Comptes ─────────────
create policy profiles_select on public.profiles for select using (public.can_view_profile(id));
create policy profiles_update on public.profiles for update to authenticated
  using (id = auth.uid()) with check (id = auth.uid());

create policy roles_select on public.user_roles for select to authenticated
  using (user_id = auth.uid() or public.is_staff());
create policy roles_insert_self on public.user_roles for insert to authenticated
  with check (user_id = auth.uid() and role in ('client', 'professional') and public.is_active_user());

create policy prefs_select on public.user_preferences for select to authenticated using (user_id = auth.uid());
create policy prefs_update on public.user_preferences for update to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy consents_select on public.user_consents for select to authenticated using (user_id = auth.uid());
create policy consents_insert on public.user_consents for insert to authenticated with check (user_id = auth.uid());

-- ───────────── Référentiels ─────────────
create policy locations_select on public.locations for select using (is_active or public.is_admin());
create policy locations_admin on public.locations for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

create policy categories_select on public.categories for select using (is_active or public.is_admin());
create policy categories_admin on public.categories for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

-- ───────────── Clients ─────────────
create policy client_select on public.client_profiles for select to authenticated
  using (user_id = auth.uid() or public.is_staff());
create policy client_insert on public.client_profiles for insert to authenticated
  with check (user_id = auth.uid() and public.has_role('client'));
create policy client_update on public.client_profiles for update to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- ───────────── Professionnels ─────────────
create policy pro_select on public.professional_profiles for select
  using (public.is_public_pro(user_id) or user_id = auth.uid() or public.is_staff());
create policy pro_insert on public.professional_profiles for insert to authenticated
  with check (user_id = auth.uid() and public.has_role('professional') and public.is_active_user());
create policy pro_update on public.professional_profiles for update to authenticated
  using (user_id = auth.uid() or public.is_admin()) with check (user_id = auth.uid() or public.is_admin());

create policy contacts_own on public.professional_contacts for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- Sous-ressources publiques d'un pro : lecture si le pro est publié, écriture par le pro lui-même.
do $$
declare t text;
begin
  foreach t in array array['professional_categories','service_areas','opening_hours',
                           'availability_exceptions','portfolio_items']
  loop
    execute format($f$create policy %1$s_select on public.%1$I for select
      using (public.is_public_pro(professional_id) or professional_id = auth.uid() or public.is_staff())$f$, t);
    execute format($f$create policy %1$s_write on public.%1$I for all to authenticated
      using (professional_id = auth.uid()) with check (professional_id = auth.uid())$f$, t);
  end loop;
end $$;

create policy services_select on public.services for select
  using ((status = 'published' and public.is_public_pro(professional_id))
         or professional_id = auth.uid() or public.is_staff());
create policy services_write on public.services for all to authenticated
  using (professional_id = auth.uid()) with check (professional_id = auth.uid());

create policy service_media_select on public.service_media for select
  using (exists (select 1 from public.services s where s.id = service_id));
create policy service_media_write on public.service_media for all to authenticated
  using (exists (select 1 from public.services s where s.id = service_id and s.professional_id = auth.uid()))
  with check (exists (select 1 from public.services s where s.id = service_id and s.professional_id = auth.uid()));

-- ───────────── Demandes ─────────────
create policy requests_select on public.service_requests for select to authenticated
  using (client_id = auth.uid() or professional_id = auth.uid() or public.is_staff());
create policy requests_insert on public.service_requests for insert to authenticated
  with check (client_id = auth.uid() and status = 'pending' and completed_at is null
              and public.is_active_user() and public.is_public_pro(professional_id)
              and not public.is_blocked_between(auth.uid(), professional_id));
-- Pas de UPDATE direct : changement de statut via public.update_request_status()

create or replace function public.request_before_insert()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  perform public.enforce_rate_limit('requests', 20, interval '1 day');
  return new;
end $$;
create trigger requests_before_insert before insert on public.service_requests
  for each row execute function public.request_before_insert();

create policy req_hist_select on public.request_status_history for select to authenticated
  using (exists (select 1 from public.service_requests r where r.id = request_id));

create policy req_att_select on public.request_attachments for select to authenticated
  using (exists (select 1 from public.service_requests r where r.id = request_id));
create policy req_att_insert on public.request_attachments for insert to authenticated
  with check (exists (select 1 from public.service_requests r
                      where r.id = request_id and r.client_id = auth.uid() and r.status = 'pending')
              and split_part(storage_path, '/', 1) = request_id::text);

-- ───────────── Messagerie ─────────────
create policy conv_select on public.conversations for select to authenticated
  using (public.is_conversation_member(id));
create policy conv_members_select on public.conversation_members for select to authenticated
  using (public.is_conversation_member(conversation_id));
create policy conv_members_update on public.conversation_members for update to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy messages_select on public.messages for select to authenticated
  using (public.is_conversation_member(conversation_id));
create policy messages_insert on public.messages for insert to authenticated
  with check (sender_id = auth.uid() and public.can_send_message(conversation_id));

create policy blocks_own on public.user_blocks for all to authenticated
  using (blocker_id = auth.uid()) with check (blocker_id = auth.uid());

-- ───────────── Confiance ─────────────
create policy favorites_own on public.favorites for all to authenticated
  using (client_id = auth.uid()) with check (client_id = auth.uid());

create policy reviews_select on public.reviews for select
  using (status = 'published' or client_id = auth.uid() or professional_id = auth.uid() or public.is_staff());
create policy reviews_insert on public.reviews for insert to authenticated
  with check (client_id = auth.uid() and status = 'published' and moderation_note is null
              and public.is_active_user()
              and exists (select 1 from public.service_requests r
                          where r.id = request_id and r.client_id = auth.uid()
                            and r.professional_id = reviews.professional_id
                            and r.status = 'completed'));

create policy replies_select on public.review_replies for select
  using (exists (select 1 from public.reviews rv where rv.id = review_id));
create policy replies_insert on public.review_replies for insert to authenticated
  with check (professional_id = auth.uid()
              and exists (select 1 from public.reviews rv where rv.id = review_id and rv.professional_id = auth.uid()));

create policy reports_select on public.reports for select to authenticated
  using (reporter_id = auth.uid() or public.is_staff());
create policy reports_insert on public.reports for insert to authenticated
  with check (reporter_id = auth.uid() and status = 'open' and handled_by is null and resolution is null);
create policy reports_staff_update on public.reports for update to authenticated
  using (public.is_staff()) with check (public.is_staff());

create or replace function public.report_before_insert()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  perform public.enforce_rate_limit('reports', 10, interval '1 day');
  return new;
end $$;
create trigger reports_before_insert before insert on public.reports
  for each row execute function public.report_before_insert();

create policy evidence_staff on public.report_evidence for select to authenticated using (public.is_staff());

create policy verif_select on public.verification_documents for select to authenticated
  using (user_id = auth.uid() or public.is_admin());
create policy verif_insert on public.verification_documents for insert to authenticated
  with check (user_id = auth.uid() and status = 'pending' and reviewed_by is null
              and split_part(storage_path, '/', 1) = auth.uid()::text);

-- ───────────── Notifications ─────────────
create policy notif_select on public.notifications for select to authenticated using (user_id = auth.uid());
create policy notif_update on public.notifications for update to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy notif_delete on public.notifications for delete to authenticated using (user_id = auth.uid());

create policy tokens_own on public.device_tokens for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- ───────────── Audit ─────────────
create policy audit_select on public.audit_logs for select to authenticated using (public.is_admin());
-- recommendation_events, rate_limits : aucune policy → inaccessibles hors fonctions serveur.
