-- BALLAL — 0006 : stockage des fichiers (buckets publics et privés séparés)
-- Convention de chemins :
--   avatars/{user_id}/…               public
--   pro-media/{user_id}/…             public (logo, couverture, portfolio, services)
--   request-attachments/{request_id}/… privé (client + pro de la demande)
--   message-attachments/{conversation_id}/… privé (membres de la conversation)
--   verification-docs/{user_id}/…     privé (propriétaire + administrateurs)

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types) values
  ('avatars', 'avatars', true, 2097152, array['image/jpeg', 'image/png', 'image/webp']),
  ('pro-media', 'pro-media', true, 5242880, array['image/jpeg', 'image/png', 'image/webp', 'video/mp4']),
  ('request-attachments', 'request-attachments', false, 5242880, array['image/jpeg', 'image/png', 'image/webp']),
  ('message-attachments', 'message-attachments', false, 10485760,
     array['image/jpeg', 'image/png', 'image/webp', 'audio/aac', 'audio/mp4', 'audio/m4a', 'audio/mpeg', 'audio/ogg']),
  ('verification-docs', 'verification-docs', false, 5242880, array['image/jpeg', 'image/png', 'application/pdf'])
on conflict (id) do nothing;

-- Lecture des buckets publics
create policy "public read" on storage.objects for select
  using (bucket_id in ('avatars', 'pro-media'));

-- Écriture dans son propre dossier (buckets publics)
create policy "own folder write" on storage.objects for insert to authenticated
  with check (bucket_id in ('avatars', 'pro-media') and (storage.foldername(name))[1] = auth.uid()::text);
create policy "own folder update" on storage.objects for update to authenticated
  using (bucket_id in ('avatars', 'pro-media') and (storage.foldername(name))[1] = auth.uid()::text);
create policy "own folder delete" on storage.objects for delete to authenticated
  using (bucket_id in ('avatars', 'pro-media') and (storage.foldername(name))[1] = auth.uid()::text);

-- Pièces jointes de demande
create policy "request attachments read" on storage.objects for select to authenticated
  using (bucket_id = 'request-attachments' and exists (
    select 1 from public.service_requests r
     where r.id::text = (storage.foldername(name))[1]
       and (r.client_id = auth.uid() or r.professional_id = auth.uid())));
create policy "request attachments write" on storage.objects for insert to authenticated
  with check (bucket_id = 'request-attachments' and exists (
    select 1 from public.service_requests r
     where r.id::text = (storage.foldername(name))[1] and r.client_id = auth.uid() and r.status = 'pending'));

-- Pièces jointes de messagerie
create policy "message attachments read" on storage.objects for select to authenticated
  using (bucket_id = 'message-attachments'
         and public.is_conversation_member(((storage.foldername(name))[1])::uuid));
create policy "message attachments write" on storage.objects for insert to authenticated
  with check (bucket_id = 'message-attachments'
              and public.can_send_message(((storage.foldername(name))[1])::uuid));

-- Justificatifs (jamais publics)
create policy "verification read" on storage.objects for select to authenticated
  using (bucket_id = 'verification-docs'
         and ((storage.foldername(name))[1] = auth.uid()::text or public.is_admin()));
create policy "verification write" on storage.objects for insert to authenticated
  with check (bucket_id = 'verification-docs' and (storage.foldername(name))[1] = auth.uid()::text);
