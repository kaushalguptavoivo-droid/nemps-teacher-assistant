-- Migration: Dynamic ERP Upgrade
-- Purpose: Supports unlimited dynamic exam patterns, custom subject components (Oral/Written/etc),
--          and maps marks directly to components. Preserves backward compatibility.

-- 1. Upgrade Exam Configs to support dynamic patterns
-- We change exam_pattern from an enum to text to allow any custom pattern name created by Admin.
alter table public.exam_configs alter column exam_pattern type text using exam_pattern::text;
drop type if exists public.exam_pattern_type cascade;

-- 2. Create Subject Components Table
-- Allows subjects to be broken down into 'Written', 'Oral', 'Practical', etc.
create table if not exists public.subject_components (
  id             uuid primary key default uuid_generate_v4(),
  subject_id     uuid not null references public.class_subjects(id) on delete cascade,
  component_name text not null, -- e.g. 'Written', 'Oral', 'Project'
  max_marks      numeric(6,2) not null check (max_marks >= 0),
  is_grade       boolean not null default false,
  display_order  integer not null default 1,
  created_at     timestamptz not null default now(),
  unique (subject_id, component_name)
);

create index subject_components_idx on public.subject_components(subject_id);

alter table public.subject_components enable row level security;
create policy "subject_components_read_all" on public.subject_components for select using (auth.role() = 'authenticated');
create policy "subject_components_admin_all" on public.subject_components for all using (public.is_admin()) with check (public.is_admin());

-- 3. Update Exam Marks to support components
-- For old records, component_id is null (meaning it applies to the whole subject).
-- For new records, component_id can pinpoint exact Oral/Written breakdown.
alter table public.exam_marks add column if not exists component_id uuid references public.subject_components(id) on delete restrict;

-- Drop old unique constraint and create a new one that includes component_id
-- If component_id is null, coalesce it to a dummy UUID so the unique index still works for whole subjects.
alter table public.exam_marks drop constraint if exists exam_marks_student_id_subject_id_term_id_key;
create unique index exam_marks_unique_component_idx on public.exam_marks (student_id, subject_id, term_id, coalesce(component_id, '00000000-0000-0000-0000-000000000000'::uuid));

-- Ensure fee_types supports future advanced parameters
alter table public.fee_types add column if not exists is_mandatory boolean default true;
alter table public.fee_types add column if not exists depends_on_transport boolean default false;
