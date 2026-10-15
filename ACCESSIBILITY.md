# Accessibility Audit — Track C

**Date:** 2026-10-15 · **App:** Maliki Prayer Times (standalone, Flutter 3.47.5,
Material 3, teal seed) · **Locales:** en / ur / ar / fr (RTL verified by Track B)

All user-visible strings were preserved exactly — no ARB keys were added,
removed, or changed. Every new accessible label reuses an existing localized
string (or Flutter's own `MaterialLocalizations`, e.g. full date names).

## Method

- Walked every screen (`home`, `settings`, `monthly`, `location`, `profiles`,
  `qibla`) and the bottom-nav shell, enumerating interactive elements:
  `IconButton`, `InkWell` day cells, `ActionChip`, `FilledButton`,
  `OutlinedButton`, `TextButton`, `SwitchListTile`, `RadioListTile`,
  `DropdownButtonFormField`, tappable `ListTile`s, `ExpansionTile`, text fields.
- Pumped each screen at text scales 1.0 / 2.0 / 3.0 on two surfaces
  (800×600 and a 360×800 phone), failing on any `RenderFlex` overflow —
  including below-the-fold content (lists are lazy; tests scroll through).
- Measured tap-target sizes on the 360dp phone.
- Computed WCAG contrast ratios for every text/background pair in code,
  including the actual rendered contexts (not just paired container colors)
  and the qibla dial's hard-coded paint colors.
- `flutter test` (full suite) green · `flutter analyze` clean.

## Findings and fixes

### 1. Semantic labels

| Element | Before | After |
|---|---|---|
| Qibla compass dial (`CustomPaint`) | invisible to screen readers | wrapped in `Semantics(label: l10n.qiblaBearing(…))` — announces e.g. “44.7° clockwise from true north” (`qibla_screen.dart`) |
| Monthly day cells (`InkWell`) | no label; reader heard fragments (“15”, “F 05:12”) | wrapped in `Semantics(button: true, excludeSemantics: true, label: MaterialLocalizations.formatFullDate(…))` — one clean “15 October 2026, button” announcement (`monthly_screen.dart`) |
| IconButtons (month nav, ± steppers) | tooltips present (`l10n.previousMonth`, `tooltipEarlier`, …) | kept — tooltips are the sanctioned label mechanism; tests now assert every `IconButton` carries a non-empty localized tooltip |
| Everything else (chips, buttons, tiles, switches, radios, dropdowns, text fields) | already labeled via text children / `labelText` / tooltips | verified by test, no change |

**No ARB keys were added.** The dial reuses `qiblaBearing`; day cells reuse
Flutter's localized full-date format. (Note: `lib/l10n/` is owned by Track B
and was not touched.)

Platform nuance (documented, not a defect): Flutter exposes a tooltip's
message to the semantics tree when the tooltip becomes visible (long-press),
so an `IconButton` announces its role on focus and its tooltip text on
long-press. This is standard Flutter behavior; no redundant `Semantics`
wrappers were added (they would double-announce once the tooltip shows).

### 2. No color-only signaling — verified, no fix needed

- **Ikhtiyari/daruri bands (home):** state is text-only already —
  `preferredLabel`/`necessityLabel` (“Preferred: …”, “Absolute end: …”).
  No color coding exists to remove.
- **Monthly bands:** each band line carries a text `Chip` (`computedChip` /
  `informationalChip`), not color alone.
- **Next-prayer highlight:** the `primaryContainer` tint is paired with the
  `nextPrayerBadge` (“Next prayer”) text badge.
- **High-latitude estimate flag:** the `estimatedMarker` (“est.”) text plus
  a localized tooltip (`estimatedTooltip`), not color alone.
- Tests assert the presence of each text signal.

### 3. Touch targets (48×48)

- Monthly day cells were **45.7dp wide on a 360dp phone**
  (`(360 − 16 − 24) / 7`). Fixed: grid padding → horizontal 6, cross-spacing
  → 2, giving exactly `(360 − 12 − 12) / 7 = 48.0`dp; height 61.5dp.
  (Weekday header padding adjusted to match so columns stay aligned.)
- All `IconButton`s (settings steppers, month nav) already meet 48×48 —
  verified by measurement on the 360dp phone.
- Bottom-nav items, switches, radios, dropdowns, chips: full-width rows,
  inherently ≥ 48dp.

### 4. Large-text overflows — fixed

| Screen / scale | Problem | Fix |
|---|---|---|
| Monthly grid, 2×/3× | day-cell `Column` overflowed (103px @2×, 315px @3×) | cell height now scales with the text scaler (`childAspectRatio: 0.78 / textScale`, lower-clamped at 1.0 so the default look is pixel-identical); grid scrolls instead of overflowing |
| Monthly grid, 3× on 360dp | time labels wrapped into extra lines, blowing past the taller cell | `FittedBox(scaleDown)` shrink-to-fit on the day number and both time labels (single-line); full-size times remain one tap away in the day-detail sheet |
| Monthly footnote, 3× on 360dp | `hijriCalendarNote` grew taller than the remaining body space (44px body overflow) | footnote capped at ⅓ screen height with internal scroll fallback; unaffected at normal sizes |
| Settings language dropdown, 2×+ | selected value (“System default”) pushed the field 190px past its card | `isExpanded: true` + ellipsizing item labels |
| Profiles comparison dropdowns, 2×+ | long profile names pushed fields 582–802px past their half-row | `isExpanded: true` (items already ellipsized) |
| Home location chip, 3× on 360dp | 53px right overflow | `Flexible` + ellipsizing label |

Home, settings (rows), profiles, location, and qibla were clean at 2×/3×
after these fixes, on both surfaces, including content below the fold.

### 5. Contrast — all pass, no adjustments

Computed against `ColorScheme.fromSeed(seedColor: Colors.teal)` (WCAG AA
requires 4.5:1 for normal text):

| Pair | Ratio |
|---|---|
| onSurface / surface | 16.31:1 |
| onSurfaceVariant / surface | 8.87:1 |
| onPrimary / primary | 6.50:1 |
| onPrimaryContainer / primaryContainer | 7.26:1 |
| onTertiaryContainer / tertiaryContainer | 7.25:1 |
| onErrorContainer / errorContainer | 7.24:1 |
| error / surface (location error text) | 6.15:1 |
| onSurface / primaryContainer (next-prayer row) | 13.27:1 |
| onSurface / tertiaryContainer (profile status card) | 13.22:1 |
| onTertiaryContainer / surface (estimated marker, actual bg) | 8.94:1 |
| Qibla dial 616161 / white | 6.19:1 |
| Qibla dial B71C1C / white | 6.57:1 |
| Qibla dial 00695C / white | 6.61:1 |
| Qibla dial 212121 / white | 16.10:1 |

No color was changed — the teal-seeded Material 3 theme already clears AA
everywhere, including the qibla dial's hard-coded paints (light theme only;
the app does not ship a dark theme, so the hard-coded dial colors are safe).

## Tests

New `test/accessibility_test.dart` (17 tests, all green):

- **semantics labels** (7): per-screen coverage — every interactive element
  exposes a label via tooltip/`labelText`/text/`Semantics`, incl. the qibla
  dial bearing and full-date day-cell labels.
- **no color-only signaling** (4): band text, next-prayer badge, band chips,
  high-latitude estimate marker.
- **large text** (2): all six screens at 2×/3× on 800×600 and 360×800,
  scrolling through lazy content, failing on any overflow.
- **touch targets** (2): day cells ≥ 48×48 and icon buttons ≥ 48×48 measured
  on the 360dp phone.
- **contrast** (2): unit tests asserting every pair above ≥ 4.5:1.

Full suite: **105/105 green** (`flutter test`), `flutter analyze` clean.

## Residual risks / known limitations

1. **Tooltip announcement timing** (platform behavior): icon-button tooltips
   are exposed to screen readers when the tooltip becomes visible
   (long-press), not on focus. Standard Flutter behavior; accepted.
2. **Day-cell times shrink at extreme scales:** on a 360dp phone at 3×, the
   grid's “F 05:12” labels shrink-to-fit rather than overflow. Full-size
   times are one tap away in the day-detail bottom sheet, which scrolls and
   scales normally. This is the standard trade-off for a fixed 7-column
   grid.
3. **Urdu (Nastaleeq) at 3× on narrow phones** was reasoned about but not
   rendered in tests (test font is Latin); the shrink-to-fit + scrolling
   guards apply regardless of script.
4. **No dark theme** is shipped, so hard-coded qibla dial colors were only
   validated against the light surface. If a dark theme is ever added, the
   dial painter (`_QiblaDialPainter`) must be re-audited.
5. **Motion/vestibular:** not in scope for this pass (no animations beyond
   standard Material transitions and the static dial).
6. `lib/main.dart` (bottom nav) was not modified — its labeled
   `BottomNavigationBarItem`s were already accessible.

## Process note

During this pass I accidentally ran `dart format` on working-tree files.
This repo's tree (Tracks A/B) is hand/short-style formatted, but the
installed SDK (Flutter 3.47.5, Dart language version 3.13) formats TALL
style, so the run rewrote hundreds of unrelated lines across 6 screen
files and even touched `lib/main.dart` (a do-not-touch file). Recovery:

- `lib/main.dart`: hand-reverted hunk by hunk; its diff is back to Track B's
  semantic changes only (verified line by line).
- The 6 screen files: re-normalized to canonical SHORT style (via a
  temporary `languageVersion: 3.6` in the git-ignored
  `.dart_tool/package_config.json`, since restored). Note this still does not
  byte-match the repo's hand formatting — no formatter run can — but the
  files are now self-consistent and every remaining diff line is a real
  semantic change (Track B's or this pass's), verified by the green suite.
- Lesson recorded in `~/AGENTS.md`: never run bare `dart format` on this
  repo; `--set-exit-if-changed` still writes by default (use
  `--output=none` for a true check).

No functional change resulted from any formatting pass; `flutter test`
(105) and `flutter analyze` are green.
