-- Fix: Enable Supabase Realtime for all required tables.
-- Run this in Supabase SQL Editor if you see RealtimeSubscribeException errors.
-- Each ALTER is wrapped so it doesn't fail if the table is already published.

do $$
declare
  t text;
begin
  foreach t in array array[
    'teacher_classes',
    'students',
    'homework',
    'homework_status',
    'notices',
    'classes',
    'profiles',
    'attendance',
    'academic_sessions',
    'whatsapp_notifications',
    'class_whatsapp_groups',
    'exam_configs',
    'exam_terms',
    'class_subjects',
    'exam_marks',
    'grade_configs',
    'report_templates',
    'student_remarks',
    'promotion_records'
  ]
  loop
    begin
      execute format('alter publication supabase_realtime add table %I', t);
    exception when others then
      -- Table may not exist or already in publication; skip silently.
      null;
    end;
  end loop;
end;
$$;

-- ── Active Session 2026-27 ────────────────────────────────────────────────────
-- Creates the 2026-27 academic session and activates it if not already done.

do $$
declare
  v_session_id uuid;
  v_admin_id   uuid;
begin
  -- Find an admin user (or any user) to use as created_by
  select id into v_admin_id from profiles where role = 'admin' limit 1;
  if v_admin_id is null then
    select id into v_admin_id from profiles limit 1;
  end if;

  -- Check if the session already exists
  select id into v_session_id
    from academic_sessions
   where label = '2026-27'
   limit 1;

  if v_session_id is null then
    -- Create it and activate immediately
    insert into academic_sessions (label, is_active, created_by)
    values ('2026-27', true, v_admin_id)
    returning id into v_session_id;
  else
    -- Make sure it is active
    update academic_sessions set is_active = true where id = v_session_id;
  end if;

  -- Deactivate every other session so there is exactly one active session
  update academic_sessions
     set is_active = false
   where id <> v_session_id;
end;
$$;
