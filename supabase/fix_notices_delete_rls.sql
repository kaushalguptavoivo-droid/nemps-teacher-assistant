-- ============================================================
-- NEMPS Fix: Notices table DELETE permission for admin
-- Supabase SQL Editor mein copy-paste karke RUN karo
-- ============================================================

-- Drop any existing conflicting delete policies
drop policy if exists "notices delete" on public.notices;
drop policy if exists "notice admin delete" on public.notices;
drop policy if exists "notices_delete_admin" on public.notices;
drop policy if exists "notices admin delete" on public.notices;
drop policy if exists "notices admin all" on public.notices;

-- Admin can do everything on notices (create, read, update, delete)
create policy "notices admin all" on public.notices
  for all using (is_admin()) with check (is_admin());

-- Teachers can read notices meant for their class or all classes
drop policy if exists "notices teacher read" on public.notices;
create policy "notices teacher read" on public.notices
  for select using (
    auth.uid() is not null
    and (audience_class_id is null
         or audience_class_id in (
           select class_id from teacher_classes where teacher_id = auth.uid()
         ))
  );

-- Done! Admin ab notices delete kar sakta hai.
