import 'package:malikiprayertimes/l10n/app_localizations.dart';
import 'package:malikiprayertimes/models/review_status.dart';
import 'package:share_plus/share_plus.dart';

/// Builds the D7 scholarly-review question pack as Markdown, for the
/// user's scholar outreach.
///
/// The packet is built in the language carried by [l10n] (English,
/// Arabic, or French — the .arb translations are faithful renderings of
/// the D7 questions; no new fiqh claims). Fixed Arabic terms stay Arabic
/// in every language. [packetDate] defaults to today; digits are the
/// standard 0-9 in every locale.
String buildReviewPacket(AppLocalizations l10n, {DateTime? packetDate}) {
  final date = packetDate ?? DateTime.now();
  final dateLabel = '${date.year}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
  final buf = StringBuffer()
    ..writeln('# ${l10n.reviewPacketTitle}')
    ..writeln()
    ..writeln('${l10n.reviewPacketDate}: $dateLabel')
    ..writeln()
    ..writeln(l10n.reviewPacketIntro)
    ..writeln();
  for (final group in ReviewRegistry.groupOrder()) {
    buf
      ..writeln('## ${reviewGroupLabel(l10n, group)}')
      ..writeln();
    for (final item
        in ReviewRegistry.allItems().where((i) => i.group == group)) {
      buf
        ..writeln('### ${item.id}')
        ..writeln()
        ..writeln(reviewQuestionText(l10n, item))
        ..writeln()
        ..writeln('**${l10n.reviewPacketWhy}:** ${reviewWhyText(l10n, item)}')
        ..writeln()
        ..writeln(
            '**${l10n.reviewPacketEvidence}:** ${reviewEvidenceText(l10n, item)}')
        ..writeln()
        ..writeln(
            '**${l10n.reviewPacketAnswerPrompt}:** _${reviewStatusLabel(l10n, item.status)}_')
        ..writeln();
    }
  }
  return buf.toString();
}

/// Shares the review packet built for [l10n] through the platform share
/// sheet, as plain-text Markdown.
///
/// [shareFn] is an injection point for tests; when omitted, the share
/// goes through share_plus's [SharePlus.instance].
Future<void> shareReviewPacket({
  required AppLocalizations l10n,
  DateTime? packetDate,
  Future<void> Function(String text, String subject)? shareFn,
}) async {
  final text = buildReviewPacket(l10n, packetDate: packetDate);
  final subject = l10n.reviewPacketTitle;
  await (shareFn ?? _defaultShare)(text, subject);
}

Future<void> _defaultShare(String text, String subject) {
  return SharePlus.instance.share(ShareParams(text: text, subject: subject));
}
