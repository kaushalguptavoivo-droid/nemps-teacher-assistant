# NEMPS Teacher Assistant

Flutter Android/Web application for **New Era Modern Public School, Vrindavan**, using **Supabase** backend.

## ✨ Features

### 👨‍🏫 Teacher Features
- **Daily Attendance** - Mark present/absent, see real-time class count
- **Homework Management** - Assign by subject (Math, English, Hindi, Science, Social Studies)
- **Homework Status Tracking** - Mark completion for each student (Complete/Incomplete/Not Checked)
- **Absent Student Notifications** - Send WhatsApp alerts to parents in one tap
- **Student Import/Export** - Bulk manage student data via CSV
- **Notices & Announcements** - Receive class-wide messages

### 👨‍💼 Admin Features
- **Teacher Supervision** - Track what teachers do (attendance marked, homework assigned, messages sent)
- **Notices Broadcasting** - Send messages to specific classes or all students
- **Student Management** - View, import, export all student records
- **Attendance Reports** - Class-wise and day-wise attendance statistics
- **Homework Reports** - Completion percentage by subject

## 🏗️ Tech Stack

- **Frontend:** Flutter (Dart) + Riverpod for state management
- **Backend:** Supabase (PostgreSQL + Auth)
- **Database:** PostgreSQL with Row Level Security
- **Offline:** Hive + Encrypted local storage
- **Messaging:** WhatsApp Web deep linking
- **Import/Export:** CSV format

## 🚀 Quick Start

### Prerequisites
1. Flutter SDK (stable channel)
2. Android Studio or VS Code with Flutter extension
3. Supabase account (free tier works)
4. Node.js LTS (optional, for Vercel deployment)

### Database Setup

1. Create a Supabase project at [supabase.com](https://supabase.com)
2. Go to **SQL Editor** and run `supabase/schema.sql`
3. Then run `supabase/seed.sql` to add dummy data

### Create Auth Users

1. Go to **Authentication → Users** in Supabase
2. Create teacher and admin accounts (use email + password)
3. Copy their Auth UUIDs
4. Update `supabase/seed.sql` with the UUIDs:

```sql
insert into profiles(id, full_name, role, phone) values
('PASTE_ADMIN_UUID', 'School Admin', 'admin', '+919999999999'),
('PASTE_TEACHER_UUID', 'Teacher Name', 'teacher', '+919999999998');
```

5. Assign teacher to classes:

```sql
insert into teacher_classes(teacher_id, class_id) values
('PASTE_TEACHER_UUID', '11111111-1111-1111-1111-111111111111');
```

### Run Locally

```bash
# Get dependencies
flutter pub get

# Run on web (Chrome)
flutter run -d chrome

# Run on Android emulator
flutter run -d emulator-5554
```

### With Custom Supabase URL

```bash
flutter run --dart-define=SUPABASE_URL=https://your-project.supabase.co --dart-define=SUPABASE_ANON_KEY=your-key -d chrome
```

## 📱 Mobile Build

```bash
# Build release APK
flutter build apk --release --dart-define=SUPABASE_URL=https://your-project.supabase.co --dart-define=SUPABASE_ANON_KEY=your-key

# Output: build/app/outputs/flutter-apk/app-release.apk
```

## 🌐 Web Deployment (Vercel)

1. Push to GitHub
2. Import repository in [Vercel](https://vercel.com)
3. Leave build settings as detected
4. In Supabase **Authentication → URL Configuration**, add your Vercel domain:
   - Site URL: `https://nemps-teacher.vercel.app`
   - Redirect URLs: `https://nemps-teacher.vercel.app/**`

## 📊 Usage Guide

### Teacher Workflow

**Morning:**
1. Open app → Select class
2. Tap "Mark Attendance"
3. Mark present (P) or absent (A) for each student
4. Tap "Save Attendance" → See count (Present: 35, Absent: 5)
5. For absent students, tap "Send" to notify parents via WhatsApp

**Afternoon:**
1. Tap "Homework" in class
2. Select subject → Add description → "Assign Homework"
3. Later, tap "Mark Status" → Select each student's status
4. Done students auto-get notification (if WhatsApp enabled)

**End of Day:**
1. Optional: Export daily attendance as CSV for records

### Admin Workflow

1. Open Admin Panel (from dashboard)
2. **Notices Tab:** Send announcements to classes
3. **Teacher Activity Tab:** See what each teacher did today
4. **Students Tab:** Browse all students by class

## 🔐 Security

- **Row Level Security (RLS)** - Teachers see only their classes
- **Encryption** - Local offline data is AES-256 encrypted
- **Audit Log** - All actions logged in `teacher_activity` table
- **No API Keys in App** - Uses Supabase public/anon key (RLS protects data)

## 📁 Project Structure

```
lib/
  main.dart                 - App entry, offline queue init
  src/
    app.dart               - Router configuration
    core/
      models/models.dart   - Data classes (Student, Homework, Notice, etc.)
      config/              - Supabase config
      services/            - Offline queue
      theme/               - Material 3 theming
    features/
      data/
        school_repository.dart  - Database operations
        providers.dart          - Riverpod providers
      presentation/
        screens.dart        - All UI screens

supabase/
  schema.sql   - Database tables & RLS policies
  seed.sql     - Test data (classes, students)
```

## 🗄️ Database Schema

- **profiles** - Teachers and admins
- **classes** - Class rooms (e.g., 5-A, 6-B)
- **teacher_classes** - Many-to-many teacher ↔ class
- **students** - Student records with contact info
- **attendance** - Daily attendance (student_id + date = unique)
- **homework** - Homework assignments by subject
- **homework_status** - Per-student homework status
- **teacher_activity** - Audit log of teacher actions
- **notices** - Admin-sent announcements

## 🔧 Troubleshooting

**"Students not showing"**
→ Make sure seed.sql was run and teacher is assigned to class

**"Attendance not saving"**
→ Check internet connection. Changes sync when online (offline queue)

**"WhatsApp not opening"**
→ WhatsApp must be installed. Web version opens WhatsApp Web link

**"Can't import CSV"**
→ CSV must have: Roll No, Full Name, Father Name, WhatsApp, DOB, Fee Status

## 📞 Support

For issues, check:
1. Supabase console for SQL errors
2. Flutter DevTools for state/network issues
3. Supabase RLS policies if data not visible

## 📝 License

Free for educational use at New Era Modern Public School.

## 🤝 Contributing

Suggestions welcome! This is actively maintained for the school.
