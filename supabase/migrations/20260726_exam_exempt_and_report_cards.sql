-- Migration: exam_exempt_and_report_cards
-- Purpose: Add is_exempt to exam_marks and create report_cards table.

-- 1. Add is_exempt to exam_marks
alter table public.exam_marks add column if not exists is_exempt boolean not null default false;

-- 2. Add old_is_exempt and new_is_exempt to exam_marks_audit
alter table public.exam_marks_audit add column if not exists old_is_exempt boolean;
alter table public.exam_marks_audit add column if not exists new_is_exempt boolean;

-- 3. Update audit_exam_marks function
create or replace function public.audit_exam_marks()
returns trigger language plpgsql security definer as $$
begin
  if tg_op = 'UPDATE' then
    insert into public.exam_marks_audit
      (mark_id, student_id, subject_id, term_id,
       old_marks, new_marks, old_grade, new_grade,
       old_is_exempt, new_is_exempt,
       changed_by, changed_at)
    values
      (old.id, old.student_id, old.subject_id, old.term_id,
       old.obtained_marks, new.obtained_marks, old.grade, new.grade,
       old.is_exempt, new.is_exempt,
       auth.uid(), now());
  end if;
  return new;
end;
$$;

-- 4. Create report_cards table
create table if not exists public.report_cards (
  id              uuid primary key default uuid_generate_v4(),
  student_id      uuid not null references public.students(id) on delete cascade,
  class_id        uuid not null references public.classes(id) on delete cascade,
  academic_year   text not null,
  total_obtained  numeric(8,2) not null,
  total_maximum   numeric(8,2) not null,
  percentage      numeric(5,2) not null,
  grade           text not null,
  result_status   text not null,
  is_published    boolean not null default false,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  unique (student_id, class_id, academic_year)
);

create trigger report_cards_updated_at
  before update on public.report_cards
  for each row execute procedure public.set_updated_at();

create index report_cards_student_idx on public.report_cards (student_id);
create index report_cards_class_idx on public.report_cards (class_id, academic_year);

-- RLS
alter table public.report_cards enable row level security;

create policy "report_cards_read_assigned"
  on public.report_cards for select
  using (public.can_access_class(class_id));

create policy "report_cards_admin_all"
  on public.report_cards for all
  using (public.is_admin())
  with check (public.is_admin());
