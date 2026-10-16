import 'package:flutter/material.dart';
import 'package:malikiprayertimes/l10n/app_localizations.dart';
import 'package:malikiprayertimes/models/review_status.dart';
import 'package:malikiprayertimes/services/review_packet_service.dart';

/// The in-app scholarly review record.
///
/// Groups the 26 D7 register items (18 questions + 8 pass-2 items) under
/// their D7 section headers; each row shows the localized question and a
/// neutral status badge. Statuses are data only: nothing is marked
/// reviewed until a scholar's name, date, and verbatim answers exist, and
/// the screen never claims endorsement.
///
/// Opened as a pushed inner screen (normal back navigation) via
/// [ReviewRecordScreen.open].
class ReviewRecordScreen extends StatelessWidget {
  /// Test injection for the share action; omitted in production, where the
  /// packet goes through the platform share sheet.
  final Future<void> Function(String text, String subject)? shareFn;

  const ReviewRecordScreen({super.key, this.shareFn});

  /// Pushes the review record screen onto [context]'s navigator.
  static void open(BuildContext context, {Future<void> Function(String text, String subject)? shareFn}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReviewRecordScreen(shareFn: shareFn),
      ),
    );
  }

  /// Plain ISO date (2026-10-16): digits are standard 0-9 in every locale.
  String _dateLabel(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  Color _badgeBackground(ThemeData theme, ReviewStatus status) {
    final scheme = theme.colorScheme;
    return switch (status) {
      ReviewStatus.proposed => scheme.secondaryContainer,
      ReviewStatus.reviewed => scheme.tertiaryContainer,
      ReviewStatus.endorsed => scheme.primaryContainer,
    };
  }

  Color _badgeForeground(ThemeData theme, ReviewStatus status) {
    final scheme = theme.colorScheme;
    return switch (status) {
      ReviewStatus.proposed => scheme.onSecondaryContainer,
      ReviewStatus.reviewed => scheme.onTertiaryContainer,
      ReviewStatus.endorsed => scheme.onPrimary,
    };
  }

  Widget _statusBadge(
      BuildContext context, AppLocalizations l10n, ReviewItem item) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _badgeBackground(theme, item.status),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        reviewStatusLabel(l10n, item.status),
        style: theme.textTheme.labelSmall?.copyWith(
          color: _badgeForeground(theme, item.status),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _reviewerBlock(
      BuildContext context, AppLocalizations l10n, ReviewItem item) {
    final theme = Theme.of(context);
    final name = item.reviewerName;
    if (name == null) return const SizedBox.shrink();
    final lines = <String>[
      '${l10n.reviewReviewer}: $name',
      if (item.reviewDate != null)
        '${l10n.reviewReviewDate}: ${_dateLabel(item.reviewDate!)}',
    ];
    final answer = item.reviewText;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final line in lines)
            Text(line, style: theme.textTheme.bodySmall),
          if (answer != null) ...[
            const SizedBox(height: 4),
            Text('${l10n.reviewAnswer}: $answer',
                style: theme.textTheme.bodyMedium),
          ],
        ],
      ),
    );
  }

  Widget _itemCard(
      BuildContext context, AppLocalizations l10n, ReviewItem item) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    '${item.id}. ${reviewQuestionText(l10n, item)}',
                    style: theme.textTheme.bodyLarge,
                  ),
                ),
                const SizedBox(width: 10),
                _statusBadge(context, l10n, item),
              ],
            ),
            _reviewerBlock(context, l10n, item),
          ],
        ),
      ),
    );
  }

  Widget _groupSection(
      BuildContext context, AppLocalizations l10n, ReviewGroup group) {
    final theme = Theme.of(context);
    final items =
        ReviewRegistry.allItems().where((i) => i.group == group).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 4),
          child: Text(
            reviewGroupLabel(l10n, group).toUpperCase(),
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
        ),
        for (final item in items) _itemCard(context, l10n, item),
      ],
    );
  }

  Future<void> _share(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    await shareReviewPacket(l10n: l10n, shareFn: shareFn);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.reviewTitle)),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              l10n.reviewIntro,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          for (final group in ReviewRegistry.groupOrder())
            _groupSection(context, l10n, group),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
            child: FilledButton.icon(
              onPressed: () => _share(context),
              icon: const Icon(Icons.ios_share),
              label: Text(l10n.reviewSharePacket),
            ),
          ),
        ],
      ),
    );
  }
}
