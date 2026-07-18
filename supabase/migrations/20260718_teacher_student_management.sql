-- Run once after schema.sql. Teachers may manage students only in their assigned classes.
create policy "teachers insert students in assigned class"
on public.students for insert
with check (can_access_class(class_id));

create policy "teachers update students in assigned class"
on public.students for update
using (can_access_class(class_id))
with check (can_access_class(class_id));

-- Keep records for reports; use active=false instead of deleting a student.
