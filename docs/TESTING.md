# Testing

## Running the suite

```sh
export PATH=/home/hatch/flutter-sdk/flutter/bin:$PATH   # sandbox only
flutter pub get
flutter gen-l10n        # required before analyze (generated localizations)
flutter analyze         # must report "No issues found!"
flutter test            # full suite, currently 189 tests
```

Rules learned the hard way (see `AGENTS.md` at the workspace root):

- Never run two `flutter test` in the same repo concurrently (lock fights).
- `/tmp` is a 512MB tmpfs — clear `/tmp/flutter_tools.*` if a run deadlocks after compile.
- `rootBundle.loadString` and FFI hang inside `testWidgets`' FakeAsync zone — wrap in `tester.runAsync()`.
- Never run bare `dart format` — this repo is hand-formatted; the SDK's tall style would churn hundreds of lines.

## What is covered

- **Engine** (`test/engine_*`): prayer-time math for all three profiles, high-latitude fallbacks, DST boundaries, NaN/Infinity input validation, regression tests for fixed audit issues (E-01, E-04, E-05).
- **Services**: notification scheduling incl. DST offsets, boot reschedule (`boot_reschedule_test.dart`), location persistence and timeouts.
- **UI/widget**: prayer-row layout at 1.0x/1.5x/2.0x text scaling in LTR and RTL (`prayer_row_layout_test.dart`), splash precache + exit dialog, accessibility contrast against the real color scheme, Qibla sensor throttling.
- **Update checker**: tag parsing (`v1.1.2+4` → build 4), APK-asset preference, release-page fallback, offline → `unknown`.

## What is NOT covered (manual QA)

- Real-device notification delivery (Doze, OEM battery savers, exact-alarm grants).
- Reboot reschedule on a real phone.
- Visual review of splash, prayer cards, and gold tertiary surfaces on device.
- iOS: cannot build or test on Linux — needs a macOS/Xcode pass.
