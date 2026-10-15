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
      _ => (name: profile.name, basis: profile.basis),
    };
