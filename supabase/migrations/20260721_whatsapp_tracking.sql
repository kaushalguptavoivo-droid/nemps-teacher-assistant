-- WhatsApp notification tracking & group links
-- Run this in Supabase SQL Editor after schema.sql

-- WhatsApp group links per class (one link per class, stored once)
create table if not exists public.class_whatsapp_groups (
  class_id uuid primary key references public.classes(id) on delete cascade,
  group_link text not null,
  updated_by uuid references public.profiles(id),
  updated_at timestamptz default now()
);
alter table public.class_whatsapp_groups enable row level security;
create policy "wa_groups_access" on class_whatsapp_groups for all
  using (can_access_class(class_id)) with check (can_access_class(class_id));

-- WhatsApp notification log (track who was notified and when)
create table if not exists public.whatsapp_notifications (
  id uuid primary key default uuid_generate_v4(),
  class_id uuid not null references public.classes(id),
  student_id uuid references public.students(id) on delete cascade,
  notification_date date not null,
  notification_type text not null check(notification_type in ('absent','present','homework')),
  subject text,
  notified_at timestamptz default now(),
  notified_by uuid references public.profiles(id),
  unique(student_id, notification_date, notification_type, subject)
);
alter table public.whatsapp_notifications enable row level security;
create policy "wa_notif_access" on whatsapp_notifications for all
  using (can_access_class(class_id)) with check (can_access_class(class_id));

-- Fix: teacher insert policy scoped to own records
drop policy if exists "activity insert" on teacher_activity;
create policy "activity insert" on teacher_activity
  for insert with check (teacher_id = auth.uid());
