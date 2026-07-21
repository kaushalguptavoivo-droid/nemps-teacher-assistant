-- Migration: exam_terms
-- Purpose: Individual examination terms belonging to an exam_config.
--          Auto-created from exam pattern; admin-editable maximum_marks.
-- Rollback: DROP TABLE IF EXISTS public.exam_terms CASCADE;

-- CREATE
create table public.exam_terms (
  id                    uuid primary key default uuid_generate_v4(),
  exam_config_id        uuid not null references public.exam_configs(id) on delete cascade,
  term_name             text not null,          -- "Oral","Written","UT1","Half Yearly","UT2","Annual"
  maximum_marks         numeric(6,2) not null check (maximum_marks > 0),
  display_order         integer not null default 1,
  include_in_final_result boolean not null default true,
  created_at            timestamptz not null default now(),
  -- No duplicate term per config
  unique (exam_config_id, term_name)
);

-- INDEX
create index exam_terms_config_idx on public.exam_terms (exam_config_id);
create index exam_terms_order_idx  on public.exam_terms (exam_config_id, display_order);

-- RLS
alter table public.exam_terms enable row level security;

create policy "exam_terms_read_assigned"
  on public.exam_terms for select
  using (
    exists (
      select 1 from public.exam_configs ec
      where ec.id = exam_config_id
        and public.can_access_class(ec.class_id)
    )
  );

create policy "exam_terms_admin_all"
  on public.exam_terms for all
  using (public.is_admin())
  with check (public.is_admin());

-- ROLLBACK
-- DROP TABLE IF EXISTS public.exam_terms CASCADE;
