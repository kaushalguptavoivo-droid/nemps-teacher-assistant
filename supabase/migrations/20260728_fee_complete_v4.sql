-- Migration: Complete Fee Management Fix (v4)
-- Date: 2026-07-28
-- Adds: months_covered, student_name, class_name to fee_payments
-- Fixes: receipt reprinting, payment tracking, school info storage
-- Safe to re-run (idempotent)

-- ── fee_payments: add missing columns for receipt/reprint info ────────────────
ALTER TABLE IF EXISTS public.fee_payments
  ADD COLUMN IF NOT EXISTS months_covered text,
  ADD COLUMN IF NOT EXISTS student_name   text,
  ADD COLUMN IF NOT EXISTS class_name     text,
  ADD COLUMN IF NOT EXISTS school_name    text DEFAULT 'NEMPS School';

-- ── fee_payments: backfill receipt_no for any old rows missing it ─────────────
UPDATE public.fee_payments
  SET receipt_no = CONCAT(
        'R-',
        EXTRACT(YEAR FROM COALESCE(payment_date, created_at::date))::text,
        '-',
        LPAD((EXTRACT(EPOCH FROM created_at)::bigint % 9999 + 1)::text, 4, '0')
      )
  WHERE receipt_no IS NULL OR receipt_no = '';

-- ── fee_payments: backfill months_covered from remarks where possible ─────────
UPDATE public.fee_payments
  SET months_covered = REPLACE(remarks, 'Months: ', '')
  WHERE months_covered IS NULL
    AND remarks IS NOT NULL
    AND remarks LIKE 'Months:%';

-- ── Unique index on receipt_no (drop old one if exists, recreate) ─────────────
DROP INDEX IF EXISTS public.idx_fp_receipt_no;
CREATE UNIQUE INDEX IF NOT EXISTS idx_fp_receipt_no_unique
  ON public.fee_payments (receipt_no)
  WHERE receipt_no IS NOT NULL AND receipt_no <> '';

-- ── Performance indexes ───────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_fp_student_id_year
  ON public.fee_payments (student_id, academic_year);

CREATE INDEX IF NOT EXISTS idx_fp_payment_date_year
  ON public.fee_payments (payment_date, academic_year);

CREATE INDEX IF NOT EXISTS idx_smf_student_year
  ON public.student_monthly_fees (student_id, academic_year);

CREATE INDEX IF NOT EXISTS idx_smf_month_year
  ON public.student_monthly_fees (month, year);

-- ── RLS policies (ensure they exist) ─────────────────────────────────────────
ALTER TABLE IF EXISTS public.fee_payments ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "fp_auth_all"  ON public.fee_payments;
CREATE POLICY "fp_auth_all" ON public.fee_payments
  FOR ALL TO authenticated USING (true) WITH CHECK (true);
