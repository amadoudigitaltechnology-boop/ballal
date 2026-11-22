-- BALLAL — 0001 : extensions et types
-- Supabase installe les extensions dans le schéma "extensions".

create schema if not exists extensions;
create extension if not exists pg_trgm with schema extensions;
create extension if not exists unaccent with schema extensions;
create extension if not exists pgcrypto with schema extensions;

-- Normalisation pour la recherche : minuscules + sans accents.
-- unaccent() n'est pas IMMUTABLE ; on l'encapsule pour pouvoir l'indexer.
create or replace function public.f_norm(t text)
returns text
language sql
immutable
parallel safe
set search_path = ''
as $$
  select lower(extensions.unaccent('extensions.unaccent'::regdictionary, coalesce(t, '')))
$$;

create type public.app_role as enum ('client', 'professional', 'moderator', 'admin', 'super_admin');
create type public.account_status as enum ('active', 'suspended', 'deleted');
create type public.pro_type as enum ('independent', 'company');
create type public.availability_status as enum ('available', 'busy', 'unavailable', 'by_appointment');
create type public.publish_status as enum ('draft', 'published', 'archived');
create type public.location_level as enum ('country', 'region', 'prefecture', 'city', 'commune', 'quartier');
create type public.request_status as enum (
  'pending',        -- envoyée, pas encore traitée
  'needs_info',     -- le pro demande des précisions
  'in_discussion',
  'accepted',
  'declined',
  'cancelled',
  'completed'
);
create type public.message_type as enum ('text', 'image', 'audio');
create type public.media_type as enum ('image', 'video');
create type public.review_status as enum ('published', 'hidden');
create type public.report_target as enum ('user', 'professional', 'service', 'review', 'message', 'conversation');
create type public.report_status as enum ('open', 'in_review', 'resolved', 'rejected');
create type public.doc_status as enum ('pending', 'approved', 'rejected');
create type public.doc_type as enum ('identity', 'company');
create type public.reco_action as enum ('impression', 'click', 'contact', 'request');
