/// Compile-time build-flavor flags, set with `--dart-define`.
///
/// `PLAY_BUILD=true` produces the Google Play build. In that build the
/// in-app GitHub APK updater MUST be off: Play's Device and Network Abuse
/// policy forbids a Play-distributed app from modifying, replacing or
/// updating itself by any method other than Google Play's own update
/// mechanism. The Play build therefore shows a "updates come from Google
/// Play" row instead of the GitHub update check, and [AppUpdateService]
/// refuses to run.
///
/// Sideload builds (the default, no define) keep the GitHub updater: those
/// builds were never distributed through Play, so the policy does not
/// apply to them.
const bool kIsPlayBuild =
    bool.fromEnvironment('PLAY_BUILD', defaultValue: false);

/// Play Store listing URL for this app (package id is stable across
/// builds). Opened by the Play build's update row.
const String kPlayStoreUrl =
    'https://play.google.com/store/apps/details?id=com.talhagohar.malikiprayertimes';
