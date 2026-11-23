# Play Store prep — Maliki Prayer Times

Status: **prep in progress (2026-11-23)**. Play build is `v1.3.7+13`
with `PLAY_BUILD=true`. Nothing here publishes anything; the Play
Console steps are the owner's to do in their own account.

## What is already done

- **Play-safe build gate (commit: Play prep, 2026-11-23).**
  `--dart-define=PLAY_BUILD=true` switches the build to Play rules:
  the Settings "Check for updates" row (GitHub APK download) is replaced
  by a "Updates come from Google Play" row opening the Play listing, and
  `AppUpdateService.check()` refuses to run even if called. Sideload
  builds (no define) keep the GitHub updater. Verified by
  `test/play_build_settings_test.dart` (run with the define; 4/4 pass).
  `lib/utils/build_flavor.dart` is the single source for the flag and
  the Play listing URL.
- **AAB**: `maliki-prayer-times-v1.3.7-play.aab`, 68,526,653 B,
  sha256 `fc925a0e…1a0fcb`, built 2026-11-23 22:12 PKT with
  `PLAY_BUILD=true` from the same production key as the APKs
  (`android/release.keystore`, backed up on Drive under "App Keystores").
  Verified: `jarsigner -verify` passes; base manifest carries package
  `com.talhagohar.malikiprayertimes` + versionName `1.3.7`; adhan
  `base/res/raw/tunisi_adhan.mp3` inside; and the Play build's
  `libapp.so` contains the Play listing URL and NOT the GitHub API URL
  (the sideload APK is the exact opposite — the define genuinely
  changes the binary). Play App Signing enrolls on first upload; keep
  the keystore — the upload key is still needed for every release.
  A copy sits at `~/workspace/your_files/maliki-prayer-times-v1.3.7-play.aab`
  (local only — do NOT share this link; Play Console takes the AAB
  directly).
- **Version**: `1.3.7+13`; `kAppVersion` matches (fixed the 1.3.0 drift
  in v1.3.7).
- **Target SDK 36 / min SDK 24** (verified from the v1.3.7 APK).
- **Privacy page**: `docs/privacy-policy.html` is host-ready (based on
  `docs/PRIVACY.md`, plus the Qada/Hayd local-only records and the
  Play-build update note). It still needs a public URL — see open
  decisions.
- **Store assets**: `docs/store/icon-512.png` (512×512) and
  `docs/store/feature-graphic-1024x500.png` are built from the app's
  own compass logo. Phone screenshots are NOT included — they must be
  real screenshots from the owner's phone (never fabricated).

## Store listing (draft — owner to confirm)

- **App name:** Maliki Prayer Times
- **Short description (≤80 chars):**
  `Prayer times by Maliki fiqh — free, offline, with adhan alerts.`
- **Full description (draft):**
  > Prayer times according to Maliki fiqh — free, with no ads and no
  > account.
  >
  > • Fajr, Sunrise, Dhuhr, Asr, Maghrib and Isha by Maliki rules, with
  >   ikhtiyari and daruri times shown separately
  > • Asr at the first mithl; Isha from the disappearance of the red
  >   twilight; narrow Maghrib mukhtar time
  > • Adhan notification at each prayer time, with reminders
  > • Qada tracker, travel (qasr) mode, Qibla compass, monthly timetable
  > • Urdu, English, Arabic and French
  > • Prayer times are calculated fully offline on your phone; your
  >   location is used only when you ask for it
  >
  > This is an early version — if you notice any shortcoming, please
  > let us know at muhaqqiqcreates@gmail.com.
- **Category:** Lifestyle (confirm in Console)
- **Content rating:** Everyone — no violence, no sexual content, no
  user-generated content, no chat, no ads, no in-app purchases.
- **Pricing:** Free. No ads. No in-app purchases. No account.
- **Contact email:** muhaqqiqcreates@gmail.com

## Data Safety (draft answers — owner to confirm in Console)

Play counts data as "collected" only when it leaves the device. On
that definition:

| Data | Collected? | Shared? | Notes |
|---|---|---|---|
| Precise location | Yes | No | One-shot GPS fix when the user taps device location; coordinates go to the OS reverse-geocoder for a place name only, then stay on the phone. No background tracking. |
| Health data (Hayd/Nifas bleeding records) | No | No | Stored only on the phone in secure storage, never transmitted. Deletable in-app (Qada → delete all). |
| Name, email, contacts, photos, files, identifiers | No | No | The app has no account and collects none of these. |
| Crash logs / diagnostics | No | No | No analytics, crash-reporting or telemetry. |

- Data deletion: no account exists; uninstalling or clearing app data
  removes everything. State this in the Console form.
- Encryption in transit: the Play build makes no app-initiated network
  request (update check disabled); the OS geocoder is a platform
  service, not an app server.

## Permissions declarations (Console)

- **USE_EXACT_ALARM** — core functionality: prayer-time alarms must
  fire at the exact time. Declare with the alarm/clock justification.
- **SCHEDULE_EXACT_ALARM (maxSdk 32)** — same, for Android 12 only.
- **REQUEST_IGNORE_BATTERY_OPTIMIZATIONS** — the app offers a
  one-tap battery-exemption request so Doze does not delay prayer
  alarms. Expect scrutiny; if Play pushes back, drop the request
  (alarms still work, may arrive late on some phones).
- **ACCESS_FINE_LOCATION / ACCESS_COARSE_LOCATION** — one-shot
  device location, user-initiated only.
- **POST_NOTIFICATIONS** — runtime prompt on first launch.
- **INTERNET** — declared in the manifest; in the Play build it is
  unused (no update check, no other network call). Keep the
  declaration honest in the form; removing the permission from the
  Play build is a follow-up if Play flags it.

## Console steps (owner only)

1. Create / open the Play Console account ($25 one-time, identity
   verification). Personal accounts created after 13 Nov 2023 must
   run a **closed test with ≥12 testers opted in continuously for
   14 days**, then apply for production access (review usually ≤7
   days). Older / organisation accounts skip that rule.
2. Create the app (package `com.talhagohar.malikiprayertimes`),
   complete App Content (privacy policy URL, content rating, target
   audience, Data Safety, ads declaration: none).
3. Upload the AAB to **Internal testing** first, then **Closed
   testing** (12+ real testers, 14 days if the rule applies).
4. Apply for production access, then promote to Production.

Realistic timeline from account creation: ~3–5 weeks if the 14-day
closed-test rule applies; ~1 week if it does not.

## Open decisions (owner)

1. **Play Console account** — exists already? Personal or
   organisation? Created before or after 13 Nov 2023?
2. **Adhan recording licence** — the bundled Tunisian adhan
   (`res/raw/tunisi_adhan.mp3`) is user-supplied with unknown
   source/licence. Public distribution on Play raises the exposure.
   Verify rights, replace with a licensed/self-recorded adhan, or
   ship without it. **Do not publish until this is decided.**
3. **Privacy-policy hosting** — `docs/privacy-policy.html` is ready;
   pick GitHub Pages (public repo) or Cloudflare Pages, publish it,
   paste the URL into Console and into the app.
4. **Phone screenshots** — at least 2 real phone screenshots (home
   timetable + one more screen) from the owner's phone.
5. **v1.3.6 phone test still owed** (Close button + adhan
   interruption) and **v1.3.7 location test** — ideally confirmed
   before the closed-test build goes out.
6. **Push v1.3.6/v1.3.7 to GitHub?** Not required for Play, but the
   repo is behind local (last pushed: v1.3.5). Needs the owner's
   explicit push directive, as always.
