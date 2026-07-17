# NEMPS Teacher Assistant

Flutter Android application for **New Era Modern Public School, Vrindavan**, using **Supabase only**.

## Included

- Supabase Auth, Postgres schema, Row Level Security and private photo-storage guidance
- Teacher-only assigned-class access; admin role and policies for school administration
- Material 3 responsive UI with system light/dark mode
- Attendance with offline outbox + automatic retry on the next sync, student list, homework shell, reports shell
- WhatsApp deep-link helper: it only opens a manual, prefilled message; it never sends automatically or uses an unofficial API
- Dummy student data and a production-oriented, normalized database model

## Setup

1. Install Flutter stable and Android Studio. Run `flutter create .` once to generate the Flutter Gradle wrapper and platform boilerplate, then run `flutter pub get`. This preserves the provided Dart, Supabase, and Android configuration.
2. Create a Supabase project. In SQL Editor run [supabase/schema.sql](supabase/schema.sql), then [supabase/seed.sql](supabase/seed.sql).
3. In Authentication, create teacher/admin accounts. Add their Auth UUIDs to `profiles` and class IDs to `teacher_classes`.
4. Create a **private** Storage bucket named `student-photos`. Add storage policies granting teachers access only to photos belonging to their assigned students; use signed URLs in the app.
5. Run locally without committing secrets:

```powershell
flutter run --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY
```

## Release APK

```powershell
flutter build apk --release --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY
```

APK output: `build/app/outputs/flutter-apk/app-release.apk`.

## Deploy on Vercel (web)

1. Push this project to a GitHub repository and import that repository in Vercel.
2. In **Project Settings → Environment Variables**, add `SUPABASE_URL` and `SUPABASE_ANON_KEY` for Production, Preview, and Development. Use the public **anon** key only—never a service-role key.
3. Leave the build settings as detected from `vercel.json`, then click **Deploy**. The first build downloads Flutter, so allow a few extra minutes.
4. In Supabase **Authentication → URL Configuration**, add your Vercel domain to Site URL and Redirect URLs, for example `https://nemps-teacher.vercel.app/**`.

The `vercel.json` rewrite keeps GoRouter deep links such as `/attendance/<class-id>` working after a browser refresh.

## Architecture

`presentation → Riverpod providers → repository → Supabase / encrypted-device queue`.

Feature modules are intentionally separated from the core models, configuration and services so attendance, fees, notices, imports and exports can grow without coupling screens to database code.

## Production checklist

- Turn on Supabase Auth email confirmation/reset policies and configure Android deep links.
- Keep RLS enabled; verify every policy with both a teacher and an admin test account.
- The offline queue is encrypted with an AES key held in `flutter_secure_storage`; never store a database service key in the app.
- Use Supabase Edge Functions for Excel parsing, backup/restore, report export and any future **official** WhatsApp Business API calls. Do not expose privileged operations to clients.
- Add Android app signing, crash monitoring and periodic backup testing before production rollout.

## WhatsApp workflow

Build a personalized template with `{{student_name}}`, filter the relevant students (absent/homework pending/fee due/selected/class), and call `openWhatsApp(phone, message)` once per selected parent. WhatsApp opens with the filled message and the teacher personally taps **Send**.
