-- Migration: class_subjects
-- Purpose: Subject list per class per academic year.
--          is_grade_subject=true for subjects like Drawing that use grade not marks.
--          Soft delete only (is_active=false). Never delete if marks exist.
-- Rollback: DROP TABLE IF EXISTS public.class_subjects CASCADE;

-- CREATE
create table public.class_subjects (
  id             uuid primary key default uuid_generate_v4(),
  class_id       uuid not null references public.classes(id) on delete restrict,
  academic_year  text not null,
  subject_name   text not null,
  display_order  integer not null default 1,
  is_grade_subject boolean not null default false,   -- true = grade; false = marks
  is_active      boolean not null default true,
  created_at     timestamptz not null default now(),
  -- No duplicate subject name per class per year
  unique (class_id, academic_year, subject_name)
);

-- INDEX
create index class_subjects_class_idx  on public.class_subjects (class_id, academic_year);
create index class_subjects_active_idx on public.class_subjects (class_id, academic_year, is_active);
create index class_subjects_order_idx  on public.class_subjects (class_id, academic_year, display_order);

-- RLS
alter table public.class_subjects enable row level security;

create policy "class_subjects_read_assigned"
  on public.class_subjects for select
  using (public.can_access_class(class_id));

create policy "class_subjects_admin_all"
  on public.class_subjects for all
  using (public.is_admin())
  with check (public.is_admin());

-- Teachers may NOT delete subjects; only admin may, and only via soft delete
-- (is_active = false) when no marks exist. Enforced at application layer.

-- ROLLBACK
-- DROP TABLE IF EXISTS public.class_subjects CASCADE;
