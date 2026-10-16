import 'package:malikiprayertimes/l10n/app_localizations.dart';

/// Review-status data model for the scholarly review program (D7).
///
/// Every calculation-profile parameter, fiqh mapping, and unresolved
/// research item carries one of three statuses. Statuses are data only:
/// the app never displays endorsement language, and nothing is marked
/// [ReviewStatus.reviewed] until a scholar's name, date, and verbatim
/// answers have been recorded.
enum ReviewStatus {
  /// The current status of every item: asked of scholars, awaiting answers.
  /// Shown in the UI with a neutral "awaiting review" label — never with
  /// review-banner wording.
  proposed,

  /// A qualified scholar's answers have been recorded (name + date +
  /// the scholar's own words).
  reviewed,

  /// A formal institutional ruling exists and its document is recorded.
  /// This status is never granted by this program's review alone (D7 §D).
  endorsed,
}

/// Grouping of register items, following D7's sections.
enum ReviewGroup {
  /// D7 section A, astronomical conventions: Q1–Q4.
  astronomy,

  /// D7 section B, Maliki jurisprudential mappings: Q5–Q11.
  fiqh,

  /// D7 section C, Mauritanian and regional questions: Q12–Q14.
  regional,

  /// D7 section D, presentation and integrity: Q15–Q18.
  presentation,

  /// D7 section B, pass-2 unresolved research items: P1–P8.
  pass2,
}

/// One question in the scholarly review register.
///
/// The question text, "why it matters", and "current evidence status"
/// live in the .arb files under [questionKey], [whyKey], and
/// [evidenceKey]; this class carries the review state around them.
class ReviewItem {
  /// Register id: 'Q1'..'Q18' or 'P1'..'P8'.
  final String id;

  /// The D7 section this item belongs to.
  final ReviewGroup group;

  /// l10n key for the question text (e.g. 'reviewQ1Question').
  final String questionKey;

  /// l10n key for the "why it matters" text (e.g. 'reviewQ1Why').
  final String whyKey;

  /// l10n key for the "current evidence status" text.
  final String evidenceKey;

  /// Current review status; [ReviewStatus.proposed] until a recorded
  /// review exists.
  final ReviewStatus status;

  /// Full name of the answering scholar, as the scholar writes it.
  final String? reviewerName;

  /// When the answers were given.
  final DateTime? reviewDate;

  /// The scholar's answers in the scholar's own formulation.
  final String? reviewText;

  const ReviewItem({
    required this.id,
    required this.group,
    required this.questionKey,
    required this.whyKey,
    required this.evidenceKey,
    required this.status,
    this.reviewerName,
    this.reviewDate,
    this.reviewText,
  });
}

/// The seeded scholarly review register: the 18 D7 questions plus the
/// 8 pass-2 unresolved items, all [ReviewStatus.proposed] with no
/// reviewer data — no scholar has been approached yet.
abstract final class ReviewRegistry {
  static List<ReviewItem> allItems() => const [
        ReviewItem(
            id: 'Q1',
            group: ReviewGroup.astronomy,
            questionKey: 'reviewQ1Question',
            whyKey: 'reviewQ1Why',
            evidenceKey: 'reviewQ1Evidence',
            status: ReviewStatus.proposed),
        ReviewItem(
            id: 'Q2',
            group: ReviewGroup.astronomy,
            questionKey: 'reviewQ2Question',
            whyKey: 'reviewQ2Why',
            evidenceKey: 'reviewQ2Evidence',
            status: ReviewStatus.proposed),
        ReviewItem(
            id: 'Q3',
            group: ReviewGroup.astronomy,
            questionKey: 'reviewQ3Question',
            whyKey: 'reviewQ3Why',
            evidenceKey: 'reviewQ3Evidence',
            status: ReviewStatus.proposed),
        ReviewItem(
            id: 'Q4',
            group: ReviewGroup.astronomy,
            questionKey: 'reviewQ4Question',
            whyKey: 'reviewQ4Why',
            evidenceKey: 'reviewQ4Evidence',
            status: ReviewStatus.proposed),
        ReviewItem(
            id: 'Q5',
            group: ReviewGroup.fiqh,
            questionKey: 'reviewQ5Question',
            whyKey: 'reviewQ5Why',
            evidenceKey: 'reviewQ5Evidence',
            status: ReviewStatus.proposed),
        ReviewItem(
            id: 'Q6',
            group: ReviewGroup.fiqh,
            questionKey: 'reviewQ6Question',
            whyKey: 'reviewQ6Why',
            evidenceKey: 'reviewQ6Evidence',
            status: ReviewStatus.proposed),
        ReviewItem(
            id: 'Q7',
            group: ReviewGroup.fiqh,
            questionKey: 'reviewQ7Question',
            whyKey: 'reviewQ7Why',
            evidenceKey: 'reviewQ7Evidence',
            status: ReviewStatus.proposed),
        ReviewItem(
            id: 'Q8',
            group: ReviewGroup.fiqh,
            questionKey: 'reviewQ8Question',
            whyKey: 'reviewQ8Why',
            evidenceKey: 'reviewQ8Evidence',
            status: ReviewStatus.proposed),
        ReviewItem(
            id: 'Q9',
            group: ReviewGroup.fiqh,
            questionKey: 'reviewQ9Question',
            whyKey: 'reviewQ9Why',
            evidenceKey: 'reviewQ9Evidence',
            status: ReviewStatus.proposed),
        ReviewItem(
            id: 'Q10',
            group: ReviewGroup.fiqh,
            questionKey: 'reviewQ10Question',
            whyKey: 'reviewQ10Why',
            evidenceKey: 'reviewQ10Evidence',
            status: ReviewStatus.proposed),
        ReviewItem(
            id: 'Q11',
            group: ReviewGroup.fiqh,
            questionKey: 'reviewQ11Question',
            whyKey: 'reviewQ11Why',
            evidenceKey: 'reviewQ11Evidence',
            status: ReviewStatus.proposed),
        ReviewItem(
            id: 'Q12',
            group: ReviewGroup.regional,
            questionKey: 'reviewQ12Question',
            whyKey: 'reviewQ12Why',
            evidenceKey: 'reviewQ12Evidence',
            status: ReviewStatus.proposed),
        ReviewItem(
            id: 'Q13',
            group: ReviewGroup.regional,
            questionKey: 'reviewQ13Question',
            whyKey: 'reviewQ13Why',
            evidenceKey: 'reviewQ13Evidence',
            status: ReviewStatus.proposed),
        ReviewItem(
            id: 'Q14',
            group: ReviewGroup.regional,
            questionKey: 'reviewQ14Question',
            whyKey: 'reviewQ14Why',
            evidenceKey: 'reviewQ14Evidence',
            status: ReviewStatus.proposed),
        ReviewItem(
            id: 'Q15',
            group: ReviewGroup.presentation,
            questionKey: 'reviewQ15Question',
            whyKey: 'reviewQ15Why',
            evidenceKey: 'reviewQ15Evidence',
            status: ReviewStatus.proposed),
        ReviewItem(
            id: 'Q16',
            group: ReviewGroup.presentation,
            questionKey: 'reviewQ16Question',
            whyKey: 'reviewQ16Why',
            evidenceKey: 'reviewQ16Evidence',
            status: ReviewStatus.proposed),
        ReviewItem(
            id: 'Q17',
            group: ReviewGroup.presentation,
            questionKey: 'reviewQ17Question',
            whyKey: 'reviewQ17Why',
            evidenceKey: 'reviewQ17Evidence',
            status: ReviewStatus.proposed),
        ReviewItem(
            id: 'Q18',
            group: ReviewGroup.presentation,
            questionKey: 'reviewQ18Question',
            whyKey: 'reviewQ18Why',
            evidenceKey: 'reviewQ18Evidence',
            status: ReviewStatus.proposed),
        ReviewItem(
            id: 'P1',
            group: ReviewGroup.pass2,
            questionKey: 'reviewP1Question',
            whyKey: 'reviewP1Why',
            evidenceKey: 'reviewP1Evidence',
            status: ReviewStatus.proposed),
        ReviewItem(
            id: 'P2',
            group: ReviewGroup.pass2,
            questionKey: 'reviewP2Question',
            whyKey: 'reviewP2Why',
            evidenceKey: 'reviewP2Evidence',
            status: ReviewStatus.proposed),
        ReviewItem(
            id: 'P3',
            group: ReviewGroup.pass2,
            questionKey: 'reviewP3Question',
            whyKey: 'reviewP3Why',
            evidenceKey: 'reviewP3Evidence',
            status: ReviewStatus.proposed),
        ReviewItem(
            id: 'P4',
            group: ReviewGroup.pass2,
            questionKey: 'reviewP4Question',
            whyKey: 'reviewP4Why',
            evidenceKey: 'reviewP4Evidence',
            status: ReviewStatus.proposed),
        ReviewItem(
            id: 'P5',
            group: ReviewGroup.pass2,
            questionKey: 'reviewP5Question',
            whyKey: 'reviewP5Why',
            evidenceKey: 'reviewP5Evidence',
            status: ReviewStatus.proposed),
        ReviewItem(
            id: 'P6',
            group: ReviewGroup.pass2,
            questionKey: 'reviewP6Question',
            whyKey: 'reviewP6Why',
            evidenceKey: 'reviewP6Evidence',
            status: ReviewStatus.proposed),
        ReviewItem(
            id: 'P7',
            group: ReviewGroup.pass2,
            questionKey: 'reviewP7Question',
            whyKey: 'reviewP7Why',
            evidenceKey: 'reviewP7Evidence',
            status: ReviewStatus.proposed),
        ReviewItem(
            id: 'P8',
            group: ReviewGroup.pass2,
            questionKey: 'reviewP8Question',
            whyKey: 'reviewP8Why',
            evidenceKey: 'reviewP8Evidence',
            status: ReviewStatus.proposed),
      ];

  /// The display order of the groups on the review record screen.
  static List<ReviewGroup> groupOrder() => const [
        ReviewGroup.astronomy,
        ReviewGroup.fiqh,
        ReviewGroup.regional,
        ReviewGroup.presentation,
        ReviewGroup.pass2,
      ];
}

/// Localized group header for [group].
String reviewGroupLabel(AppLocalizations l10n, ReviewGroup group) =>
    switch (group) {
      ReviewGroup.astronomy => l10n.reviewGroupAstronomy,
      ReviewGroup.fiqh => l10n.reviewGroupFiqh,
      ReviewGroup.regional => l10n.reviewGroupRegional,
      ReviewGroup.presentation => l10n.reviewGroupPresentation,
      ReviewGroup.pass2 => l10n.reviewGroupPass2,
    };

/// Neutral, non-claiming status label for [status].
///
/// "Awaiting review" is the only label reachable with the seeded data;
/// the other two exist so a recorded review can be displayed when one
/// exists. None of these claim scholarly approval of the app.
String reviewStatusLabel(AppLocalizations l10n, ReviewStatus status) =>
    switch (status) {
      ReviewStatus.proposed => l10n.reviewStatusProposed,
      ReviewStatus.reviewed => l10n.reviewStatusReviewed,
      ReviewStatus.endorsed => l10n.reviewStatusEndorsed,
    };

/// Localized question text for [item].
String reviewQuestionText(AppLocalizations l10n, ReviewItem item) =>
    switch (item.id) {
      'Q1' => l10n.reviewQ1Question,
      'Q2' => l10n.reviewQ2Question,
      'Q3' => l10n.reviewQ3Question,
      'Q4' => l10n.reviewQ4Question,
      'Q5' => l10n.reviewQ5Question,
      'Q6' => l10n.reviewQ6Question,
      'Q7' => l10n.reviewQ7Question,
      'Q8' => l10n.reviewQ8Question,
      'Q9' => l10n.reviewQ9Question,
      'Q10' => l10n.reviewQ10Question,
      'Q11' => l10n.reviewQ11Question,
      'Q12' => l10n.reviewQ12Question,
      'Q13' => l10n.reviewQ13Question,
      'Q14' => l10n.reviewQ14Question,
      'Q15' => l10n.reviewQ15Question,
      'Q16' => l10n.reviewQ16Question,
      'Q17' => l10n.reviewQ17Question,
      'Q18' => l10n.reviewQ18Question,
      'P1' => l10n.reviewP1Question,
      'P2' => l10n.reviewP2Question,
      'P3' => l10n.reviewP3Question,
      'P4' => l10n.reviewP4Question,
      'P5' => l10n.reviewP5Question,
      'P6' => l10n.reviewP6Question,
      'P7' => l10n.reviewP7Question,
      'P8' => l10n.reviewP8Question,
      _ => '',
    };

/// Localized "why it matters" text for [item].
String reviewWhyText(AppLocalizations l10n, ReviewItem item) =>
    switch (item.id) {
      'Q1' => l10n.reviewQ1Why,
      'Q2' => l10n.reviewQ2Why,
      'Q3' => l10n.reviewQ3Why,
      'Q4' => l10n.reviewQ4Why,
      'Q5' => l10n.reviewQ5Why,
      'Q6' => l10n.reviewQ6Why,
      'Q7' => l10n.reviewQ7Why,
      'Q8' => l10n.reviewQ8Why,
      'Q9' => l10n.reviewQ9Why,
      'Q10' => l10n.reviewQ10Why,
      'Q11' => l10n.reviewQ11Why,
      'Q12' => l10n.reviewQ12Why,
      'Q13' => l10n.reviewQ13Why,
      'Q14' => l10n.reviewQ14Why,
      'Q15' => l10n.reviewQ15Why,
      'Q16' => l10n.reviewQ16Why,
      'Q17' => l10n.reviewQ17Why,
      'Q18' => l10n.reviewQ18Why,
      'P1' => l10n.reviewP1Why,
      'P2' => l10n.reviewP2Why,
      'P3' => l10n.reviewP3Why,
      'P4' => l10n.reviewP4Why,
      'P5' => l10n.reviewP5Why,
      'P6' => l10n.reviewP6Why,
      'P7' => l10n.reviewP7Why,
      'P8' => l10n.reviewP8Why,
      _ => '',
    };

/// Localized "current evidence status" text for [item].
String reviewEvidenceText(AppLocalizations l10n, ReviewItem item) =>
    switch (item.id) {
      'Q1' => l10n.reviewQ1Evidence,
      'Q2' => l10n.reviewQ2Evidence,
      'Q3' => l10n.reviewQ3Evidence,
      'Q4' => l10n.reviewQ4Evidence,
      'Q5' => l10n.reviewQ5Evidence,
      'Q6' => l10n.reviewQ6Evidence,
      'Q7' => l10n.reviewQ7Evidence,
      'Q8' => l10n.reviewQ8Evidence,
      'Q9' => l10n.reviewQ9Evidence,
      'Q10' => l10n.reviewQ10Evidence,
      'Q11' => l10n.reviewQ11Evidence,
      'Q12' => l10n.reviewQ12Evidence,
      'Q13' => l10n.reviewQ13Evidence,
      'Q14' => l10n.reviewQ14Evidence,
      'Q15' => l10n.reviewQ15Evidence,
      'Q16' => l10n.reviewQ16Evidence,
      'Q17' => l10n.reviewQ17Evidence,
      'Q18' => l10n.reviewQ18Evidence,
      'P1' => l10n.reviewP1Evidence,
      'P2' => l10n.reviewP2Evidence,
      'P3' => l10n.reviewP3Evidence,
      'P4' => l10n.reviewP4Evidence,
      'P5' => l10n.reviewP5Evidence,
      'P6' => l10n.reviewP6Evidence,
      'P7' => l10n.reviewP7Evidence,
      'P8' => l10n.reviewP8Evidence,
      _ => '',
    };
