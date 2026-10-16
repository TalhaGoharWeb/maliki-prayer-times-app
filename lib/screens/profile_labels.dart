import 'package:malikiprayertimes/engine/prayer_profile.dart';
import 'package:malikiprayertimes/l10n/app_localizations.dart';

/// Localized display names for the calculation profiles.
///
/// Profiles are immutable engine constants with English `name`/`basis`
/// (used by engine tests); the UI shows these localized equivalents,
/// keyed by the profile's stable [PrayerProfile.id]. An unknown id falls
/// back to the profile's own English name/basis so a newly added profile
/// never renders blank.
({String name, String basis}) profileLabel(
    AppLocalizations l10n, PrayerProfile profile) =>
    switch (profile.id) {
      'maliki-mwl-west-africa' => (
          name: l10n.profileNameMwlWestAfrica,
          basis: l10n.profileBasisMwlWestAfrica,
        ),
      'maliki-egyptian' => (
          name: l10n.profileNameEgyptian,
          basis: l10n.profileBasisEgyptian,
        ),
      'maliki-uoif' => (
          name: l10n.profileNameUoif,
          basis: l10n.profileBasisUoif,
        ),
      'maliki-morocco-habous' => (
          name: l10n.profileNameMoroccoHabous,
          basis: l10n.profileBasisMoroccoHabous,
        ),
      _ => (name: profile.name, basis: profile.basis),
    };

/// A single tunable parameter of a profile, for per-parameter evidence
/// badges. Sunrise/sunset (−0.833°), ihtiyat and rounding are shared
/// conventions, not profile parameters, so they carry no badge here.
enum ProfileParam { fajrAngle, ishaAngle, asrShadowFactor }

/// True for the one profile whose preset angles are disputed in the
/// research (D1 trap register: UOIF 12°/12° vs claimed 15°/15°).
bool profileAnglesDisputed(PrayerProfile profile) =>
    profile.id == 'maliki-uoif';

/// Profile-level evidence status in the D9 vocabulary, shown as a summary
/// badge wherever a profile's name renders (profile list, home profile
/// card, methodology header). No angle is ever presented as a Maliki
/// ruling: the institutional badges say so explicitly.
String profileEvidenceBadge(AppLocalizations l10n, PrayerProfile profile) =>
    switch (profile.id) {
      'maliki-mwl-west-africa' => l10n.evidenceProfileProvisional,
      'maliki-morocco-habous' => l10n.evidenceBadgeInstitutional,
      'maliki-egyptian' => l10n.evidenceBadgeInstitutional,
      'maliki-uoif' => l10n.evidenceBadgeDisputed,
      _ => l10n.evidenceBadgeProvisional,
    };

/// Per-parameter evidence status in the D9 vocabulary. The angle badges
/// follow the profile's evidence standing (provisional convention,
/// institutional preset, or disputed); Asr t=1 is fiqh-derived on every
/// profile (Maliki first mithl, D9 A3 — High confidence).
String parameterEvidenceBadge(
        AppLocalizations l10n, PrayerProfile profile, ProfileParam param) =>
    switch (param) {
      ProfileParam.asrShadowFactor => l10n.evidenceBadgeFiqhDerived,
      ProfileParam.fajrAngle || ProfileParam.ishaAngle => switch (profile.id) {
          'maliki-morocco-habous' => l10n.evidenceBadgeInstitutional,
          'maliki-egyptian' => l10n.evidenceBadgeInstitutional,
          'maliki-uoif' => l10n.evidenceBadgeDisputed,
          _ => l10n.evidenceBadgeProvisional,
        },
    };
