-- Tests de sécurité et de fonctionnement (exécutés par run.sh sur une base jetable).
-- Chaque bloc échoue avec une exception si une règle est violée.
\set ON_ERROR_STOP 1

-- Utilisateurs de test
insert into auth.users (id, phone, phone_confirmed_at, raw_user_meta_data) values
  ('00000000-0000-0000-0000-00000000000a', '224620000001', now(), '{"full_name":"Fatou Client"}'),
  ('00000000-0000-0000-0000-00000000000b', '224620000002', now(), '{"full_name":"Intrus"}'),
  ('00000000-0000-0000-0000-00000000000c', '224620000003', now(), '{"full_name":"Mamadou Diallo"}'),
  ('00000000-0000-0000-0000-00000000000d', '224620000004', now(), '{"full_name":"Admin"}');
insert into public.user_roles (user_id, role) values ('00000000-0000-0000-0000-00000000000d', 'admin');

create or replace function pg_temp.expect_error(sql text, label text) returns void language plpgsql as $$
begin
  begin
    execute sql;
  exception when others then
    raise notice 'OK (refusé) : % → %', label, sqlerrm;
    return;
  end;
  raise exception 'ÉCHEC : % aurait dû être refusé', label;
end $$;
grant execute on function pg_temp.expect_error(text, text) to anon, authenticated;

create or replace function pg_temp.check(cond boolean, label text) returns void language plpgsql as $$
begin
  if cond is not true then raise exception 'ÉCHEC : %', label; end if;
  raise notice 'OK : %', label;
end $$;
grant execute on function pg_temp.check(boolean, text) to anon, authenticated;

select pg_temp.check((select count(*) from public.profiles) = 4, 'profils créés automatiquement');
select pg_temp.check((select phone_verified from public.profiles where id = '00000000-0000-0000-0000-00000000000a'), 'téléphone vérifié repris de auth');

-- ═══ Client A ═══
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000a', false);
set role authenticated;
select public.activate_role('client');
select pg_temp.expect_error($q$insert into public.user_roles values ('00000000-0000-0000-0000-00000000000a','admin')$q$, 'auto-promotion admin');
select pg_temp.expect_error($q$select public.grant_staff_role('00000000-0000-0000-0000-00000000000a','admin')$q$, 'grant_staff_role par un client');
update public.profiles set full_name = 'Fatou B.' where id = '00000000-0000-0000-0000-00000000000a';
select pg_temp.expect_error($q$update public.profiles set status = 'suspended' where id = '00000000-0000-0000-0000-00000000000a'$q$, 'modifier son propre statut');
reset role;

-- ═══ Pro P ═══
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000c', false);
set role authenticated;
select public.activate_role('professional');
select pg_temp.expect_error($q$update public.professional_profiles set display_name = '', is_published = true where user_id = auth.uid()$q$, 'publier sans nom');
update public.professional_profiles
   set display_name = 'Mamadou Services', headline = 'Plombier sanitaire',
       description = 'Installation sanitaire, réparation de fuites, chauffe-eau. Intervention rapide à Ratoma et Dixinn depuis 8 ans.',
       skills = '{fuite,chauffe-eau,sanitaire}', experience_years = 8,
       location_id = (select id from public.locations where slug = 'kipe'),
       rating_avg = 5, rating_count = 999, identity_verified = true
 where user_id = auth.uid();
insert into public.professional_categories (professional_id, category_id, is_primary)
  select auth.uid(), id, true from public.categories where slug = 'plomberie';
insert into public.service_areas (professional_id, location_id)
  select auth.uid(), id from public.locations where slug = 'dixinn';
insert into public.services (professional_id, category_id, title, price_min, status)
  select auth.uid(), id, 'Réparation de fuite', 50000, 'published' from public.categories where slug = 'plomberie';
update public.professional_profiles set is_published = true where user_id = auth.uid();
reset role;
select pg_temp.check((select rating_count = 0 and not identity_verified and lat is not null
                        from public.professional_profiles where user_id = '00000000-0000-0000-0000-00000000000c'),
                     'colonnes protégées ignorées + coordonnées de zone copiées');
select pg_temp.check((select phone from public.professional_contacts where user_id = '00000000-0000-0000-0000-00000000000c') = '+224620000003',
                     'téléphone pro normalisé +224');

-- ═══ Visiteur anonyme ═══
select set_config('request.jwt.claim.sub', '', false);
set role anon;
select pg_temp.check((select count(*) from public.search_professionals('plombie')) = 1, 'recherche avec faute de frappe');
select pg_temp.check((select count(*) from public.search_professionals('Plombier Kipé')) = 1, 'recherche multi-mots avec accent');
select pg_temp.check((select count(*) from public.search_professionals('chauffe eau')) = 1, 'recherche par compétence');
select pg_temp.check((select count(*) from public.search_professionals('coiffure')) = 0, 'pas de faux résultat');
select pg_temp.check((select count(*) from public.search_professionals(p_location := (select id from public.locations where slug = 'ratoma'))) = 1,
                     'filtre commune contenant le quartier du pro');
select pg_temp.check((select count(*) from public.search_professionals(p_location := (select id from public.locations where slug = 'camayenne'))) = 1,
                     'filtre quartier couvert par une zone d''intervention (Dixinn)');
select pg_temp.check((select count(*) from public.search_professionals(p_location := (select id from public.locations where slug = 'kaloum'))) = 0,
                     'zone non couverte exclue');
select pg_temp.check((select count(*) from public.search_professionals(p_lat := 9.62, p_lng := -13.62, p_radius_km := 5)) = 1, 'rayon 5 km');
select pg_temp.check((select count(*) from public.search_professionals(p_lat := 10.38, p_lng := -9.30, p_radius_km := 5)) = 0, 'hors rayon (Kankan)');
select pg_temp.check((select count(*) from public.search_professionals(p_category := (select id from public.categories where slug = 'batiment'))) = 1,
                     'filtre famille de catégorie');
select pg_temp.check((select count(*) from public.professional_contacts) = 0, 'anonyme ne lit pas les contacts');
select pg_temp.check((select count(*) from public.profiles where id = '00000000-0000-0000-0000-00000000000a') = 0, 'anonyme ne voit pas les clients');
select pg_temp.expect_error($q$select * from public.get_professional_contact('00000000-0000-0000-0000-00000000000c')$q$, 'contact sans connexion');
select pg_temp.expect_error($q$insert into public.service_requests (client_id, professional_id, title, description) values ('00000000-0000-0000-0000-00000000000a','00000000-0000-0000-0000-00000000000c','x','yyyyyy')$q$, 'demande anonyme');
reset role;

-- ═══ Demande A → P ═══
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000a', false);
set role authenticated;
select pg_temp.check((select phone from public.get_professional_contact('00000000-0000-0000-0000-00000000000c')) = '+224620000003', 'contact visible connecté');
select pg_temp.expect_error($q$insert into public.service_requests (client_id, professional_id, title, description, status) values (auth.uid(),'00000000-0000-0000-0000-00000000000c','Fuite','Fuite sous l''évier', 'accepted')$q$, 'créer une demande déjà acceptée');
insert into public.service_requests (client_id, professional_id, title, description, location_id)
values (auth.uid(), '00000000-0000-0000-0000-00000000000c', 'Fuite cuisine', 'Fuite sous l''évier depuis hier',
        (select id from public.locations where slug = 'kipe'));
select pg_temp.expect_error($q$select public.update_request_status((select id from public.service_requests limit 1), 'accepted')$q$, 'client qui accepte sa propre demande');
update public.service_requests set status = 'completed'; -- RLS : 0 ligne modifiée
reset role;
select pg_temp.check((select status from public.service_requests limit 1) = 'pending', 'statut inchangé après update direct');
select id as req from public.service_requests limit 1 \gset

select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000b', false);
set role authenticated;
select pg_temp.check((select count(*) from public.service_requests) = 0, 'intrus ne voit pas la demande');
select pg_temp.check((select count(*) from public.request_status_history) = 0, 'intrus ne voit pas l''historique');
select pg_temp.expect_error(format($q$select public.update_request_status(%L, 'cancelled')$q$, :'req'), 'intrus modifie la demande (id connu)');
reset role;

select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000c', false);
set role authenticated;
select pg_temp.check((select count(*) from public.notifications where type = 'new_request') = 1, 'pro notifié de la demande');
select public.update_request_status((select id from public.service_requests limit 1), 'accepted', 'Je passe demain');
select pg_temp.expect_error($q$select public.update_request_status((select id from public.service_requests limit 1), 'pending')$q$, 'transition invalide');
select pg_temp.check((select count(*) from public.profiles where id = '00000000-0000-0000-0000-00000000000a') = 1, 'pro voit le nom du client lié');
reset role;

select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000a', false);
set role authenticated;
select pg_temp.expect_error($q$insert into public.reviews (request_id, client_id, professional_id, rating) select id, auth.uid(), professional_id, 5 from public.service_requests limit 1$q$, 'avis avant fin de prestation');
select public.update_request_status((select id from public.service_requests limit 1), 'completed');
insert into public.reviews (request_id, client_id, professional_id, rating, comment)
  select id, auth.uid(), professional_id, 4, 'Travail propre' from public.service_requests limit 1;
select pg_temp.expect_error($q$insert into public.reviews (request_id, client_id, professional_id, rating) select id, auth.uid(), professional_id, 5 from public.service_requests limit 1$q$, 'second avis sur la même demande');
select pg_temp.check((select count(*) from public.request_status_history) = 3, 'historique des statuts complet');
reset role;
select pg_temp.check((select rating_avg = 4 and rating_count = 1 from public.professional_profiles where user_id = '00000000-0000-0000-0000-00000000000c'), 'note moyenne recalculée');

select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000b', false);
set role authenticated;
select public.activate_role('client');
select pg_temp.expect_error($q$insert into public.reviews (request_id, client_id, professional_id, rating) select id, auth.uid(), '00000000-0000-0000-0000-00000000000c', 1 from (select '00000000-0000-0000-0000-000000000000'::uuid id) x$q$, 'faux avis sans demande');
reset role;

-- ═══ Messagerie ═══
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000a', false);
set role authenticated;
select public.start_conversation('00000000-0000-0000-0000-00000000000c') as conv \gset
select pg_temp.check(public.start_conversation('00000000-0000-0000-0000-00000000000c') = :'conv', 'conversation directe réutilisée');
insert into public.messages (conversation_id, sender_id, body) values (:'conv', auth.uid(), 'Bonjour, vous êtes disponible ?');
select pg_temp.expect_error(format($q$insert into public.messages (conversation_id, sender_id, body) values (%L, '00000000-0000-0000-0000-00000000000c', 'usurpation')$q$, :'conv'), 'envoyer au nom d''un autre');
select pg_temp.expect_error(format($q$insert into public.messages (conversation_id, sender_id, type, attachment_path, attachment_mime) values (%L, auth.uid(), 'image', 'autre-dossier/x.jpg', 'image/jpeg')$q$, :'conv'), 'pièce jointe hors du dossier de conversation');
insert into storage.objects (bucket_id, name) values ('message-attachments', :'conv' || '/photo.jpg');
reset role;

select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000b', false);
set role authenticated;
select pg_temp.check((select count(*) from public.messages) = 0, 'intrus ne lit aucun message');
select pg_temp.check((select count(*) from public.conversations) = 0, 'intrus ne voit aucune conversation');
select pg_temp.expect_error(format($q$insert into public.messages (conversation_id, sender_id, body) values (%L, auth.uid(), 'spam')$q$, :'conv'), 'intrus écrit dans la conversation');
select pg_temp.expect_error(format($q$insert into storage.objects (bucket_id, name) values ('message-attachments', %L)$q$, :'conv' || '/x.jpg'), 'intrus dépose un fichier');
select pg_temp.check((select count(*) from storage.objects where bucket_id = 'message-attachments') = 0, 'intrus ne voit pas les fichiers');
select pg_temp.expect_error(format($q$select public.start_conversation(p_request := %L)$q$, :'req'), 'intrus ouvre la conversation d''une demande (id connu)');
reset role;

select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000c', false);
set role authenticated;
select pg_temp.check((select unread_count from public.list_my_conversations()) = 1, 'non-lu côté pro');
select pg_temp.check((select messages from public.get_unread_counts()) = 1, 'compteur global non-lus');
select pg_temp.check((select count(*) from storage.objects where bucket_id = 'message-attachments') = 1, 'membre voit la pièce jointe');
select public.mark_conversation_read(:'conv');
select pg_temp.check((select unread_count from public.list_my_conversations()) = 0, 'marqué comme lu');
insert into public.messages (conversation_id, sender_id, body) values (:'conv', auth.uid(), 'Oui, demain matin.');
select pg_temp.expect_error($q$select public.start_conversation('00000000-0000-0000-0000-00000000000a')$q$, 'pro démarre une conversation directe vers un client');
insert into public.user_blocks (blocker_id, blocked_id) values (auth.uid(), '00000000-0000-0000-0000-00000000000a');
reset role;

select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000a', false);
set role authenticated;
select pg_temp.expect_error(format($q$insert into public.messages (conversation_id, sender_id, body) values (%L, auth.uid(), 'encore')$q$, :'conv'), 'écrire après blocage');
select pg_temp.check((select count(*) from public.search_professionals('plombier')) = 1, 'recherche reste accessible');
select public.report_content('message', (select id from public.messages where sender_id = '00000000-0000-0000-0000-00000000000c' limit 1),
                             'harassment', 'test', array[(select id from public.messages where sender_id = '00000000-0000-0000-0000-00000000000c' limit 1)]);
reset role;

select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000b', false);
set role authenticated;
select pg_temp.expect_error($q$select public.report_content('message', gen_random_uuid(), 'spam', null, array[(select id from public.messages limit 1)])$q$, 'joindre un message d''une autre conversation');
reset role;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000b', false);
set role authenticated;
select pg_temp.expect_error(format($q$select public.report_content('message', gen_random_uuid(), 'spam', null, array[(select id from public.messages where conversation_id = %L limit 1)])$q$, :'conv'), 'joindre un message invisible (sous-requête vide → null)');
reset role;

-- ═══ Administration ═══
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000d', false);
set role authenticated;
select pg_temp.check((select count(*) from public.report_evidence) = 1, 'modérateur voit le message signalé');
select pg_temp.check((select count(*) from public.messages) = 0, 'admin ne lit pas les conversations');
select public.admin_set_user_status('00000000-0000-0000-0000-00000000000c', 'suspended', 'Test de suspension');
select pg_temp.check((select count(*) from public.audit_logs where action = 'user.set_status') = 1, 'action admin journalisée');
reset role;

select set_config('request.jwt.claim.sub', '', false);
set role anon;
select pg_temp.check((select count(*) from public.search_professionals('plombier')) = 0, 'pro suspendu retiré de la recherche');
reset role;

-- ═══ Recommandation ═══
update public.profiles set status = 'active' where id = '00000000-0000-0000-0000-00000000000c';
update public.professional_profiles set is_published = true where user_id = '00000000-0000-0000-0000-00000000000c';
delete from public.user_blocks;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000b', false);
set role authenticated;
select pg_temp.check((select 'Intervient dans votre zone' = any(reasons) from public.recommend_professionals((select id from public.locations where slug = 'ratoma'))),
                     'recommandation explicable par zone');
select pg_temp.check((select count(*) from public.recommend_professionals((select id from public.locations where slug = 'kaloum'))) = 0,
                     'pas de recommandation hors zone');
update public.user_preferences set personalization_enabled = false where user_id = auth.uid();
select public.log_recommendation_event('00000000-0000-0000-0000-00000000000c', 'click');
reset role;
select pg_temp.check((select count(*) from public.recommendation_events) = 0, 'aucun événement IA si personnalisation désactivée');

-- ═══ Anti-spam ═══
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000a', false);
set role authenticated;
select pg_temp.expect_error(format($q$do $d$ begin for i in 1..40 loop insert into public.messages (conversation_id, sender_id, body) values (%L, auth.uid(), 'msg ' || i); end loop; end $d$$q$, :'conv'), 'limite de 30 messages par minute');
reset role;

-- ═══ Quartier ajouté à la main ═══
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000b', false);
set role authenticated;
select pg_temp.check((select user_added from public.add_location((select id from public.locations where slug = 'kagbelen'), '  Kagbélen   Centre ')), 'quartier ajouté manuellement');
select pg_temp.check((select count(*) from public.locations where slug = 'kagbelen-centre') = 1, 'pas de doublon (accents/espaces)');
select pg_temp.check((select id from public.add_location((select id from public.locations where slug = 'kagbelen'), 'Kagbelen centre')) = (select id from public.locations where slug = 'kagbelen-centre'), 'quartier existant réutilisé');
select pg_temp.expect_error($q$select public.add_location((select id from public.locations where slug = 'kipe'), 'Sous-quartier')$q$, 'ajout sous un quartier refusé');
reset role;
select set_config('request.jwt.claim.sub', '', false);
set role anon;
select pg_temp.expect_error($q$select public.add_location((select id from public.locations where slug = 'kagbelen'), 'X anonyme')$q$, 'ajout anonyme refusé');
reset role;
select pg_temp.check((select count(*) from public.locations where level = 'commune' and parent_id = (select id from public.locations where level='city' and slug='conakry')) = 13, '13 communes à Conakry');

-- ═══ Statistiques pro ═══
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000b', false);
set role authenticated;
insert into public.favorites (client_id, professional_id) values (auth.uid(), '00000000-0000-0000-0000-00000000000c');
reset role;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000c', false);
set role authenticated;
select pg_temp.check(public.count_my_followers() = 1, 'compteur de favoris du pro');
select pg_temp.check((select count(*) from public.favorites) = 0, 'le pro ne voit pas qui l''a mis en favori');
reset role;

\echo '══════ TOUS LES TESTS SONT PASSÉS ══════'
