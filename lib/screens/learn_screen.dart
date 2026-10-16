import 'package:flutter/material.dart';
import 'package:malikiprayertimes/screens/learn_texts.dart';
import 'package:malikiprayertimes/utils/fonts.dart';

/// Learn screen (Phase 4): the "Enseignement" teaching section (Tawqit
/// pattern). Five sections — the five prayers' Maliki definitions with
/// verbatim classical Arabic passages, the 18° classical pedigree with
/// its honest boundary, dawn-observation studies, a FAQ, and a glossary.
///
/// Integrity: every block names its D1/D4 evidence; modern conventions
/// are labeled conventions inside the bodies. The header note says what
/// this section is NOT (teaching material, not fiqh rulings; nothing
/// reviewed by a qualified Maliki scholar). The screen renders body
/// content only — the app chrome lives in [MalikiPrayerTimesApp].
class LearnScreen extends StatelessWidget {
  const LearnScreen({super.key});

  /// Pushes the learn screen with its app chrome onto [context]'s
  /// navigator. The screen itself renders body content only, so the route
  /// wraps it in a Scaffold whose title comes from the localized learn
  /// strings (same locale the body uses).
  static void open(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) {
          final s =
              learnStrings(Localizations.localeOf(ctx).languageCode);
          return Scaffold(
            appBar: AppBar(title: Text(s.title)),
            body: const LearnScreen(),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final code = Localizations.localeOf(context).languageCode;
    final s = learnStrings(code);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        _headerCard(context, code, s),
        const SizedBox(height: 16),
        _integrityCard(context, s),
        const SizedBox(height: 16),
        for (final section in learnSections)
          _section(context, code, section),
      ],
    );
  }

  /// Deep-green header card: section title and what this screen is for.
  Widget _headerCard(BuildContext context, String code, LearnStrings s) {
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
            Text(
              _headerSubtitle(code),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onPrimary,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  /// One-line purpose subtitle under the header title, per locale.
  String _headerSubtitle(String code) => switch (code) {
        'ur' =>
          'پانچ نمازوں کی مالکی تعریفیں، 18 ڈگری کا سوال، اور عام سوالات — '
              'سب تحقیقی شواہد سے منسلک۔',
        'ar' =>
          'تعريفات مالكية للصلوات الخمس، ومسألة الـ18 درجة، والأسئلة '
              'الشائعة — كلها موصولة بأدلة البحث.',
        'fr' =>
          'Définitions malikites des cinq prières, la question des 18° et '
              'les questions fréquentes — le tout lié aux preuves de la '
              'recherche.',
        _ =>
          'Maliki definitions of the five prayers, the 18° question, and '
              'common questions — all linked to the research evidence.',
      };

  /// Gold integrity card: teaching, not rulings; nothing reviewed.
  Widget _integrityCard(BuildContext context, LearnStrings s) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.tertiaryFixed,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.school_outlined,
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

  /// One teaching section: eyebrow heading, intro, one expansion tile per
  /// block, and the section's evidence-reference line.
  Widget _section(BuildContext context, String code, LearnSection section) {
    final content = learnContent(code, section.id);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            content.title.toUpperCase(),
            style: AppFonts.eyebrow(context).copyWith(
              color: Theme.of(context).colorScheme.secondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content.intro,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 8),
          for (final block in content.blocks)
            _blockCard(context, block),
          _evidenceLine(
              context, learnSectionRefs(code, section.id)),
        ],
      ),
    );
  }

  /// One block: title; tap expands to the Arabic passage (when present),
  /// the body, and the block's evidence references.
  Widget _blockCard(BuildContext context, LearnBlock block) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        title: Text(block.title, style: theme.textTheme.titleSmall),
        children: [
          if (block.arabic.isNotEmpty) ...[
            _arabicQuote(context, block.arabic),
            const SizedBox(height: 10),
          ],
          Text(
            block.body,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          _evidenceLine(context, block.refs),
        ],
      ),
    );
  }

  /// The classical passage: right-to-left, in Amiri, set off on a tinted
  /// card so verbatim quotations are visually distinct from the teaching
  /// body.
  Widget _arabicQuote(BuildContext context, String passage) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        passage,
        textDirection: TextDirection.rtl,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontFamily: AppFonts.arabic,
              height: 1.9,
            ),
      ),
    );
  }

  /// Evidence references: small icon + the D1/D4 reference line, so every
  /// block visibly names the evidence behind its claims.
  Widget _evidenceLine(BuildContext context, String refs) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.article_outlined,
            size: 14, color: scheme.secondary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            refs,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.secondary,
                ),
          ),
        ),
      ],
    );
  }
}
