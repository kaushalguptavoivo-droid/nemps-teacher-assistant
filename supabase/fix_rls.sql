-- ============================================================
-- NEMPS Fix: RLS policies + schema corrections
-- Supabase SQL Editor mein copy-paste karke RUN karo
-- ============================================================

-- 1. classes table: academic_year optional karo (tha NOT NULL without default)
alter table public.classes alter column academic_year set default '';
alter table public.classes alter column academic_year drop not null;

-- 2. classes table: admin ko INSERT/UPDATE/DELETE allow karo
--    (pehle sirf SELECT tha, isliye class add nahi hoti thi)
drop policy if exists "classes assigned" on public.classes;
create policy "classes read"      on public.classes for select using (auth.uid() is not null);
create policy "classes admin all" on public.classes for all    using (is_admin()) with check (is_admin());

-- 3. students table: teacher apni class ke students add/edit/remove kar sake
--    (pehle sirf SELECT tha)
drop policy if exists "students teacher insert" on public.students;
drop policy if exists "students teacher update" on public.students;
drop policy if exists "students teacher delete" on public.students;
create policy "students teacher insert" on public.students
  for insert with check (can_access_class(class_id));
create policy "students teacher update" on public.students
  for update using (can_access_class(class_id)) with check (can_access_class(class_id));
create policy "students teacher delete" on public.students
  for delete using (can_access_class(class_id));

-- 4. profiles: admin saare teachers dekh sake (getAllTeachers query ke liye)
drop policy if exists "profile own" on public.profiles;
create policy "profile read" on public.profiles
  for select using (id = auth.uid() or is_admin());

-- 5. teacher_classes: admin assign/unassign kar sake (already exists but verify)
drop policy if exists "assignments admin" on public.teacher_classes;
create policy "assignments admin" on public.teacher_classes
  for all using (is_admin()) with check (is_admin());

-- Done! Ab app se class, student, teacher sab manage ho sakta hai.
