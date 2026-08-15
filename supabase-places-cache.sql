-- Shared cache for the nearby-places Edge Function.
-- Run once in the Supabase SQL editor (or via `supabase db push`).
--
-- RLS is enabled with no policies: only the service-role key used by the
-- Edge Function can read or write; the anon key shipped in the app cannot.

create table if not exists public.places_cache (
  cache_key  text primary key,
  payload    jsonb not null,
  expires_at timestamptz not null,
  updated_at timestamptz not null default now()
);

alter table public.places_cache enable row level security;

create index if not exists places_cache_expires_idx
  on public.places_cache (expires_at);

-- Optional housekeeping: delete expired rows older than a week.
-- Schedule with pg_cron if you like; the function ignores expired rows either way.
-- delete from public.places_cache where expires_at < now() - interval '7 days';
