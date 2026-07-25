-- Fees Module Migration
-- Run this in Supabase SQL Editor

-- Fee Types Table
create table if not exists public.fee_types (
  id uuid default gen_random_uuid() primary key,
  name text not null,
  description text,
  amount double precision not null,
  frequency text not null default 'monthly',
  is_active boolean default true,
  academic_year text,
  is_one_time boolean default false,
  late_fee_per_month double precision default 0,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- Class Fee Config Table
create table if not exists public.class_fee_configs (
  id uuid default gen_random_uuid() primary key,
  class_id text not null,
  fee_type_id uuid references public.fee_types(id) on delete cascade,
  amount double precision not null,
  concession_type text default 'none',
  late_fee_per_month double precision default 0,
  is_active boolean default true,
  academic_year text,
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  unique(class_id, fee_type_id, academic_year)
);

-- Student Fees Table
create table if not exists public.student_fees (
  id uuid default gen_random_uuid() primary key,
  student_id text not null,
  academic_year text not null,
  total_fee double precision default 0,
  concession_amount double precision default 0,
  concession_type text default 'none',
  net_fee double precision default 0,
  paid_amount double precision default 0,
  due_amount double precision default 0,
  late_fee_applied double precision default 0,
  installment_plan text default 'full',
  is_one_time boolean default false,
  fee_status text default 'due',
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  unique(student_id, academic_year)
);

-- Student Monthly Fees Table
create table if not exists public.student_monthly_fees (
  id uuid default gen_random_uuid() primary key,
  student_fee_id uuid references public.student_fees(id) on delete cascade,
  student_id text not null,
  month text not null,
  amount double precision not null,
  late_fee double precision default 0,
  is_paid boolean default false,
  due_date date,
  paid_date date,
  academic_year text,
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  unique(student_fee_id, month)
);

-- Fee Payments Table
create table if not exists public.fee_payments (
  id uuid default gen_random_uuid() primary key,
  student_fee_id uuid references public.student_fees(id) on delete cascade,
  student_id text not null,
  amount double precision not null,
  payment_date date not null,
  payment_mode text default 'cash',
  receipt_number text,
  collected_by text,
  notes text,
  academic_year text,
  month text,
  created_at timestamptz default now()
);

-- Enable RLS
alter table public.fee_types enable row level security;
alter table public.class_fee_configs enable row level security;
alter table public.student_fees enable row level security;
alter table public.student_monthly_fees enable row level security;
alter table public.fee_payments enable row level security;

-- RLS Policies (allow authenticated users)
create policy "Allow authenticated access to fee_types" on public.fee_types for all to authenticated using (true);
create policy "Allow authenticated access to class_fee_configs" on public.class_fee_configs for all to authenticated using (true);
create policy "Allow authenticated access to student_fees" on public.student_fees for all to authenticated using (true);
create policy "Allow authenticated access to student_monthly_fees" on public.student_monthly_fees for all to authenticated using (true);
create policy "Allow authenticated access to fee_payments" on public.fee_payments for all to authenticated using (true);

-- Create indexes for better performance
create index if not exists idx_class_fee_configs_class_id on public.class_fee_configs(class_id);
create index if not exists idx_student_fees_student_id on public.student_fees(student_id);
create index if not exists idx_student_monthly_fees_student_id on public.student_monthly_fees(student_id);
create index if not exists idx_student_monthly_fees_month on public.student_monthly_fees(month);
create index if not exists idx_fee_payments_student_id on public.fee_payments(student_id);
create index if not exists idx_fee_payments_date on public.fee_payments(payment_date);
