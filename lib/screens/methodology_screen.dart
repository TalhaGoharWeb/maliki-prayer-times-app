import 'package:flutter/material.dart';
import 'package:malikiprayertimes/engine/prayer_profile.dart';
import 'package:malikiprayertimes/l10n/app_localizations.dart';
import 'package:malikiprayertimes/screens/methodology_texts.dart';
import 'package:malikiprayertimes/screens/profile_labels.dart';
import 'package:malikiprayertimes/utils/fonts.dart';

/// Methodology screen: the full method table (D1 Part IV) rendered from
/// [methodologyTexts], grouped into fiqh-derived rules and institutional /
/// software conventions, every row carrying its status badge.
///
/// The status badge is the integrity boundary: software conventions
/// (18°/17°, −0.833°, ihtiyat minutes, rounding, high-latitude fallback)
/// are NEVER presented as Maliki rulings — in code comments, UI strings,
/// or docs. The header names the profile, the method version, and the data
/// vintage so every displayed time is traceable.
///
/// This screen renders body content only — the app chrome lives in
/// [MalikiPrayerTimesApp]. Navigation wiring is done by a later worker.
class MethodologyScreen extends StatelessWidget {
  /// The calculation profile the table documents.
  final PrayerProfile profile;

  const MethodologyScreen({
    super.key,
    this.profile = PrayerProfiles.defaultProfile,
  });

  /// Pushes the methodology screen with its app chrome onto [context]'s
  /// navigator. The screen itself renders body content only, so the route
  /// wraps it in a Scaffold whose title comes from the localized
  /// methodology strings (same locale the body uses).
  static void open(BuildContext context,
      {PrayerProfile profile = PrayerProfiles.defaultProfile}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) {
          final s = methodologyStrings(
              Localizations.localeOf(ctx).languageCode);
          return Scaffold(
            appBar: AppBar(title: Text(s.title)),
            body: MethodologyScreen(profile: profile),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final code = Localizations.localeOf(context).languageCode;
    final l10n = AppLocalizations.of(context)!;
    final s = methodologyStrings(code);
    final fiqhRows = methodologyRows
        .where((r) => r.status == MethodStatus.fiqhDerived)
        .toList();
    final convRows = methodologyRows
        .where((r) => r.status == MethodStatus.convention)
        .toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        _headerCard(context, s, l10n),
        const SizedBox(height: 16),
        _integrityCard(context, s),
        const SizedBox(height: 16),
        _section(context, s, s.fiqhSection, fiqhRows),
        const SizedBox(height: 16),
        _section(context, s, s.conventionSection, convRows),
      ],
    );
  }

  /// Deep-green header card: title, profile name + evidence badge, method
  /// version, vintage.
  Widget _headerCard(
      BuildContext context, MethodologyStrings s, AppLocalizations l10n) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.primary,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              s.title.toUpperCase(),
              style: AppFonts.eyebrow(context).copyWith(
                color: scheme.tertiaryFixed,
              ),
            ),
            const SizedBox(height: 8),
            // Localized profile name with its D9 evidence badge — e.g. the
            // Habous profile always renders as "Institutional preset — not
            // a fiqh ruling" here too.
            _headerLine(
              context,
              s.profileLabel,
              '${profileLabel(l10n, profile).name} — '
              '${profileEvidenceBadge(l10n, profile)}',
            ),
            const SizedBox(height: 4),
            _headerLine(context, s.versionLabel, s.versionValue),
            const SizedBox(height: 4),
            _headerLine(context, s.vintageLabel, s.vintageValue),
          ],
        ),
      ),
    );
  }

  Widget _headerLine(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Text.rich(
      TextSpan(
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onPrimary,
        ),
        children: [
          TextSpan(
            text: '$label: ',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          TextSpan(text: value),
        ],
      ),
    );
  }

  /// Gold integrity card: the conventions-are-not-rulings distinction,
  /// stated once and unmistakably.
  Widget _integrityCard(BuildContext context, MethodologyStrings s) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.tertiaryFixed,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.verified_outlined,
                color: scheme.onTertiaryFixed, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                s.integrityNote,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onTertiaryFixed,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// One table section: eyebrow header plus an expandable card per row.
  Widget _section(
    BuildContext context,
    MethodologyStrings s,
    String heading,
    List<MethodologyRow> rows,
  ) {
    final code = Localizations.localeOf(context).languageCode;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          heading.toUpperCase(),
          style: AppFonts.eyebrow(context).copyWith(
            color: Theme.of(context).colorScheme.secondary,
          ),
        ),
        const SizedBox(height: 8),
        for (final row in rows) _rowCard(context, s, code, row),
      ],
    );
  }

  /// One method-table row: parameter, value, status badge; tap expands to
  /// show the source/limits detail line.
  Widget _rowCard(
    BuildContext context,
    MethodologyStrings s,
    String code,
    MethodologyRow row,
  ) {
    final text = methodologyText(code, row.id);
    final badge = methodologyBadgeText(code, row.status);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _badge(context, scheme, row.status, badge),
            const SizedBox(height: 6),
            Text(text.parameter, style: theme.textTheme.titleSmall),
          ],
        ),
        subtitle: Text(
          text.value,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.secondary,
          ),
        ),
        children: [
          Text(
            text.detail,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  /// Status badge: deep green for fiqh-derived rules, gold for conventions.
  Widget _badge(
    BuildContext context,
    ColorScheme scheme,
    MethodStatus status,
    String label,
  ) {
    final bool fiqh = status == MethodStatus.fiqhDerived;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: fiqh ? scheme.primaryContainer : scheme.tertiaryFixed,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: AppFonts.badgeLabel(context).copyWith(
          color: fiqh ? scheme.onPrimary : scheme.onTertiaryFixed,
        ),
      ),
    );
  }
}
