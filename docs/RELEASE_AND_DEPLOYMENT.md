# One source, two production releases

The Android app and web app both use the Flutter code in `lib/` and the same Supabase project. No separate frontend, duplicate database, or data migration is needed: attendance, homework, notices, and users remain synchronized through Supabase.

## Android release process

1. Run `flutter pub get` and `flutter test`.
2. Generate or provide a school-owned Android signing key. Keep it outside Git and back it up securely.
3. Build with `flutter build apk --release` for a directly installable APK. Use `flutter build appbundle --release` for Play Store delivery.
4. Install the release APK on a teacher phone and verify login, offline attendance, sync, and the WhatsApp handoff.

## Web release process

Choose one host, not both:

- **Vercel:** import the GitHub repo. `vercel.json` downloads Flutter and publishes `build/web`.
- **Netlify:** import the GitHub repo. `netlify.toml` performs the equivalent build and preserves browser routes.

For either host, set `SUPABASE_URL` and `SUPABASE_ANON_KEY` only if overriding the supplied public client configuration. Then add the deployed HTTPS domain in Supabase Authentication URL Configuration.

## Version and synchronization policy

- Change `version:` in `pubspec.yaml` once per release.
- Build the APK and deploy web from the same Git commit.
- Use Supabase migrations for every database change and apply them before either rollout.
- Never use a Supabase `service_role` key in Flutter or in a static web build.
