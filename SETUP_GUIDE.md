# NEMPS Teacher Assistant — Updated Setup Guide

## Database Setup (Required First)

1. **Open Supabase SQL Editor** and run:
   ```sql
   -- Run schema.sql (creates all tables)
   -- Run seed.sql (adds test data)
   ```

2. **Create Auth Users in Supabase:**
   - Go to Authentication → Users
   - Create teacher and admin accounts
   - Copy their Auth UUIDs

3. **Update seed.sql with Auth UUIDs:**
   ```sql
   insert into profiles(id, full_name, role, phone) values
   ('ADMIN_UUID', 'School Admin', 'admin', '+919999999999'),
   ('TEACHER_UUID', 'Teacher Name', 'teacher', '+919999999998');
   ```

4. **Assign Teachers to Classes:**
   ```sql
   insert into teacher_classes(teacher_id, class_id) values
   ('TEACHER_UUID', '11111111-1111-1111-1111-111111111111');
   ```

## Features Implemented

### 📋 **Teacher Features:**
- ✅ **Attendance** - Mark present/absent daily, track count class-wise
- ✅ **Homework** - Assign by subject, mark completion status (Complete/Incomplete)
- ✅ **Absent Notifications** - Send WhatsApp to absent students with one tap
- ✅ **Homework Messages** - Send status to parents via WhatsApp
- ✅ **Class Details** - Import/Export student list as CSV

### 👨‍💼 **Admin Features:**
- ✅ **Notices** - Send broadcasts to classes or individual students
- ✅ **Teacher Supervision** - Track teacher activity (attendance marked, homework assigned, messages sent)
- ✅ **Student Management** - View all students, bulk import/export
- ✅ **Reports** - View attendance and homework completion reports

## How to Use

### Marking Attendance (Teacher)
1. Dashboard → Select Class → Attendance
2. Mark P (Present) or A (Absent) for each student
3. Tap "Save Attendance"
4. See present/absent count in real-time

### Assigning Homework (Teacher)
1. Dashboard → Select Class → Homework
2. Select subject (Math/English/Hindi/Science/Social Studies)
3. Add description
4. Tap "Assign Homework"

### Marking Homework Status (Teacher)
1. In Homework screen, tap "Mark Status" on any homework
2. For each student: ✓ Done, ✗ Incomplete, ? Not Checked
3. Tap "Save"

### Sending Notifications (Teacher)
1. Attendance Screen → Students with Absent status show notification button
2. Tap "Send" → Opens WhatsApp with pre-filled message
3. Same for Homework Status

### Import/Export Students (Teacher)
1. Class Details → Menu → "Import Students" or "Export Students"
2. CSV format: Roll No, Full Name, Father Name, WhatsApp, DOB, Fee Status
3. Import adds/updates students in database

### Admin Panel
1. Dashboard → "Admin Panel"
2. **Notices Tab** - Send broadcast messages to classes
3. **Teacher Activity Tab** - View what teachers did (attendance, homework, messages)
4. **Students Tab** - View all students by class

## Running Locally

```powershell
# Get dependencies
flutter pub get

# Run on Chrome (web)
flutter run -d chrome

# Run on Android emulator
flutter run -d emulator-5554

# Build APK
flutter build apk --release
```

## Environment Setup

The app uses Supabase URLs from the config. To override:

```powershell
flutter run --dart-define=SUPABASE_URL=https://your-project.supabase.co --dart-define=SUPABASE_ANON_KEY=your-key
```

## Database Schema

- **profiles** - Teachers/Admin users
- **classes** - Class rooms (5-A, 6-B, etc.)
- **teacher_classes** - Which teacher teaches which class
- **students** - Student list with contact info
- **attendance** - Daily attendance records
- **homework** - Homework assignments by subject
- **homework_status** - Individual student homework status
- **teacher_activity** - Audit log of teacher actions
- **notices** - Broadcast messages from admin

## Security

- Row Level Security (RLS) enabled on all tables
- Teachers see only their assigned classes
- Admins see everything
- All writes are logged in teacher_activity table

## Offline Support

- Attendance and homework are cached locally
- Changes sync automatically when internet returns
- Encrypted local storage for security

## Next Steps

1. Deploy to Vercel (web): Follow Vercel docs in README
2. Build for Android/iOS for mobile apps
3. Configure your school's Supabase project
4. Invite teachers and admins with their auth credentials
