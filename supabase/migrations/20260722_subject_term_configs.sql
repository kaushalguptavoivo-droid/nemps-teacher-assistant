-- Migration: subject_term_configs
-- Purpose: Per-subject per-term maximum marks and inclusion flag.
--          Allows different subjects to have different max marks in the same term,
--          and allows some subjects to be excluded from certain terms entirely
--          (e.g. Art only has Annual, not UT1/UT2).
--          If no row exists for a subject+term, the term's default maximum_marks is used.
-- Rollback: DROP TABLE IF EXISTS public.subject_term_configs CASCADE;

create table public.subject_term_configs (
  id          uuid primary key default uuid_generate_v4(),
  subject_id  uuid not null references public.class_subjects(id) on delete cascade,
  term_id     uuid not null references public.exam_terms(id)     on delete cascade,
  max_marks   numeric(6,2) not null default 0
                check (max_marks >= 0),
  is_included boolean not null default true,  -- false = term does not apply to this subject
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  unique (subject_id, term_id)
);

create trigger subject_term_configs_updated_at
  before update on public.subject_term_configs
  for each row execute procedure public.set_updated_at();

-- INDEX
create index stc_subject_idx on public.subject_term_configs (subject_id);
create index stc_term_idx    on public.subject_term_configs (term_id);

-- RLS
alter table public.subject_term_configs enable row level security;

create policy "stc_read_all_authed"
  on public.subject_term_configs for select
  using (auth.role() = 'authenticated');

create policy "stc_admin_all"
  on public.subject_term_configs for all
  using (public.is_admin())
  with check (public.is_admin());

-- ROLLBACK
-- DROP TABLE IF EXISTS public.subject_term_configs CASCADE;
