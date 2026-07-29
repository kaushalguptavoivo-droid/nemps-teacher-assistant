-- Fee Receipt Improvements + Partial Payment Support
-- Adds: father_name, roll_no, payment_type to fee_payments so receipts can
-- show the student's roll no / father's name, and so we can tell full vs
-- partial payments apart when reprinting a receipt later.
-- Safe to re-run (idempotent).

ALTER TABLE IF EXISTS public.fee_payments
  ADD COLUMN IF NOT EXISTS father_name  text,
  ADD COLUMN IF NOT EXISTS roll_no      text,
  ADD COLUMN IF NOT EXISTS payment_type text DEFAULT 'full';

-- Backfill payment_type for old rows: if the payment amount was less than
-- what was due for the covered months (i.e. the month ended up 'partial'),
-- old receipts had no way of recording that — leave those NULL/'full' as a
-- best-effort default since we cannot reconstruct the original intent.
UPDATE public.fee_payments
  SET payment_type = 'full'
  WHERE payment_type IS NULL;
