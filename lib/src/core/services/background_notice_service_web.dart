// Web build of BackgroundNoticeService.
//
// The `workmanager` package (used for background notice checks even when
// the app is fully closed) has no web implementation — it's an Android/iOS
// concept (there's no "closed app" background execution model on web the
// same way). This app also builds for web (Vercel deployment), so this file
// provides a harmless no-op version selected automatically for web builds
// via the conditional export in background_notice_service.dart. On web,
// notice alerts simply rely on the app being open (same as before this
// feature existed) — nothing regresses, it just doesn't add closed-app
// alerts on web, which isn't a meaningful concept there anyway.

class BackgroundNoticeService {
  BackgroundNoticeService._();

  static Future<void> init() async {}

  static Future<void> markAlerted(String noticeId) async {}
}
