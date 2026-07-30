// Platform-conditional entry point for BackgroundNoticeService.
//
// Rest of the app imports THIS file only (never the _io/_web files
// directly). Dart's conditional export picks the right implementation at
// compile time:
//   - dart.library.io is available on Android/iOS/desktop → real WorkManager
//     based background check (background_notice_service_io.dart)
//   - otherwise (web) → the no-op stub (background_notice_service_web.dart)
//
// This is what fixes the Vercel web-build failure: the `workmanager`
// package doesn't exist for web, so its symbols (Workmanager,
// ExistingPeriodicWorkPolicy, etc.) can't be referenced in any code path
// the web compiler processes. Conditional export means the web build never
// even sees background_notice_service_io.dart.
export 'background_notice_service_web.dart'
    if (dart.library.io) 'background_notice_service_io.dart';
