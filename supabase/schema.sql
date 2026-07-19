-- NEMPS Teacher Assistant: run this in Supabase SQL Editor.
create extension if not exists "uuid-ossp";
create type public.app_role as enum ('admin','teacher');
create type public.attendance_status as enum ('present','absent');
create type public.fee_status as enum ('paid','due','overdue');

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null,
  role app_role not null default 'teacher',
  phone text,
  avatar_url text,
  created_at timestamptz default now()
);

create table public.classes (
  id uuid primary key default uuid_generate_v4(),
  name text not null,
  section text not null,
  academic_year text not null,
  unique(name,section,academic_year)
);

create table public.teacher_classes (
  teacher_id uuid references public.profiles(id) on delete cascade,
  class_id uuid references public.classes(id) on delete cascade,
  primary key(teacher_id,class_id)
);

create table public.students (
  id uuid primary key default uuid_generate_v4(),
  class_id uuid not null references public.classes(id),
  roll_no text not null,
  full_name text not null,
  father_name text,
  whatsapp text,
  dob date,
  fee_status fee_status default 'due',
  photo_url text,
  active boolean default true,
  unique(class_id,roll_no)
);

create table public.attendance (
  id text primary key,
  class_id uuid not null references public.classes(id),
  student_id uuid not null references public.students(id) on delete cascade,
  date date not null,
  status attendance_status not null,
  marked_by uuid references public.profiles(id),
  marked_at timestamptz default now(),
  unique(student_id,date)
);

create table public.homework (
  id uuid primary key default uuid_generate_v4(),
  class_id uuid not null references public.classes(id),
  subject text not null check(subject in ('Math','English','Hindi','Science','Social Studies')),
  description text,
  assigned_date date default now(),
  assigned_by uuid references public.profiles(id)
);

create table public.homework_status (
  id uuid primary key default uuid_generate_v4(),
  homework_id uuid not null references public.homework(id) on delete cascade,
  student_id uuid not null references public.students(id) on delete cascade,
  status text not null check(status in ('completed','incomplete','not_checked')),
  marked_by uuid references public.profiles(id),
  marked_at timestamptz default now(),
  unique(homework_id,student_id)
);

create table public.teacher_activity (
  id uuid primary key default uuid_generate_v4(),
  teacher_id uuid not null references public.profiles(id) on delete cascade,
  class_id uuid not null references public.classes(id),
  activity_type text not null check(activity_type in ('attendance_marked','homework_marked','whatsapp_sent','notice_sent')),
  activity_date date default now(),
  details jsonb,
  created_at timestamptz default now()
);

create table public.notices (
  id uuid primary key default uuid_generate_v4(),
  title text not null,
  body text not null,
  audience_class_id uuid references public.classes(id),
  audience_student_id uuid references public.students(id),
  created_by uuid references public.profiles(id),
  created_at timestamptz default now()
);

alter table public.profiles enable row level security;
alter table public.classes enable row level security;
alter table public.teacher_classes enable row level security;
alter table public.students enable row level security;
alter table public.attendance enable row level security;
alter table public.homework enable row level security;
alter table public.homework_status enable row level security;
alter table public.teacher_activity enable row level security;
alter table public.notices enable row level security;

create function public.is_admin() returns boolean language sql stable security definer set search_path=public as $$ select exists(select 1 from profiles where id=auth.uid() and role='admin') $$;
create function public.can_access_class(cid uuid) returns boolean language sql stable security definer set search_path=public as $$ select is_admin() or exists(select 1 from teacher_classes where teacher_id=auth.uid() and class_id=cid) $$;

-- Profiles policies
create policy "profile own" on profiles for select using (id=auth.uid() or is_admin());
create policy "profile admin update" on profiles for update using (is_admin());

-- Classes policies
create policy "classes assigned" on classes for select using (can_access_class(id));

-- Teacher classes policies
create policy "assignments own" on teacher_classes for select using (teacher_id=auth.uid() or is_admin());
create policy "assignments admin" on teacher_classes for all using (is_admin()) with check (is_admin());

-- Students policies
create policy "students assigned" on students for select using (can_access_class(class_id));
create policy "students admin" on students for all using (is_admin()) with check (is_admin());

-- Attendance policies
create policy "attendance class" on attendance for all using (can_access_class(class_id)) with check (can_access_class(class_id));

-- Homework policies
create policy "homework class" on homework for all using (can_access_class(class_id)) with check (can_access_class(class_id));

-- Homework status policies
create policy "status teachers" on homework_status for all using (exists(select 1 from homework h where h.id=homework_id and can_access_class(h.class_id))) with check (exists(select 1 from homework h where h.id=homework_id and can_access_class(h.class_id)));

-- Teacher activity policies
create policy "activity own" on teacher_activity for select using (teacher_id=auth.uid() or is_admin());
create policy "activity insert" on teacher_activity for insert with check (true);
create policy "activity admin" on teacher_activity for all using (is_admin()) with check (is_admin());

-- Notices policies
create policy "notices read" on notices for select using (audience_class_id is null or can_access_class(audience_class_id) or created_by=auth.uid());
-- FIX: INSERT must use WITH CHECK, not USING (original had a bug here)
create policy "notices insert teachers" on notices for insert with check (auth.uid() is not null);
create policy "notices admin all" on notices for all using (is_admin()) with check (is_admin());
