-- BALLAL — 0011 : durcissement et performances
-- 1) Compte obligatoire : la recherche et les recommandations ne sont plus ouvertes aux visiteurs anonymes
--    (empêche l'aspiration de l'annuaire sans compte).
-- 2) RLS : auth.uid() évalué une seule fois par requête (« (select auth.uid()) ») au lieu d'une fois par ligne.
-- 3) Index sur les clés étrangères utilisées dans les jointures et suppressions en cascade.

revoke execute on function public.search_professionals(text, uuid, uuid, double precision, double precision, integer,
  boolean, numeric, boolean, integer, text, integer, integer) from anon;
revoke execute on function public.recommend_professionals(uuid, double precision, double precision, integer, integer) from anon;

do $$
declare
  p record;
  q text;
  c text;
  stmt text;
begin
  for p in
    select schemaname, tablename, policyname, qual, with_check
    from pg_policies
    where schemaname = 'public'
      and (coalesce(qual, '') ~ 'auth\.uid\(\)' or coalesce(with_check, '') ~ 'auth\.uid\(\)')
  loop
    q := p.qual;
    c := p.with_check;
    if q is not null then
      q := replace(replace(q, '( SELECT auth.uid() AS uid)', '§UID§'), 'auth.uid()', '(select auth.uid())');
      q := replace(q, '§UID§', '(select auth.uid())');
    end if;
    if c is not null then
      c := replace(replace(c, '( SELECT auth.uid() AS uid)', '§UID§'), 'auth.uid()', '(select auth.uid())');
      c := replace(c, '§UID§', '(select auth.uid())');
    end if;
    stmt := format('alter policy %I on %I.%I', p.policyname, p.schemaname, p.tablename);
    if q is not null then stmt := stmt || format(' using (%s)', q); end if;
    if c is not null then stmt := stmt || format(' with check (%s)', c); end if;
    execute stmt;
  end loop;
end $$;

create index if not exists service_media_service_idx on public.service_media (service_id, sort_order);
create index if not exists favorites_pro_idx on public.favorites (professional_id);
create index if not exists conversations_pro_idx on public.conversations (professional_id);
create index if not exists conversations_created_by_idx on public.conversations (created_by);
create index if not exists request_attachments_req_idx on public.request_attachments (request_id);
create index if not exists services_category_idx on public.services (category_id);
create index if not exists service_requests_service_idx on public.service_requests (service_id);
create index if not exists service_requests_category_idx on public.service_requests (category_id);
create index if not exists service_requests_location_idx on public.service_requests (location_id);
create index if not exists reviews_client_idx on public.reviews (client_id);
create index if not exists review_replies_pro_idx on public.review_replies (professional_id);
create index if not exists user_blocks_blocked_idx on public.user_blocks (blocked_id);
create index if not exists reports_reporter_idx on public.reports (reporter_id);
create index if not exists reports_handled_by_idx on public.reports (handled_by);
create index if not exists device_tokens_user_idx on public.device_tokens (user_id);
create index if not exists user_consents_user_idx on public.user_consents (user_id);
create index if not exists verification_documents_user_idx on public.verification_documents (user_id);
create index if not exists verification_documents_reviewer_idx on public.verification_documents (reviewed_by);
create index if not exists recommendation_events_pro_idx on public.recommendation_events (professional_id);
create index if not exists request_status_history_by_idx on public.request_status_history (changed_by);
create index if not exists audit_logs_actor_idx on public.audit_logs (actor_id);
create index if not exists client_profiles_fav_loc_idx on public.client_profiles (favorite_location_id);
create index if not exists locations_created_by_idx on public.locations (created_by);
