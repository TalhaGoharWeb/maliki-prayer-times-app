import 'package:flutter/material.dart';
import 'package:malikiprayertimes/l10n/app_localizations.dart';
import 'package:malikiprayertimes/utils/fonts.dart';

/// Why a changelog row is what it is — the same integrity boundary as the
/// methodology table (lib/screens/methodology_texts.dart):
/// [fiqhDerived] is a Maliki legal rule with attested textual basis;
/// [convention] is an institutional or software convention — NEVER a fiqh
/// ruling. Nothing here invents fiqh, scholars, angles, or endorsements:
/// every row mirrors docs/CALCULATION_CHANGELOG.md, which is measured from
/// docs/CALCULATION_METHODS.md and the research deliverables.
///
/// Digits stay Western 0-9 in every locale (Urdu-first rule); version
/// strings and dates are plain ASCII.
enum ChangelogStatus { fiqhDerived, convention }

/// One parameter row of a changelog version entry: parameter / value /
/// status / changed-since, mirroring the markdown table.
class ChangelogRow {
  final String parameter;
  final String value;
  final ChangelogStatus status;
  final String changedSince;

  const ChangelogRow({
    required this.parameter,
    required this.value,
    required this.status,
    required this.changedSince,
  });
}

/// One released version's entry.
class ChangelogVersion {
  /// Display version, e.g. 'v1.2.0+5'.
  final String version;

  /// Release date, ISO yyyy-MM-dd.
  final String date;

  /// True for the baseline entry (the first recorded method state); the
  /// screen renders the localized baseline note for it.
  final bool isBaseline;

  final List<ChangelogRow> rows;

  const ChangelogVersion({
    required this.version,
    required this.date,
    required this.isBaseline,
    required this.rows,
  });
}

/// The versioned record of engine/profile changes, hardcoded as Dart data
/// mirroring docs/CALCULATION_CHANGELOG.md (single-source would be nicer,
/// but asset-loading inside widgets is a known hang risk in tests — so the
/// data is duplicated here and test/calculation_changelog_test.dart asserts
/// version and parameter parity with the markdown file).
const List<ChangelogVersion> changelogVersions = [
  ChangelogVersion(
    version: 'v1.2.0+5',
    date: '2026-10-16',
    isBaseline: true,
    rows: [
      ChangelogRow(
        parameter: 'Fajr angle',
        value: '18° solar depression (MWL Islamic Fiqh Council, 1986)',
        status: ChangelogStatus.convention,
        changedSince: 'v1.2.0+5 (baseline)',
      ),
      ChangelogRow(
        parameter: 'Isha angle',
        value: '17° solar depression (red twilight; MWL 1986)',
        status: ChangelogStatus.convention,
        changedSince: 'v1.2.0+5 (baseline)',
      ),
      ChangelogRow(
        parameter: 'Asr shadow factor',
        value:
            '1 — first mithl, zawal shadow excluded (Maliki mashhur; Mukhtasar Khalil)',
        status: ChangelogStatus.fiqhDerived,
        changedSince: 'v1.2.0+5 (baseline)',
      ),
      ChangelogRow(
        parameter: 'Sunrise/sunset horizon',
        value: '−0.833° solar depression (upper limb + refraction)',
        status: ChangelogStatus.convention,
        changedSince: 'v1.2.0+5 (baseline)',
      ),
      ChangelogRow(
        parameter: 'Ihtiyat policy',
        value:
            '+1 min on Dhuhr, +1 min on Maghrib; user-toggleable in Settings; fiqh night boundaries stay anchored on the raw solar sunset',
        status: ChangelogStatus.convention,
        changedSince: 'v1.2.0+5 (baseline)',
      ),
      ChangelogRow(
        parameter: 'Rounding',
        value:
            'every solar instant rounded to the nearest minute after the timezone offset is applied; manual adjustments are whole minutes applied after rounding',
        status: ChangelogStatus.convention,
        changedSince: 'v1.2.0+5 (baseline)',
      ),
      ChangelogRow(
        parameter: 'High-latitude fallback',
        value:
            'middle-of-night estimates when a solar event has no solution (polar coherence: whole day on the estimate path when the sun never reaches the horizon); flagged in the UI',
        status: ChangelogStatus.convention,
        changedSince: 'v1.2.0+5 (baseline)',
      ),
      ChangelogRow(
        parameter: 'Time-zone frame',
        value:
            'all displayed times use the device timezone; manual far-away locations are approximate (documented limitation)',
        status: ChangelogStatus.convention,
        changedSince: 'v1.2.0+5 (baseline)',
      ),
    ],
  ),
  ChangelogVersion(
    version: 'v1.3.0+6',
    date: '2026-10-16',
    isBaseline: false,
    rows: [
      ChangelogRow(
        parameter: 'Time-zone frame',
        value:
            "displayed times render in the location's IANA zone: the stored zone for manual locations (chosen in the zone picker, defaulting to the device zone), the device zone for GPS-derived locations; offsets resolved per date so DST transitions are correct per date; bundled tz database latest_all (full IANA coverage, 598 zones, tzdata 2026e), offline-first",
        status: ChangelogStatus.convention,
        changedSince: 'v1.3.0+6 (unreleased)',
      ),
      ChangelogRow(
        parameter: 'Sunrise/sunset horizon',
        value:
            '−0.833° solar depression (upper limb + refraction) plus the elevation dip correction 0.0293×√h (h in meters) when a per-location elevation is set; optional input, unset = sea-level horizon',
        status: ChangelogStatus.convention,
        changedSince: 'v1.3.0+6 (unreleased)',
      ),
      ChangelogRow(
        parameter: 'Calculation profiles',
        value:
            'new "Maliki — Morocco Habous" preset added (Fajr 19°, Isha 17°): institutional preset, NOT a fiqh ruling; methodology unpublished (D1). No engine math changed',
        status: ChangelogStatus.convention,
        changedSince: 'v1.3.0+6 (unreleased)',
      ),
      ChangelogRow(
        parameter: 'Profile evidence badges',
        value:
            'every profile shows per-parameter evidence status (D9): MWL West Africa 18/17 = provisional convention (default); Habous 19/17 and Egyptian 19.5/17.5 = institutional preset; UOIF 12/12 = disputed (12° vs claimed 15°); Asr factor 1 = fiqh-derived on all profiles',
        status: ChangelogStatus.convention,
        changedSince: 'v1.3.0+6 (unreleased)',
      ),
      ChangelogRow(
        parameter: 'Regional auto-adapt',
        value:
            '"Recommended settings": a one-time, dismissible dialog suggests the regional preset matching the detected location (Maghreb → Habous; West Africa → MWL West Africa; Egypt → Egyptian; France → UOIF with its disputed badge); the user confirms — nothing switches silently',
        status: ChangelogStatus.convention,
        changedSince: 'v1.3.0+6 (unreleased)',
      ),
    ],
  ),
];

/// In-app rendering of the calculation changelog.
///
/// Opened as a pushed inner screen (normal back navigation) via
/// [CalculationChangelogScreen.open].
class CalculationChangelogScreen extends StatelessWidget {
  const CalculationChangelogScreen({super.key});

  /// Pushes the changelog screen onto [context]'s navigator.
  static void open(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const CalculationChangelogScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.changelogTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          // Deep-green header card: title + why this record exists.
          Card(
            color: scheme.primary,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.changelogTitle.toUpperCase(),
                    style: AppFonts.eyebrow(context).copyWith(
                      color: scheme.tertiaryFixed,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.changelogIntro,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          for (final entry in changelogVersions) ...[
            _VersionCard(entry: entry),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }
}

/// One version entry: version + date header, optional baseline note, and
/// the parameter rows.
class _VersionCard extends StatelessWidget {
  final ChangelogVersion entry;

  const _VersionCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final scheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    entry.version,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  entry.date,
                  // Dates are plain ISO: pin the Latin font so the digits
                  // never misrender in Nastaleeq.
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.secondary,
                    fontFamily: AppFonts.latinSans,
                  ),
                ),
              ],
            ),
            if (entry.isBaseline) ...[
              const SizedBox(height: 6),
              Text(
                l10n.changelogBaselineNote,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.secondary,
                ),
              ),
            ],
            const SizedBox(height: 8),
            for (final row in entry.rows) _ChangelogRowTile(row: row),
          ],
        ),
      ),
    );
  }
}

/// One parameter row: parameter + status badge, value, and the
/// "changed since" line. The status badge carries the integrity boundary
/// as text — never color alone.
class _ChangelogRowTile extends StatelessWidget {
  final ChangelogRow row;

  const _ChangelogRowTile({required this.row});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final scheme = theme.colorScheme;

    final isFiqh = row.status == ChangelogStatus.fiqhDerived;
    final badgeText =
        isFiqh ? l10n.changelogStatusFiqh : l10n.changelogStatusConvention;
    final badgeBackground =
        isFiqh ? scheme.primaryContainer : scheme.secondaryContainer;
    final badgeForeground =
        isFiqh ? scheme.onPrimary : scheme.onSecondaryContainer;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  row.parameter,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Shrink-to-fit: at large text sizes the badge scales down
              // instead of pushing the row into overflow.
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: badgeBackground,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      badgeText,
                      style: AppFonts.badgeLabel(context).copyWith(
                        color: badgeForeground,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            row.value,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 2),
          Text(
            '${l10n.changelogSinceHeader}: ${row.changedSince}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.secondary,
              // Version strings are Latin-script data: pin the Latin font
              // so the digits never misrender in Nastaleeq.
              fontFamily: AppFonts.latinSans,
            ),
          ),
        ],
      ),
    );
  }
}
