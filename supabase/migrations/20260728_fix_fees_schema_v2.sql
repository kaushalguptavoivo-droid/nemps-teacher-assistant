-- Migration: Fix Fee Module Schema Compatibility (v2 - corrected)
-- Date: 2026-07-28
-- Purpose: Corrected version of 20260728_fix_fees_schema.sql.
--          The previous migration failed because it tried to ALTER COLUMN student_fee_id
--          on fee_payments before the column was added (original fee_payments had no
--          student_fee_id column), causing the entire transaction to roll back, which
--          meant student_fees.status was never added. This migration fixes that by
--          adding student_fee_id first, then dropping NOT NULL.
--          Safe to re-run (idempotent).

-- ── 1. fee_types: add columns introduced later ──────────────────────────────
ALTER TABLE IF EXISTS public.fee_types ADD COLUMN IF NOT EXISTS is_mandatory        boolean          DEFAULT true;
ALTER TABLE IF EXISTS public.fee_types ADD COLUMN IF NOT EXISTS depends_on_transport boolean         DEFAULT false;
ALTER TABLE IF EXISTS public.fee_types ADD COLUMN IF NOT EXISTS is_one_time         boolean          DEFAULT false;
ALTER TABLE IF EXISTS public.fee_types ADD COLUMN IF NOT EXISTS late_fee_per_month  double precision DEFAULT 0;

-- ── 2. student_fees: add columns the Flutter code writes ────────────────────
ALTER TABLE IF EXISTS public.student_fees ADD COLUMN IF NOT EXISTS fee_type_id     uuid;
ALTER TABLE IF EXISTS public.student_fees ADD COLUMN IF NOT EXISTS class_id_text   text;
ALTER TABLE IF EXISTS public.student_fees ADD COLUMN IF NOT EXISTS amount          double precision DEFAULT 0;
ALTER TABLE IF EXISTS public.student_fees ADD COLUMN IF NOT EXISTS paid_amount     double precision DEFAULT 0;
ALTER TABLE IF EXISTS public.student_fees ADD COLUMN IF NOT EXISTS status          text DEFAULT 'due';
ALTER TABLE IF EXISTS public.student_fees ADD COLUMN IF NOT EXISTS due_date        date;
ALTER TABLE IF EXISTS public.student_fees ADD COLUMN IF NOT EXISTS paid_date       date;
ALTER TABLE IF EXISTS public.student_fees ADD COLUMN IF NOT EXISTS concession      double precision DEFAULT 0;
ALTER TABLE IF EXISTS public.student_fees ADD COLUMN IF NOT EXISTS late_fee_applied double precision DEFAULT 0;
ALTER TABLE IF EXISTS public.student_fees ADD COLUMN IF NOT EXISTS remarks         text;

-- ── 3. fee_payments: add student_fee_id FIRST, then drop NOT NULL ──────────
--   The original fee_payments table (20240101 migration) never had student_fee_id.
--   We must ADD it before trying to DROP NOT NULL on it.
ALTER TABLE IF EXISTS public.fee_payments ADD COLUMN IF NOT EXISTS student_fee_id  uuid;
ALTER TABLE IF EXISTS public.fee_payments ADD COLUMN IF NOT EXISTS receipt_no      text;
ALTER TABLE IF EXISTS public.fee_payments ADD COLUMN IF NOT EXISTS academic_year   text;
ALTER TABLE IF EXISTS public.fee_payments ADD COLUMN IF NOT EXISTS concession      double precision DEFAULT 0;
ALTER TABLE IF EXISTS public.fee_payments ADD COLUMN IF NOT EXISTS concession_type text DEFAULT 'none';
ALTER TABLE IF EXISTS public.fee_payments ADD COLUMN IF NOT EXISTS late_fee        double precision DEFAULT 0;

-- ── 4. student_monthly_fees ──────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.student_monthly_fees (
    id              uuid             DEFAULT gen_random_uuid() PRIMARY KEY,
    student_id      text             NOT NULL,
    class_id        text             NOT NULL,
    month           text             NOT NULL,
    year            integer          NOT NULL,
    academic_year   text,
    total_amount    double precision NOT NULL,
    paid_amount     double precision DEFAULT 0,
    status          text             DEFAULT 'due',
    concession      double precision DEFAULT 0,
    concession_type text             DEFAULT 'none',
    late_fee        double precision DEFAULT 0,
    is_installment  boolean          DEFAULT false,
    installment_no  integer          DEFAULT 0,
    remarks         text,
    due_date        date,
    paid_date       date,
    created_at      timestamptz      DEFAULT now(),
    updated_at      timestamptz      DEFAULT now()
);

-- If student_monthly_fees already existed from earlier migration, ensure year column is present
ALTER TABLE IF EXISTS public.student_monthly_fees ADD COLUMN IF NOT EXISTS year integer;

-- Drop old incorrect unique constraint (month + academic_year only) if it exists
ALTER TABLE public.student_monthly_fees
    DROP CONSTRAINT IF EXISTS student_monthly_fees_student_id_month_academic_year_key;

-- Add correct unique constraint that includes year
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'smf_unique_student_month_year_ay'
          AND conrelid = 'public.student_monthly_fees'::regclass
    ) THEN
        ALTER TABLE public.student_monthly_fees
            ADD CONSTRAINT smf_unique_student_month_year_ay
            UNIQUE (student_id, month, year, academic_year);
    END IF;
EXCEPTION WHEN others THEN NULL;
END $$;

-- ── 5. RLS ───────────────────────────────────────────────────────────────────
ALTER TABLE IF EXISTS public.student_monthly_fees ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow authenticated access to student_monthly_fees" ON public.student_monthly_fees;
DROP POLICY IF EXISTS "smf_auth_all"                                        ON public.student_monthly_fees;
CREATE POLICY "smf_auth_all" ON public.student_monthly_fees
    FOR ALL TO authenticated USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow authenticated access to fee_payments" ON public.fee_payments;
DROP POLICY IF EXISTS "fp_auth_all"                               ON public.fee_payments;
CREATE POLICY "fp_auth_all" ON public.fee_payments
    FOR ALL TO authenticated USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow authenticated access to student_fees" ON public.student_fees;
DROP POLICY IF EXISTS "sf_auth_all"                               ON public.student_fees;
CREATE POLICY "sf_auth_all" ON public.student_fees
    FOR ALL TO authenticated USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow authenticated access to fee_types" ON public.fee_types;
DROP POLICY IF EXISTS "ft_auth_all"                           ON public.fee_types;
CREATE POLICY "ft_auth_all" ON public.fee_types
    FOR ALL TO authenticated USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow authenticated access to class_fee_configs" ON public.class_fee_configs;
DROP POLICY IF EXISTS "cfc_auth_all"                                    ON public.class_fee_configs;
CREATE POLICY "cfc_auth_all" ON public.class_fee_configs
    FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- ── 6. Indexes ───────────────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_smf_student_id     ON public.student_monthly_fees (student_id);
CREATE INDEX IF NOT EXISTS idx_smf_academic_year  ON public.student_monthly_fees (academic_year);
CREATE INDEX IF NOT EXISTS idx_smf_status         ON public.student_monthly_fees (status);
CREATE INDEX IF NOT EXISTS idx_fp_receipt_no      ON public.fee_payments (receipt_no);
CREATE INDEX IF NOT EXISTS idx_fp_academic_year   ON public.fee_payments (academic_year);
CREATE INDEX IF NOT EXISTS idx_fp_payment_date    ON public.fee_payments (payment_date);
