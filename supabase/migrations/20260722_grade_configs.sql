-- Migration: grade_configs
-- Purpose: Admin-configurable grade table per academic year.
--          Maps percentage ranges to grade labels (A1, A2 … E).
--          Nothing hardcoded — all grades come from this table.
-- Rollback: DROP TABLE IF EXISTS public.grade_configs CASCADE;

-- CREATE
create table public.grade_configs (
  id                  uuid primary key default uuid_generate_v4(),
  academic_year       text not null,
  grade               text not null,           -- "A1","A2","B1","B2","C1","C2","D","E"
  minimum_percentage  numeric(5,2) not null check (minimum_percentage >= 0),
  maximum_percentage  numeric(5,2) not null check (maximum_percentage <= 100),
  description         text,                    -- "Outstanding","Excellent", …
  display_order       integer not null default 1,
  check (minimum_percentage <= maximum_percentage),
  unique (academic_year, grade)
);

-- INDEX
create index grade_configs_year_idx  on public.grade_configs (academic_year);
create index grade_configs_order_idx on public.grade_configs (academic_year, display_order);

-- RLS
alter table public.grade_configs enable row level security;

create policy "grade_configs_read_all"
  on public.grade_configs for select
  using (auth.uid() is not null);

create policy "grade_configs_admin_all"
  on public.grade_configs for all
  using (public.is_admin())
  with check (public.is_admin());

-- Seed default grade table for 2026-27 (admin may modify)
-- Run AFTER inserting a row into academic_sessions with label='2026-27'
insert into public.grade_configs
  (academic_year, grade, minimum_percentage, maximum_percentage, description, display_order)
values
  ('2026-27', 'A1', 91, 100, 'Outstanding',        1),
  ('2026-27', 'A2', 81,  90, 'Excellent',           2),
  ('2026-27', 'B1', 71,  80, 'Very Good',           3),
  ('2026-27', 'B2', 61,  70, 'Good',                4),
  ('2026-27', 'C1', 51,  60, 'Average',             5),
  ('2026-27', 'C2', 41,  50, 'Needs Improvement',   6),
  ('2026-27', 'D',  33,  40, 'Pass',                7),
  ('2026-27', 'E',   0,  32, 'Fail',                8);

-- ROLLBACK
-- DELETE FROM public.grade_configs WHERE academic_year = '2026-27';
-- DROP TABLE IF EXISTS public.grade_configs CASCADE;
