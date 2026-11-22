-- BALLAL — 0007 : temps réel (messagerie, notifications, accusés de lecture)
-- Supabase Realtime respecte les politiques RLS pour postgres_changes.
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    alter publication supabase_realtime add table public.messages, public.notifications, public.conversation_members;
  end if;
end $$;
