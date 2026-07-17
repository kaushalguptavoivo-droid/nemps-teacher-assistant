-- Run after schema.sql. Create the auth users in Supabase Dashboard first,
-- then replace these UUIDs with their Auth user IDs.
-- insert into profiles(id, full_name, role, phone) values
-- ('ADMIN_AUTH_UUID','NEMPS Administrator','admin','+919999999999'),
-- ('TEACHER_AUTH_UUID','Anita Sharma','teacher','+919999999998');
insert into public.classes(id,name,section,academic_year) values
('11111111-1111-1111-1111-111111111111','5','A','2026-27'),
('22222222-2222-2222-2222-222222222222','6','A','2026-27') on conflict do nothing;
insert into public.students(class_id,roll_no,full_name,father_name,whatsapp,dob,fee_status) values
('11111111-1111-1111-1111-111111111111','01','Aarav Gupta','Rajesh Gupta','919999999901','2015-08-11','paid'),
('11111111-1111-1111-1111-111111111111','02','Diya Sharma','Manoj Sharma','919999999902','2015-02-03','due'),
('11111111-1111-1111-1111-111111111111','03','Kabir Verma','Rohit Verma','919999999903','2015-12-22','overdue') on conflict do nothing;
