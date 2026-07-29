-- Fee Payment RPC Functions
-- The Flutter app calls `collect_fee_payment` (record a payment + mark the
-- covered months paid/partial) and `delete_fee_payment` (undo a payment and
-- reverse whatever it applied) via supabase.rpc(...). Neither function
-- existed in the database — every call was failing at runtime. This
-- migration creates both as a single atomic transaction each, so a payment
-- and its month-status updates can never get out of sync, in either
-- direction.
-- Safe to re-run (CREATE OR REPLACE).

-- ── collect_fee_payment ─────────────────────────────────────────────────────
-- p_payment: jsonb matching FeePayment.toInsertMap() (student_id, amount,
--   months_covered as "April 2024, May 2024", concession, etc.)
-- p_month_labels: text[] of the same months, e.g. ['April 2024','May 2024']
-- Splits amount/concession evenly across the given months (matching the
-- Dart-side markMonthlyFeesAsPaid logic) and returns the new payment id.

CREATE OR REPLACE FUNCTION public.collect_fee_payment(
  p_payment jsonb,
  p_month_labels text[]
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_payment_id uuid := gen_random_uuid();
  v_student_id text := p_payment->>'student_id';
  v_academic_year text := p_payment->>'academic_year';
  v_total_amount numeric := COALESCE((p_payment->>'amount')::numeric, 0);
  v_total_concession numeric := COALESCE((p_payment->>'concession')::numeric, 0);
  v_month_count integer := GREATEST(array_length(p_month_labels, 1), 1);
  v_per_amount numeric := v_total_amount / v_month_count;
  v_per_concession numeric := v_total_concession / v_month_count;
  v_label text;
  v_month text;
  v_year integer;
  v_row public.student_monthly_fees%ROWTYPE;
  v_new_paid numeric;
  v_new_concession numeric;
  v_new_status text;
BEGIN
  IF p_month_labels IS NULL OR array_length(p_month_labels, 1) IS NULL THEN
    RAISE EXCEPTION 'At least one month must be selected';
  END IF;

  INSERT INTO public.fee_payments (
    id, student_fee_id, student_id, amount, payment_date, payment_method,
    receipt_no, academic_year, concession, concession_type, late_fee,
    remarks, months_covered, payment_type, student_name, class_name,
    school_name, father_name, roll_no, created_at
  ) VALUES (
    v_payment_id,
    (p_payment->>'student_fee_id')::uuid,
    v_student_id::uuid,
    v_total_amount,
    COALESCE((p_payment->>'payment_date')::date, CURRENT_DATE),
    COALESCE(p_payment->>'payment_method', 'cash'),
    p_payment->>'receipt_no',
    v_academic_year,
    v_total_concession,
    COALESCE(p_payment->>'concession_type', 'none'),
    COALESCE((p_payment->>'late_fee')::numeric, 0),
    p_payment->>'remarks',
    p_payment->>'months_covered',
    COALESCE(p_payment->>'payment_type', 'full'),
    p_payment->>'student_name',
    p_payment->>'class_name',
    p_payment->>'school_name',
    p_payment->>'father_name',
    p_payment->>'roll_no',
    now()
  );

  FOREACH v_label IN ARRAY p_month_labels LOOP
    v_month := split_part(trim(v_label), ' ', 1);
    v_year := NULLIF(split_part(trim(v_label), ' ', 2), '')::integer;
    IF v_year IS NULL THEN
      CONTINUE;
    END IF;

    SELECT * INTO v_row
    FROM public.student_monthly_fees
    WHERE student_id = v_student_id AND month = v_month AND year = v_year
    LIMIT 1;

    IF NOT FOUND THEN
      CONTINUE;
    END IF;

    v_new_paid := COALESCE(v_row.paid_amount, 0) + v_per_amount;
    v_new_concession := COALESCE(v_row.concession, 0) + v_per_concession;
    v_new_status := CASE
      WHEN v_new_paid >= (v_row.amount - v_new_concession) THEN 'paid'
      ELSE 'partial'
    END;

    UPDATE public.student_monthly_fees
    SET paid_amount = v_new_paid,
        status = v_new_status,
        concession = v_new_concession,
        is_paid = (v_new_status = 'paid'),
        paid_date = CURRENT_DATE,
        updated_at = now()
    WHERE id = v_row.id;
  END LOOP;

  RETURN v_payment_id;
END;
$$;

-- ── delete_fee_payment ──────────────────────────────────────────────────────
-- Reverses a payment: subtracts its per-month share back out of every month
-- it covered (paid_amount/concession), recomputes status ('paid' / 'partial'
-- / 'due'), never lets paid_amount go negative, then removes the payment
-- row. This is what powers "delete from receipt history" — deleting a
-- mistaken payment correctly puts the fee back to due/partial instead of
-- leaving it stuck as paid with no matching receipt.

CREATE OR REPLACE FUNCTION public.delete_fee_payment(
  p_payment_id uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_payment public.fee_payments%ROWTYPE;
  v_month_labels text[];
  v_month_count integer;
  v_per_amount numeric;
  v_per_concession numeric;
  v_label text;
  v_month text;
  v_year integer;
  v_row public.student_monthly_fees%ROWTYPE;
  v_new_paid numeric;
  v_new_concession numeric;
  v_new_status text;
BEGIN
  SELECT * INTO v_payment
  FROM public.fee_payments
  WHERE id = p_payment_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Payment % not found', p_payment_id;
  END IF;

  IF v_payment.months_covered IS NOT NULL AND trim(v_payment.months_covered) <> '' THEN
    SELECT array_agg(trim(m)) INTO v_month_labels
    FROM unnest(string_to_array(v_payment.months_covered, ',')) AS m;
  END IF;

  IF v_month_labels IS NOT NULL AND array_length(v_month_labels, 1) > 0 THEN
    v_month_count := array_length(v_month_labels, 1);
    v_per_amount := v_payment.amount / v_month_count;
    v_per_concession := COALESCE(v_payment.concession, 0) / v_month_count;

    FOREACH v_label IN ARRAY v_month_labels LOOP
      v_month := split_part(v_label, ' ', 1);
      v_year := NULLIF(split_part(v_label, ' ', 2), '')::integer;
      IF v_year IS NULL THEN
        CONTINUE;
      END IF;

      SELECT * INTO v_row
      FROM public.student_monthly_fees
      WHERE student_id = v_payment.student_id::text AND month = v_month AND year = v_year
      LIMIT 1;

      IF NOT FOUND THEN
        CONTINUE;
      END IF;

      v_new_paid := GREATEST(COALESCE(v_row.paid_amount, 0) - v_per_amount, 0);
      v_new_concession := GREATEST(COALESCE(v_row.concession, 0) - v_per_concession, 0);
      v_new_status := CASE
        WHEN v_new_paid <= 0 THEN 'due'
        WHEN v_new_paid >= (v_row.amount - v_new_concession) THEN 'paid'
        ELSE 'partial'
      END;

      UPDATE public.student_monthly_fees
      SET paid_amount = v_new_paid,
          status = v_new_status,
          concession = v_new_concession,
          is_paid = (v_new_status = 'paid'),
          paid_date = CASE WHEN v_new_status = 'due' THEN NULL ELSE v_row.paid_date END,
          updated_at = now()
      WHERE id = v_row.id;
    END LOOP;
  END IF;

  DELETE FROM public.fee_payments WHERE id = p_payment_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.collect_fee_payment(jsonb, text[]) TO authenticated;
GRANT EXECUTE ON FUNCTION public.delete_fee_payment(uuid) TO authenticated;
