-- NEMPS Teacher Assistant: run this in Supabase SQL Editor.
create extension if not exists "uuid-ossp";
create type public.app_role as enum ('admin','teacher');
create type public.attendance_status as enum ('present','absent');
create type public.fee_status as enum ('paid','due','overdue');

create table public.profiles (id uuid primary key references auth.users(id) on delete cascade, full_name text not null, role app_role not null default 'teacher', phone text, avatar_url text, created_at timestamptz not null default now());
create table public.classes (id uuid primary key default uuid_generate_v4(), name text not null, section text not null, academic_year text not null, unique(name,section,academic_year));
create table public.teacher_classes (teacher_id uuid references public.profiles(id) on delete cascade, class_id uuid references public.classes(id) on delete cascade, primary key(teacher_id,class_id));
create table public.students (id uuid primary key default uuid_generate_v4(), class_id uuid not null references public.classes(id), roll_no text not null, full_name text not null, father_name text, mother_name text, whatsapp text, alternate_phone text, dob date, address text, photo_url text, fee_status fee_status not null default 'due', active boolean not null default true, created_at timestamptz not null default now(), unique(class_id,roll_no));
create table public.attendance (id text primary key, class_id uuid not null references public.classes(id), student_id uuid not null references public.students(id), date date not null, status attendance_status not null, marked_by uuid references public.profiles(id), updated_at timestamptz not null default now(), unique(student_id,date));
create table public.homework (id uuid primary key default uuid_generate_v4(), class_id uuid not null references public.classes(id), subject text not null check(subject in ('Math','English','Hindi','Science','SST','Computer','GK','Others')), details text not null, due_date date, posted_by uuid references public.profiles(id), created_at timestamptz not null default now());
create table public.homework_status (homework_id uuid references public.homework(id) on delete cascade, student_id uuid references public.students(id) on delete cascade, status text not null check(status in ('completed','pending','not_checked')) default 'not_checked', primary key(homework_id,student_id));
create table public.fees (id uuid primary key default uuid_generate_v4(), student_id uuid references public.students(id) on delete cascade, amount numeric(10,2) not null, due_date date not null, paid_at timestamptz, reminder_history jsonb not null default '[]');
create table public.notices (id uuid primary key default uuid_generate_v4(), title text not null, body text not null, category text not null, audience_class_id uuid references public.classes(id), published_by uuid references public.profiles(id), published_at timestamptz not null default now());
create table public.message_templates (id uuid primary key default uuid_generate_v4(), name text not null, body text not null, category text not null, updated_at timestamptz not null default now());

alter table public.profiles enable row level security; alter table public.classes enable row level security; alter table public.teacher_classes enable row level security; alter table public.students enable row level security; alter table public.attendance enable row level security; alter table public.homework enable row level security; alter table public.homework_status enable row level security; alter table public.fees enable row level security; alter table public.notices enable row level security; alter table public.message_templates enable row level security;
create function public.is_admin() returns boolean language sql stable security definer set search_path=public as $$ select exists(select 1 from profiles where id=auth.uid() and role='admin') $$;
create function public.can_access_class(cid uuid) returns boolean language sql stable security definer set search_path=public as $$ select is_admin() or exists(select 1 from teacher_classes where teacher_id=auth.uid() and class_id=cid) $$;
create policy "profile own" on profiles for select using (id=auth.uid() or is_admin());
create policy "classes assigned" on classes for select using (can_access_class(id));
create policy "assignments own" on teacher_classes for select using (teacher_id=auth.uid() or is_admin());
create policy "students assigned" on students for select using (can_access_class(class_id));
create policy "attendance class" on attendance for all using (can_access_class(class_id)) with check (can_access_class(class_id));
create policy "homework class" on homework for all using (can_access_class(class_id)) with check (can_access_class(class_id));
create policy "status teachers" on homework_status for all using (exists(select 1 from homework h where h.id=homework_id and can_access_class(h.class_id))) with check (exists(select 1 from homework h where h.id=homework_id and can_access_class(h.class_id)));
create policy "fees access class" on fees for select using (is_admin() or exists(select 1 from students s where s.id=student_id and can_access_class(s.class_id)));
create policy "notices read" on notices for select using (audience_class_id is null or can_access_class(audience_class_id));
create policy "templates admin" on message_templates for all using (is_admin()) with check (is_admin());
-- Storage: create private bucket 'student-photos'; add matching object policies before enabling uploads.
