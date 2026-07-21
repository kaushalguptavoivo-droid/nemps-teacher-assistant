-- Enable Supabase Realtime for tables used with StreamProvider
-- Run this in Supabase SQL Editor

alter publication supabase_realtime add table teacher_classes;
alter publication supabase_realtime add table students;
alter publication supabase_realtime add table homework;
alter publication supabase_realtime add table notices;
alter publication supabase_realtime add table classes;
alter publication supabase_realtime add table profiles;
alter publication supabase_realtime add table attendance;
