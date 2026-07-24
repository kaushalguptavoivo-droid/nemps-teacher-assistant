-- Homework and Fees Improvements Migration
-- Date: 2026-07-24

-- 1. Update homework table - Add is_hidden column and expand subject check constraint
ALTER TABLE homework ADD COLUMN IF NOT EXISTS is_hidden BOOLEAN DEFAULT false;

-- Drop existing check constraint and recreate with all subjects
ALTER TABLE homework DROP CONSTRAINT IF EXISTS homework_subject_check;
ALTER TABLE homework ADD CONSTRAINT homework_subject_check 
  CHECK (subject IN ('Math', 'English', 'Hindi', 'Science', 'Social Studies', 
                     'Computer', 'Drawing', 'EVS', 'GK', 'Sanskrit'));

-- 2. Create fee_types table
CREATE TABLE IF NOT EXISTS fee_types (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    description TEXT,
    amount DECIMAL(10, 2) NOT NULL,
    frequency TEXT NOT NULL DEFAULT 'one-time',
    academic_year TEXT NOT NULL,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. Create class_fee_configs table
CREATE TABLE IF NOT EXISTS class_fee_configs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    class_id UUID NOT NULL REFERENCES classes(id) ON DELETE CASCADE,
    fee_type_id UUID NOT NULL REFERENCES fee_types(id) ON DELETE CASCADE,
    academic_year TEXT NOT NULL,
    is_enabled BOOLEAN DEFAULT true,
    custom_amount DECIMAL(10, 2),
    due_date DATE,
    late_fee DECIMAL(10, 2) DEFAULT 0,
    concession_allowed BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(class_id, fee_type_id, academic_year)
);

-- 4. Create student_fees table
CREATE TABLE IF NOT EXISTS student_fees (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id UUID NOT NULL REFERENCES students(id) ON DELETE CASCADE,
    fee_type_id UUID NOT NULL REFERENCES fee_types(id) ON DELETE CASCADE,
    class_id UUID NOT NULL REFERENCES classes(id) ON DELETE CASCADE,
    academic_year TEXT NOT NULL,
    amount DECIMAL(10, 2) NOT NULL,
    paid_amount DECIMAL(10, 2) DEFAULT 0,
    status TEXT DEFAULT 'due',
    due_date DATE NOT NULL,
    paid_date DATE,
    concession DECIMAL(10, 2) DEFAULT 0,
    late_fee_applied DECIMAL(10, 2) DEFAULT 0,
    remarks TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 5. Create fee_payments table
CREATE TABLE IF NOT EXISTS fee_payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_fee_id UUID NOT NULL REFERENCES student_fees(id) ON DELETE CASCADE,
    student_id UUID NOT NULL REFERENCES students(id) ON DELETE CASCADE,
    amount DECIMAL(10, 2) NOT NULL,
    payment_date DATE NOT NULL,
    payment_method TEXT DEFAULT 'cash',
    transaction_id TEXT,
    received_by UUID REFERENCES profiles(id),
    remarks TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 6. Enable RLS on fee tables
ALTER TABLE fee_types ENABLE ROW LEVEL SECURITY;
ALTER TABLE class_fee_configs ENABLE ROW LEVEL SECURITY;
ALTER TABLE student_fees ENABLE ROW LEVEL SECURITY;
ALTER TABLE fee_payments ENABLE ROW LEVEL SECURITY;

-- 7. RLS Policies for fee tables
CREATE POLICY "fee_types_select" ON fee_types FOR SELECT TO authenticated USING (true);
CREATE POLICY "fee_types_all" ON fee_types FOR ALL TO authenticated USING (true);

CREATE POLICY "class_fee_configs_select" ON class_fee_configs FOR SELECT TO authenticated USING (true);
CREATE POLICY "class_fee_configs_all" ON class_fee_configs FOR ALL TO authenticated USING (true);

CREATE POLICY "student_fees_select" ON student_fees FOR SELECT TO authenticated USING (true);
CREATE POLICY "student_fees_all" ON student_fees FOR ALL TO authenticated USING (true);

CREATE POLICY "fee_payments_select" ON fee_payments FOR SELECT TO authenticated USING (true);
CREATE POLICY "fee_payments_all" ON fee_payments FOR ALL TO authenticated USING (true);
