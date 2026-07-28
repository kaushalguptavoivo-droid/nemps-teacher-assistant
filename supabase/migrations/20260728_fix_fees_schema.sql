-- Migration: Fix Fee Module Schema Compatibility
-- Date: 2026-07-28
-- Purpose: Align fee tables with Flutter app's actual column requirements.
--          Safe to re-run (idempotent).

-- ── 1. fee_types: add columns introduced later ──────────────────────────────
ALTER TABLE IF EXISTS public.fee_types ADD COLUMN IF NOT EXISTS is_mandatory        boolean          DEFAULT true;
ALTER TABLE IF EXISTS public.fee_types ADD COLUMN IF NOT EXISTS depends_on_transport boolean         DEFAULT false;
ALTER TABLE IF EXISTS public.fee_types ADD COLUMN IF NOT EXISTS is_one_time         boolean          DEFAULT false;
ALTER TABLE IF EXISTS public.fee_types ADD COLUMN IF NOT EXISTS late_fee_per_month  double precision DEFAULT 0;

-- ── 2. student_fees: add columns the Flutter code writes ────────────────────
--   The 2024-01 migration created this table with different columns;
--   the 2026-07-24 migration may not have replaced them.
ALTER TABLE IF EXISTS public.student_fees ADD COLUMN IF NOT EXISTS fee_type_id     uuid;
ALTER TABLE IF EXISTS public.student_fees ADD COLUMN IF NOT EXISTS class_id_text   text;   -- shadow column (class_id may be UUID FK)
ALTER TABLE IF EXISTS public.student_fees ADD COLUMN IF NOT EXISTS amount          double precision DEFAULT 0;
ALTER TABLE IF EXISTS public.student_fees ADD COLUMN IF NOT EXISTS paid_amount     double precision DEFAULT 0;
ALTER TABLE IF EXISTS public.student_fees ADD COLUMN IF NOT EXISTS status          text DEFAULT 'due';
ALTER TABLE IF EXISTS public.student_fees ADD COLUMN IF NOT EXISTS due_date        date;
ALTER TABLE IF EXISTS public.student_fees ADD COLUMN IF NOT EXISTS paid_date       date;
ALTER TABLE IF EXISTS public.student_fees ADD COLUMN IF NOT EXISTS concession      double precision DEFAULT 0;
ALTER TABLE IF EXISTS public.student_fees ADD COLUMN IF NOT EXISTS late_fee_applied double precision DEFAULT 0;
ALTER TABLE IF EXISTS public.student_fees ADD COLUMN IF NOT EXISTS remarks         text;

-- ── 3. fee_payments: make student_fee_id nullable, add missing columns ──────
ALTER TABLE IF EXISTS public.fee_payments ALTER COLUMN student_fee_id DROP NOT NULL;
ALTER TABLE IF EXISTS public.fee_payments ADD COLUMN IF NOT EXISTS receipt_no      text;
ALTER TABLE IF EXISTS public.fee_payments ADD COLUMN IF NOT EXISTS academic_year   text;
ALTER TABLE IF EXISTS public.fee_payments ADD COLUMN IF NOT EXISTS concession      double precision DEFAULT 0;
ALTER TABLE IF EXISTS public.fee_payments ADD COLUMN IF NOT EXISTS concession_type text DEFAULT 'none';
ALTER TABLE IF EXISTS public.fee_payments ADD COLUMN IF NOT EXISTS late_fee        double precision DEFAULT 0;

-- ── 4. student_monthly_fees ──────────────────────────────────────────────────
--   Create from scratch if the old migration's version exists (wrong unique key).
--   We drop the bad unique constraint first and add a correct one.
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

-- Drop duplicate/old policies before recreating
DROP POLICY IF EXISTS "Allow authenticated access to student_monthly_fees" ON public.student_monthly_fees;
DROP POLICY IF EXISTS "smf_auth_all"                                        ON public.student_monthly_fees;
CREATE POLICY "smf_auth_all" ON public.student_monthly_fees
    FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- Ensure fee_payments policies exist
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
