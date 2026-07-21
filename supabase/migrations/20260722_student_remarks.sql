-- Migration: student_remarks
-- Purpose: One remark per student per term, entered by class teacher.
-- Rollback: DROP TABLE IF EXISTS public.student_remarks CASCADE;

-- CREATE
create table public.student_remarks (
  id          uuid primary key default uuid_generate_v4(),
  student_id  uuid not null references public.students(id) on delete cascade,
  term_id     uuid not null references public.exam_terms(id) on delete cascade,
  remark      text not null,
  entered_by  uuid references public.profiles(id),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  -- One remark per student per term
  unique (student_id, term_id)
);

create trigger student_remarks_updated_at
  before update on public.student_remarks
  for each row execute procedure public.set_updated_at();

-- INDEX
create index student_remarks_student_idx on public.student_remarks (student_id);
create index student_remarks_term_idx    on public.student_remarks (term_id);

-- RLS
alter table public.student_remarks enable row level security;

-- Teacher may read/write remarks only for students in their class
create policy "remarks_read_assigned"
  on public.student_remarks for select
  using (
    exists (
      select 1 from public.students s
      where s.id = student_id
        and public.can_access_class(s.class_id)
    )
  );

create policy "remarks_insert_assigned"
  on public.student_remarks for insert
  with check (
    exists (
      select 1 from public.students s
      where s.id = student_id
        and public.can_access_class(s.class_id)
    )
  );

create policy "remarks_update_assigned"
  on public.student_remarks for update
  using (
    exists (
      select 1 from public.students s
      where s.id = student_id
        and public.can_access_class(s.class_id)
    )
  )
  with check (
    exists (
      select 1 from public.students s
      where s.id = student_id
        and public.can_access_class(s.class_id)
    )
  );

create policy "remarks_admin_all"
  on public.student_remarks for all
  using (public.is_admin())
  with check (public.is_admin());

-- ROLLBACK
-- DROP TABLE IF EXISTS public.student_remarks CASCADE;
