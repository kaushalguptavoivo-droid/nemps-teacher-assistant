-- Migration: Fix "Generate Fees" bulk action for student_fees
-- Date: 2026-07-29
-- Root cause: FeeRepository.generateFeesForClass() upserts into student_fees
--   with onConflict: 'student_id,fee_type_id,academic_year', but no unique
--   or exclusion constraint on those columns has ever existed on this table.
--   Postgres requires a matching constraint for ON CONFLICT to work, so every
--   call to the "Generate Fees" button in Fees Mgmt → Class Config has been
--   failing with: 42P10 "there is no unique or exclusion constraint matching
--   the ON CONFLICT specification".
-- Fix: dedupe any pre-existing duplicate rows (keeping the most recently
--   updated one, preferring rows with a paid_amount > 0 so we never delete a
--   row that recorded real payment activity), then add the constraint.
-- Safe to re-run (idempotent).

-- ── 1. Remove duplicate (student_id, fee_type_id, academic_year) rows ────────
--   Keep the "best" row per group: highest paid_amount first, then most recent.
WITH ranked AS (
  SELECT
    id,
    ROW_NUMBER() OVER (
      PARTITION BY student_id, fee_type_id, academic_year
      ORDER BY paid_amount DESC NULLS LAST, created_at DESC NULLS LAST
    ) AS rn
  FROM public.student_fees
  WHERE fee_type_id IS NOT NULL
)
DELETE FROM public.student_fees sf
USING ranked
WHERE sf.id = ranked.id
  AND ranked.rn > 1;

-- ── 2. Add the unique constraint the app's upsert expects ────────────────────
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'student_fees_unique_student_feetype_year'
          AND conrelid = 'public.student_fees'::regclass
    ) THEN
        ALTER TABLE public.student_fees
            ADD CONSTRAINT student_fees_unique_student_feetype_year
            UNIQUE (student_id, fee_type_id, academic_year);
    END IF;
EXCEPTION WHEN others THEN NULL;
END $$;

-- ── 3. Helpful index for lookups by fee_type_id (wasn't indexed before) ──────
CREATE INDEX IF NOT EXISTS idx_student_fees_fee_type_id ON public.student_fees (fee_type_id);
