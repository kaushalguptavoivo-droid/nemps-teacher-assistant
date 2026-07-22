-- Phase 7: Promotion Engine
-- Table: promotion_records
-- Stores one promotion decision per student per class per academic year.
-- result_status is set by the system based on classResultsProvider.
-- promotion_status can be overridden by Admin.
-- Previous years' data is NEVER overwritten (academic_year scopes every row).
-- ROLLBACK: DROP TABLE IF EXISTS promotion_records;

-- ── Table ─────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS promotion_records (
  id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id           UUID NOT NULL REFERENCES students(id) ON DELETE CASCADE,
  class_id             UUID NOT NULL REFERENCES classes(id) ON DELETE CASCADE,
  academic_year        TEXT NOT NULL,                          -- e.g. "2026-27"
  result_status        TEXT NOT NULL DEFAULT 'pending'
                         CHECK (result_status IN ('pass','fail','compartment','pending')),
  promotion_status     TEXT NOT NULL DEFAULT 'pending'
                         CHECK (promotion_status IN ('promoted','not_promoted','pending')),
  promoted_to_class_id UUID REFERENCES classes(id) ON DELETE SET NULL,
  is_manual_override   BOOLEAN NOT NULL DEFAULT FALSE,
  override_reason      TEXT,
  overridden_by        UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  -- One record per student per class per year.
  UNIQUE (student_id, class_id, academic_year)
);

-- ── Indexes ───────────────────────────────────────────────────────────────────

CREATE INDEX IF NOT EXISTS idx_promotion_records_class_year
  ON promotion_records (class_id, academic_year);

CREATE INDEX IF NOT EXISTS idx_promotion_records_student
  ON promotion_records (student_id);

CREATE INDEX IF NOT EXISTS idx_promotion_records_academic_year
  ON promotion_records (academic_year);

-- ── Updated-at trigger ────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION update_promotion_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_promotion_updated_at
  BEFORE UPDATE ON promotion_records
  FOR EACH ROW EXECUTE FUNCTION update_promotion_updated_at();

-- ── Row Level Security ────────────────────────────────────────────────────────

ALTER TABLE promotion_records ENABLE ROW LEVEL SECURITY;

-- Admin: full access
CREATE POLICY "admin_all_promotion_records" ON promotion_records
  FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
        AND profiles.role = 'admin'
    )
  );

-- Teacher: read their own assigned classes only
CREATE POLICY "teacher_read_own_class_promotions" ON promotion_records
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM teacher_classes tc
      WHERE tc.teacher_id = auth.uid()
        AND tc.class_id = promotion_records.class_id
    )
  );

-- ── ROLLBACK ──────────────────────────────────────────────────────────────────
-- DROP TRIGGER IF EXISTS trg_promotion_updated_at ON promotion_records;
-- DROP FUNCTION IF EXISTS update_promotion_updated_at();
-- DROP TABLE IF EXISTS promotion_records;
