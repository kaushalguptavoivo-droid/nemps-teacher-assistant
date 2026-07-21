-- Migration: exam_configs
-- Purpose: One examination configuration per class per academic session.
--          Defines exam_pattern (nursery | prep_to_8) and locking state.
-- Rollback: DROP TABLE IF EXISTS public.exam_configs CASCADE;

-- CREATE
create type public.exam_pattern_type as enum ('nursery', 'prep_to_8');

create table public.exam_configs (
  id                  uuid primary key default uuid_generate_v4(),
  class_id            uuid not null references public.classes(id) on delete restrict,
  academic_year       text not null,          -- e.g. "2026-27" (mirrors academic_sessions.label)
  exam_pattern        exam_pattern_type not null,
  passing_percentage  numeric(5,2) not null default 33.00,
  result_type         text not null default 'marks' check (result_type in ('marks','grade','both')),
  is_locked           boolean not null default false,
  created_by          uuid references public.profiles(id),
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now(),
  -- One config per class per year
  unique (class_id, academic_year)
);

-- INDEX
create index exam_configs_class_idx    on public.exam_configs (class_id);
create index exam_configs_year_idx     on public.exam_configs (academic_year);
create index exam_configs_locked_idx   on public.exam_configs (is_locked);

create trigger exam_configs_updated_at
  before update on public.exam_configs
  for each row execute procedure public.set_updated_at();

-- RLS
alter table public.exam_configs enable row level security;

create policy "exam_configs_read_assigned"
  on public.exam_configs for select
  using (public.can_access_class(class_id));

create policy "exam_configs_admin_all"
  on public.exam_configs for all
  using (public.is_admin())
  with check (public.is_admin());

-- ROLLBACK
-- DROP TABLE IF EXISTS public.exam_configs CASCADE;
-- DROP TYPE  IF EXISTS public.exam_pattern_type CASCADE;
