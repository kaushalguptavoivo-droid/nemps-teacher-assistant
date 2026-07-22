-- ============================================================
-- Migration: daily_work_remarks + Attendance Register RPC
-- Purpose  : Feature - Date-wise work/remarks tracking per student,
--            and a server-side pivot function for the Attendance Register.
-- Non-destructive: uses CREATE TABLE IF NOT EXISTS, ALTER TABLE ADD COLUMN IF NOT EXISTS.
-- Rollback : DROP TABLE IF EXISTS public.daily_work_remarks CASCADE;
--            DROP FUNCTION IF EXISTS public.get_attendance_register;
-- ============================================================

-- 1. daily_work_remarks table
CREATE TABLE IF NOT EXISTS public.daily_work_remarks (
  id           uuid        PRIMARY KEY DEFAULT uuid_generate_v4(),
  class_id     uuid        NOT NULL REFERENCES public.classes(id)  ON DELETE CASCADE,
  student_id   uuid        NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
  date         date        NOT NULL,
  work_done    text,
  remarks      text,
  assignment   text,
  entered_by   uuid        REFERENCES public.profiles(id),
  created_at   timestamptz NOT NULL DEFAULT now(),
  updated_at   timestamptz NOT NULL DEFAULT now(),
  UNIQUE (student_id, date)
);

-- Indexes
CREATE INDEX IF NOT EXISTS daily_work_class_date_idx ON public.daily_work_remarks (class_id, date);
CREATE INDEX IF NOT EXISTS daily_work_student_idx    ON public.daily_work_remarks (student_id);

-- Auto-update updated_at
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger
    WHERE tgname = 'daily_work_remarks_updated_at'
  ) THEN
    CREATE TRIGGER daily_work_remarks_updated_at
      BEFORE UPDATE ON public.daily_work_remarks
      FOR EACH ROW EXECUTE PROCEDURE public.set_updated_at();
  END IF;
EXCEPTION WHEN undefined_function THEN
  -- set_updated_at may not exist on all instances; skip gracefully.
  NULL;
END;
$$;

-- RLS
ALTER TABLE public.daily_work_remarks ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "work_remarks_select" ON public.daily_work_remarks;
CREATE POLICY "work_remarks_select"
  ON public.daily_work_remarks FOR SELECT
  USING (public.can_access_class(class_id));

DROP POLICY IF EXISTS "work_remarks_insert" ON public.daily_work_remarks;
CREATE POLICY "work_remarks_insert"
  ON public.daily_work_remarks FOR INSERT
  WITH CHECK (public.can_access_class(class_id));

DROP POLICY IF EXISTS "work_remarks_update" ON public.daily_work_remarks;
CREATE POLICY "work_remarks_update"
  ON public.daily_work_remarks FOR UPDATE
  USING  (public.can_access_class(class_id))
  WITH CHECK (public.can_access_class(class_id));

DROP POLICY IF EXISTS "work_remarks_admin" ON public.daily_work_remarks;
CREATE POLICY "work_remarks_admin"
  ON public.daily_work_remarks FOR ALL
  USING  (public.is_admin())
  WITH CHECK (public.is_admin());

-- ============================================================
-- 2. Supabase RPC: get_attendance_register
--    Pivots attendance rows into a 31-column matrix per student.
--    Also computes current-month present count and all-time
--    present count so the frontend doesn't need to post-process.
--
--    Call via: supabase.rpc('get_attendance_register',
--                { p_class_id: '...', p_year: 2026, p_month: 7 })
-- ============================================================
CREATE OR REPLACE FUNCTION public.get_attendance_register(
  p_class_id uuid,
  p_year     int,
  p_month    int
)
RETURNS TABLE (
  student_id              uuid,
  roll_no                 text,
  full_name               text,
  d01 text, d02 text, d03 text, d04 text, d05 text,
  d06 text, d07 text, d08 text, d09 text, d10 text,
  d11 text, d12 text, d13 text, d14 text, d15 text,
  d16 text, d17 text, d18 text, d19 text, d20 text,
  d21 text, d22 text, d23 text, d24 text, d25 text,
  d26 text, d27 text, d28 text, d29 text, d30 text,
  d31 text,
  current_month_present   int,
  all_time_present        int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Security: caller must be able to access this class.
  IF NOT public.can_access_class(p_class_id) THEN
    RAISE EXCEPTION 'Access denied';
  END IF;

  RETURN QUERY
  WITH monthly_att AS (
    SELECT a.student_id,
           EXTRACT(day FROM a.date)::int AS day_no,
           a.status::text AS status
    FROM   public.attendance a
    WHERE  a.class_id = p_class_id
      AND  EXTRACT(year  FROM a.date) = p_year
      AND  EXTRACT(month FROM a.date) = p_month
  ),
  all_time_att AS (
    SELECT a.student_id,
           COUNT(*) FILTER (WHERE a.status = 'present') AS total_present
    FROM   public.attendance a
    WHERE  a.class_id = p_class_id
    GROUP  BY a.student_id
  )
  SELECT
    s.id,
    s.roll_no,
    s.full_name,
    MAX(CASE WHEN ma.day_no = 1  THEN ma.status END),
    MAX(CASE WHEN ma.day_no = 2  THEN ma.status END),
    MAX(CASE WHEN ma.day_no = 3  THEN ma.status END),
    MAX(CASE WHEN ma.day_no = 4  THEN ma.status END),
    MAX(CASE WHEN ma.day_no = 5  THEN ma.status END),
    MAX(CASE WHEN ma.day_no = 6  THEN ma.status END),
    MAX(CASE WHEN ma.day_no = 7  THEN ma.status END),
    MAX(CASE WHEN ma.day_no = 8  THEN ma.status END),
    MAX(CASE WHEN ma.day_no = 9  THEN ma.status END),
    MAX(CASE WHEN ma.day_no = 10 THEN ma.status END),
    MAX(CASE WHEN ma.day_no = 11 THEN ma.status END),
    MAX(CASE WHEN ma.day_no = 12 THEN ma.status END),
    MAX(CASE WHEN ma.day_no = 13 THEN ma.status END),
    MAX(CASE WHEN ma.day_no = 14 THEN ma.status END),
    MAX(CASE WHEN ma.day_no = 15 THEN ma.status END),
    MAX(CASE WHEN ma.day_no = 16 THEN ma.status END),
    MAX(CASE WHEN ma.day_no = 17 THEN ma.status END),
    MAX(CASE WHEN ma.day_no = 18 THEN ma.status END),
    MAX(CASE WHEN ma.day_no = 19 THEN ma.status END),
    MAX(CASE WHEN ma.day_no = 20 THEN ma.status END),
    MAX(CASE WHEN ma.day_no = 21 THEN ma.status END),
    MAX(CASE WHEN ma.day_no = 22 THEN ma.status END),
    MAX(CASE WHEN ma.day_no = 23 THEN ma.status END),
    MAX(CASE WHEN ma.day_no = 24 THEN ma.status END),
    MAX(CASE WHEN ma.day_no = 25 THEN ma.status END),
    MAX(CASE WHEN ma.day_no = 26 THEN ma.status END),
    MAX(CASE WHEN ma.day_no = 27 THEN ma.status END),
    MAX(CASE WHEN ma.day_no = 28 THEN ma.status END),
    MAX(CASE WHEN ma.day_no = 29 THEN ma.status END),
    MAX(CASE WHEN ma.day_no = 30 THEN ma.status END),
    MAX(CASE WHEN ma.day_no = 31 THEN ma.status END),
    COALESCE(COUNT(DISTINCT CASE WHEN ma.status = 'present' THEN ma.day_no END), 0)::int,
    COALESCE(MAX(at2.total_present), 0)::int
  FROM   public.students s
  LEFT   JOIN monthly_att ma ON ma.student_id = s.id
  LEFT   JOIN all_time_att at2 ON at2.student_id = s.id
  WHERE  s.class_id = p_class_id
    AND  s.active   = true
  GROUP  BY s.id, s.roll_no, s.full_name, at2.total_present
  ORDER  BY s.roll_no;
END;
$$;
