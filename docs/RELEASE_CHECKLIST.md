# Release checklist

## Signing

- Production builds MUST be signed with the production keystore
  (`android/release.keystore` + `android/key.properties`, both git-ignored).
  The Gradle build picks it up automatically when `key.properties` exists and
  falls back to the pinned TEST key otherwise — verify the signature before
  distributing:
  `apksigner verify --print-certs app-release.apk` (or check the SHA-256).
- **Back up `android/release.keystore` + `android/key.properties`** to encrypted
  USB + a password manager. Losing them means the Play Store (and the in-app
  updater) will never accept an update signed with a new key again.
- GitHub Actions release builds use the same production key via the
  `ANDROID_KEYSTORE_*` repository secrets.

## Before cutting a release

1. `flutter analyze` — no issues.
2. `flutter test` — full suite green.
3. Bump `version:` in `pubspec.yaml` AND `kAppVersion` in `lib/utils/app_info.dart`
   (a test fails if they drift).
4. Push to `master` and confirm the PR-check workflow is green.
5. Trigger the **Build and release APK** workflow with the matching tag
   (e.g. `v1.1.2+4`); it runs analyze + tests, builds, and attaches the APK
   to the GitHub release. The in-app updater picks it up from there.
6. Real-device smoke test: install, splash, prayer times, notifications,
   Qibla, and Settings → Check for updates.

## Never

- Ship a build signed with the TEST key (`android/test-key.keystore`) as a
  production release — devices will reject the signature change on update.
- Claim scholarly verification/endorsement — that needs the recorded answers
  of qualified Maliki scholars (see research deliverable 07 §5). Still owed.
- Claim iOS readiness — no macOS/Xcode build has been produced or tested.
