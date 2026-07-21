-- Migration: academic_sessions
-- Purpose: Track academic sessions (years). Only one may be ACTIVE at a time.
-- Rollback: DROP TABLE IF EXISTS public.academic_sessions CASCADE;

-- CREATE
create table public.academic_sessions (
  id          uuid primary key default uuid_generate_v4(),
  label       text not null unique,          -- e.g. "2026-27"
  is_active   boolean not null default false,
  created_by  uuid references public.profiles(id),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

-- Only one session can be active at a time (partial unique index)
create unique index academic_sessions_one_active
  on public.academic_sessions (is_active)
  where is_active = true;

-- INDEX
create index academic_sessions_label_idx on public.academic_sessions (label);

-- Auto-update updated_at
create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger academic_sessions_updated_at
  before update on public.academic_sessions
  for each row execute procedure public.set_updated_at();

-- RLS
alter table public.academic_sessions enable row level security;

create policy "sessions_read_all"
  on public.academic_sessions for select
  using (auth.uid() is not null);

create policy "sessions_admin_all"
  on public.academic_sessions for all
  using (public.is_admin())
  with check (public.is_admin());

-- ROLLBACK (for reference)
-- DROP TABLE IF EXISTS public.academic_sessions CASCADE;
-- DROP FUNCTION IF EXISTS public.set_updated_at() CASCADE;
