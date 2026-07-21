-- Migration: report_templates
-- Purpose: Controls report card layout and school branding.
--          Multiple templates supported (Half Yearly, Annual, Nursery, etc.).
--          Nothing about layout is hardcoded — all comes from this table.
-- Rollback: DROP TABLE IF EXISTS public.report_templates CASCADE;

-- CREATE
create table public.report_templates (
  id               uuid primary key default uuid_generate_v4(),
  template_name    text not null,           -- "Half Yearly","Annual","Nursery"
  academic_year    text not null,
  school_name      text not null,
  school_address   text,
  logo_url         text,
  principal_name   text,
  paper_size       text not null default 'A4' check (paper_size in ('A4','Legal','Letter','Custom')),
  orientation      text not null default 'portrait' check (orientation in ('portrait','landscape')),
  show_attendance  boolean not null default true,
  show_grade       boolean not null default true,
  show_percentage  boolean not null default true,
  show_rank        boolean not null default true,
  show_remarks     boolean not null default true,
  watermark_text   text,
  header_text      text,
  footer_text      text,
  signature_label  text,                   -- e.g. "Principal's Signature"
  is_default       boolean not null default false,
  created_by       uuid references public.profiles(id),
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  unique (academic_year, template_name)
);

-- Only one template can be default per academic_year
create unique index report_templates_one_default
  on public.report_templates (academic_year, is_default)
  where is_default = true;

create trigger report_templates_updated_at
  before update on public.report_templates
  for each row execute procedure public.set_updated_at();

-- INDEX
create index report_templates_year_idx     on public.report_templates (academic_year);
create index report_templates_default_idx  on public.report_templates (academic_year, is_default);

-- RLS
alter table public.report_templates enable row level security;

create policy "report_templates_read_all"
  on public.report_templates for select
  using (auth.uid() is not null);

create policy "report_templates_admin_all"
  on public.report_templates for all
  using (public.is_admin())
  with check (public.is_admin());

-- ROLLBACK
-- DROP TABLE IF EXISTS public.report_templates CASCADE;
