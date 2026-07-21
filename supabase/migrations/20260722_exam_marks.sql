-- Migration: exam_marks
-- Purpose: Marks (or grade) entered per student per subject per term.
--          UPSERT on (student_id, subject_id, term_id) — no duplicates.
--          Drawing stores grade; all others store obtained_marks.
--          Audit columns track who entered / last updated.
-- Rollback: DROP TABLE IF EXISTS public.exam_marks CASCADE;
--           DROP TABLE IF EXISTS public.exam_marks_audit CASCADE;

-- CREATE — marks
create table public.exam_marks (
  id              uuid primary key default uuid_generate_v4(),
  student_id      uuid not null references public.students(id) on delete restrict,
  class_id        uuid not null references public.classes(id) on delete restrict,
  subject_id      uuid not null references public.class_subjects(id) on delete restrict,
  term_id         uuid not null references public.exam_terms(id) on delete restrict,
  obtained_marks  numeric(6,2),                 -- null when is_grade_subject=true or absent
  grade           text,                         -- null when is_grade_subject=false
  is_absent       boolean not null default false,
  remarks         text,
  entered_by      uuid references public.profiles(id),
  entered_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  -- Constraint: one record per student per subject per term
  unique (student_id, subject_id, term_id),
  -- Constraint: marks must not exceed maximum (checked at app layer; stored here for reference)
  check (obtained_marks is null or obtained_marks >= 0)
);

create trigger exam_marks_updated_at
  before update on public.exam_marks
  for each row execute procedure public.set_updated_at();

-- INDEX
create index exam_marks_student_idx on public.exam_marks (student_id);
create index exam_marks_class_idx   on public.exam_marks (class_id);
create index exam_marks_subject_idx on public.exam_marks (subject_id);
create index exam_marks_term_idx    on public.exam_marks (term_id);
create index exam_marks_year_idx    on public.exam_marks (class_id, student_id, term_id);

-- Audit log — every INSERT/UPDATE on exam_marks appends a row here
create table public.exam_marks_audit (
  id          uuid primary key default uuid_generate_v4(),
  mark_id     uuid not null references public.exam_marks(id) on delete cascade,
  student_id  uuid not null,
  subject_id  uuid not null,
  term_id     uuid not null,
  old_marks   numeric(6,2),
  new_marks   numeric(6,2),
  old_grade   text,
  new_grade   text,
  changed_by  uuid references public.profiles(id),
  changed_at  timestamptz not null default now(),
  reason      text
);

create index exam_marks_audit_mark_idx on public.exam_marks_audit (mark_id);
create index exam_marks_audit_when_idx on public.exam_marks_audit (changed_at);

-- Trigger: capture old vs new on every update
create or replace function public.audit_exam_marks()
returns trigger language plpgsql security definer as $$
begin
  if tg_op = 'UPDATE' then
    insert into public.exam_marks_audit
      (mark_id, student_id, subject_id, term_id,
       old_marks, new_marks, old_grade, new_grade,
       changed_by, changed_at)
    values
      (old.id, old.student_id, old.subject_id, old.term_id,
       old.obtained_marks, new.obtained_marks, old.grade, new.grade,
       auth.uid(), now());
  end if;
  return new;
end;
$$;

create trigger exam_marks_audit_trigger
  after update on public.exam_marks
  for each row execute procedure public.audit_exam_marks();

-- RLS — exam_marks
alter table public.exam_marks enable row level security;

create policy "marks_read_assigned"
  on public.exam_marks for select
  using (public.can_access_class(class_id));

create policy "marks_insert_assigned"
  on public.exam_marks for insert
  with check (
    public.can_access_class(class_id)
    and not exists (
      select 1 from public.exam_configs ec
      join public.exam_terms et on et.exam_config_id = ec.id
      where et.id = term_id and ec.is_locked = true
    )
  );

create policy "marks_update_assigned"
  on public.exam_marks for update
  using (
    public.can_access_class(class_id)
    and not exists (
      select 1 from public.exam_configs ec
      join public.exam_terms et on et.exam_config_id = ec.id
      where et.id = term_id and ec.is_locked = true
    )
  )
  with check (public.can_access_class(class_id));

create policy "marks_admin_all"
  on public.exam_marks for all
  using (public.is_admin())
  with check (public.is_admin());

-- RLS — exam_marks_audit (read-only for admin)
alter table public.exam_marks_audit enable row level security;

create policy "audit_admin_read"
  on public.exam_marks_audit for select
  using (public.is_admin());

-- ROLLBACK
-- DROP TABLE IF EXISTS public.exam_marks_audit CASCADE;
-- DROP TABLE IF EXISTS public.exam_marks CASCADE;
-- DROP FUNCTION IF EXISTS public.audit_exam_marks() CASCADE;
