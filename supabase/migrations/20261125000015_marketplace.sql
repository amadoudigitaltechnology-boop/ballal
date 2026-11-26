-- BALLAL — 0015 : Marketplace (tout utilisateur peut publier ses articles et les vendre)
-- Sécurité : chacun ne gère que ses annonces, photos dans son propre dossier, champs contrôlés,
-- plafond de publications, discussion acheteur ↔ vendeur dans la messagerie existante.

create table if not exists public.listings (
  id uuid primary key default gen_random_uuid(),
  seller_id uuid not null references public.profiles(id) on delete cascade,
  title text not null check (char_length(btrim(title)) between 3 and 80),
  description text check (description is null or char_length(description) <= 2000),
  price_gnf bigint not null check (price_gnf between 0 and 100000000000),
  category text not null check (category in ('phones', 'electronics', 'fashion', 'home', 'vehicles', 'beauty', 'food', 'other')),
  condition text not null default 'used' check (condition in ('new', 'used')),
  location_name text check (location_name is null or char_length(location_name) <= 60),
  photos text[] not null default '{}' check (cardinality(photos) <= 6),
  status text not null default 'active' check (status in ('active', 'sold', 'removed')),
  views int not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists listings_feed_idx on public.listings (status, created_at desc);
create index if not exists listings_seller_idx on public.listings (seller_id, created_at desc);
create index if not exists listings_category_idx on public.listings (category, created_at desc) where status = 'active';

alter table public.listings enable row level security;

-- Lecture : annonces actives d'un vendeur actif, ses propres annonces, l'administration.
drop policy if exists listings_select on public.listings;
create policy listings_select on public.listings for select to authenticated
  using ((status = 'active' and public.is_user_active(seller_id)) or seller_id = (select auth.uid()) or public.is_admin());
drop policy if exists listings_insert on public.listings;
create policy listings_insert on public.listings for insert to authenticated
  with check (seller_id = (select auth.uid()) and status = 'active' and public.is_active_user());
drop policy if exists listings_update on public.listings;
create policy listings_update on public.listings for update to authenticated
  using (seller_id = (select auth.uid()) or public.is_admin())
  with check (seller_id = (select auth.uid()) or public.is_admin());
drop policy if exists listings_delete on public.listings;
create policy listings_delete on public.listings for delete to authenticated
  using (seller_id = (select auth.uid()));

revoke all on public.listings from anon;
revoke truncate, references, trigger on public.listings from authenticated;

-- Contrôles serveur : photos dans le dossier du vendeur, vues et dates non falsifiables,
-- un vendeur ne peut pas réactiver une annonce retirée par l'administration.
create or replace function public.listing_before_write()
returns trigger language plpgsql security definer set search_path = '' as $$
declare p text;
begin
  if tg_op = 'INSERT' then
    perform public.enforce_rate_limit('listings', 20, interval '1 day');
    new.views := 0;
    new.created_at := now();
  else
    new.seller_id := old.seller_id;
    new.created_at := old.created_at;
    if not public.is_admin() then
      new.views := old.views;
      if old.status = 'removed' then new.status := 'removed'; end if;
      if new.status = 'removed' and old.status <> 'removed' then new.status := old.status; end if;
    end if;
  end if;
  new.title := btrim(new.title);
  new.updated_at := now();
  foreach p in array new.photos loop
    if p is null or char_length(p) > 300 or p not like new.seller_id::text || '/%' then
      raise exception 'invalid_photo_path' using errcode = '22023';
    end if;
  end loop;
  return new;
end $$;
revoke execute on function public.listing_before_write() from public, anon, authenticated;
drop trigger if exists listing_before_write on public.listings;
create trigger listing_before_write before insert or update on public.listings
  for each row execute function public.listing_before_write();

-- Retrait par l'administration : tracé dans le journal de sécurité.
create or replace function public.admin_remove_listing(p_listing uuid, p_reason text default null)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if not public.is_admin() then
    perform public.security_flag('forbidden_admin_call', jsonb_build_object('fn', 'admin_remove_listing'));
    raise exception 'forbidden' using errcode = '42501';
  end if;
  update public.listings set status = 'removed' where id = p_listing;
  insert into public.audit_logs (actor_id, action, target_type, target_id, metadata)
  values (auth.uid(), 'listing_removed', 'listing', p_listing, jsonb_build_object('reason', left(p_reason, 300)));
end $$;
revoke execute on function public.admin_remove_listing(uuid, text) from public, anon;
grant execute on function public.admin_remove_listing(uuid, text) to authenticated;

-- Vue d'une annonce : compteur protégé (une vue par personne et par heure).
create or replace function public.record_listing_view(p_listing uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare v_inserted int;
begin
  if auth.uid() is null then return; end if;
  insert into public.rate_limits (user_id, bucket, window_start, hits)
  values (auth.uid(), 'lview:' || p_listing, date_trunc('hour', now()), 1)
  on conflict do nothing;
  get diagnostics v_inserted = row_count;
  if v_inserted = 1 then
    update public.listings set views = views + 1 where id = p_listing and seller_id <> auth.uid();
  end if;
end $$;
revoke execute on function public.record_listing_view(uuid) from public, anon;
grant execute on function public.record_listing_view(uuid) to authenticated;

-- Fil de la marketplace avec le nom du vendeur (sans exposer ses données privées).
create or replace function public.market_feed(p_category text default null, p_query text default null,
                                              p_seller uuid default null, p_limit int default 30, p_offset int default 0,
                                              p_id uuid default null)
returns table (id uuid, seller_id uuid, seller_name text, seller_avatar text, title text, description text,
               price_gnf bigint, category text, condition text, location_name text, photos text[],
               status text, views int, created_at timestamptz)
language sql stable security definer set search_path = '' as $$
  select l.id, l.seller_id,
         coalesce(nullif(pp.display_name, ''), p.full_name, 'Vendeur'),
         coalesce(pp.logo_path, p.avatar_path),
         l.title, l.description, l.price_gnf, l.category, l.condition, l.location_name, l.photos,
         l.status, l.views, l.created_at
    from public.listings l
    join public.profiles p on p.id = l.seller_id
    left join public.professional_profiles pp on pp.user_id = l.seller_id
   where auth.uid() is not null
     and ((l.status = 'active' and p.status = 'active') or l.seller_id = auth.uid())
     and (p_seller is null or l.seller_id = p_seller)
     and (p_id is null or l.id = p_id)
     and (p_category is null or l.category = p_category)
     and (p_query is null or l.title ilike '%' || replace(replace(left(p_query, 60), '%', ''), '_', '') || '%')
     and not public.is_blocked_between(auth.uid(), l.seller_id)
   order by l.created_at desc
   limit least(greatest(p_limit, 1), 60) offset greatest(p_offset, 0)
$$;
revoke execute on function public.market_feed(text, text, uuid, int, int, uuid) from public, anon;
grant execute on function public.market_feed(text, text, uuid, int, int, uuid) to authenticated;

-- Stockage des photos d'annonces : public en lecture, écriture dans son propre dossier, 5 Mo, images.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('market', 'market', true, 5242880, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update set file_size_limit = excluded.file_size_limit, allowed_mime_types = excluded.allowed_mime_types;
drop policy if exists "market read" on storage.objects;
drop policy if exists "market own write" on storage.objects;
drop policy if exists "market own update" on storage.objects;
drop policy if exists "market own delete" on storage.objects;
create policy "market read" on storage.objects for select using (bucket_id = 'market');
create policy "market own write" on storage.objects for insert to authenticated
  with check (bucket_id = 'market' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "market own update" on storage.objects for update to authenticated
  using (bucket_id = 'market' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "market own delete" on storage.objects for delete to authenticated
  using (bucket_id = 'market' and (storage.foldername(name))[1] = auth.uid()::text);

-- ───────────── Discussion acheteur ↔ vendeur ─────────────
alter table public.conversations add column if not exists listing_id uuid references public.listings(id) on delete set null;
drop index if exists public.conversations_direct_uniq;
create unique index conversations_direct_uniq on public.conversations (client_id, professional_id)
  where request_id is null and listing_id is null;
create unique index if not exists conversations_listing_uniq on public.conversations (client_id, listing_id)
  where listing_id is not null;

create or replace function public.start_listing_conversation(p_listing uuid)
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := auth.uid();
  v_seller uuid;
  v_conv uuid;
begin
  if v_uid is null or not public.is_active_user() then
    raise exception 'not_authenticated' using errcode = '28000';
  end if;
  select seller_id into v_seller from public.listings where id = p_listing and status = 'active';
  if v_seller is null then raise exception 'listing_not_available' using errcode = 'P0001'; end if;
  if v_seller = v_uid then raise exception 'own_listing' using errcode = 'P0001'; end if;
  if public.is_blocked_between(v_uid, v_seller) or not public.is_user_active(v_seller) then
    raise exception 'blocked' using errcode = '42501';
  end if;
  select id into v_conv from public.conversations where client_id = v_uid and listing_id = p_listing;
  if v_conv is null then
    perform public.enforce_rate_limit('new_conversations', 30, interval '1 day');
    -- L'acheteur occupe la place « client », le vendeur la place « professional » de la conversation.
    insert into public.conversations (client_id, professional_id, created_by, listing_id)
    values (v_uid, v_seller, v_uid, p_listing) returning id into v_conv;
    insert into public.conversation_members (conversation_id, user_id, member_role) values
      (v_conv, v_uid, 'client'), (v_conv, v_seller, 'professional');
  end if;
  return v_conv;
end $$;
revoke execute on function public.start_listing_conversation(uuid) from public, anon;
grant execute on function public.start_listing_conversation(uuid) to authenticated;

-- La liste des conversations indique l'article concerné (et n'affiche pas « PRO » pour un simple vendeur).
drop function if exists public.list_my_conversations(int, timestamptz);
create function public.list_my_conversations(p_limit int default 30, p_before timestamptz default null)
returns table (conversation_id uuid, request_id uuid, other_user_id uuid, other_name text, other_avatar text,
               other_is_pro boolean, last_message_at timestamptz, last_message_preview text,
               unread_count int, other_last_read_at timestamptz, archived boolean,
               listing_id uuid, listing_title text, listing_photo text, listing_price_gnf bigint)
language sql stable security definer set search_path = '' as $$
  select c.id, c.request_id, o.user_id,
         coalesce(nullif(pp.display_name, ''), p.full_name, 'Utilisateur'),
         coalesce(pp.logo_path, p.avatar_path),
         o.member_role = 'professional' and c.listing_id is null and pp.user_id is not null,
         c.last_message_at, c.last_message_preview,
         (select count(*)::int from public.messages m
           where m.conversation_id = c.id and m.sender_id <> auth.uid()
             and m.created_at > coalesce(me.last_read_at, '-infinity'::timestamptz)),
         o.last_read_at, me.archived,
         c.listing_id, l.title, l.photos[1], l.price_gnf
    from public.conversation_members me
    join public.conversations c on c.id = me.conversation_id
    join public.conversation_members o on o.conversation_id = c.id and o.user_id <> me.user_id
    join public.profiles p on p.id = o.user_id
    left join public.professional_profiles pp on pp.user_id = o.user_id and o.member_role = 'professional'
    left join public.listings l on l.id = c.listing_id
   where me.user_id = auth.uid()
     and (p_before is null or coalesce(c.last_message_at, c.created_at) < p_before)
   order by coalesce(c.last_message_at, c.created_at) desc
   limit least(greatest(p_limit, 1), 100)
$$;
revoke execute on function public.list_my_conversations(int, timestamptz) from public, anon;
grant execute on function public.list_my_conversations(int, timestamptz) to authenticated;

-- Les annonces apparaissent dans le temps réel (fil mis à jour sans recharger).
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime')
     and not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and tablename = 'listings') then
    alter publication supabase_realtime add table public.listings;
  end if;
end $$;
