/// A named calculation profile: the set of operational conventions the engine
/// applies on top of the astronomical solar model.
///
/// Angles are astronomical conventions approximating legal signs, not fiqh
/// rulings. Every profile here is a PROPOSED research artifact — pending
/// scholarly review — and must be labeled as such wherever it is presented.
enum HighLatitudeRule { middleOfNight }

class PrayerProfile {
  /// Stable identifier, e.g. 'maliki-mwl-west-africa'.
  final String id;

  /// Display name.
  final String name;

  /// One-line scholarly/technical basis naming the source of the conventions.
  final String basis;

  /// Solar depression below the horizon for true dawn, in degrees.
  /// Source: spec §3.1 — MWL Islamic Fiqh Council 1986 decision (18° default);
  /// Egyptian General Authority of Survey (19.5°); UOIF France (12°).
  final double fajrAngle;

  /// Solar depression for Isha (disappearance of the red twilight), in degrees.
  /// Source: spec §3.6 — MWL 1986 decision (17°); Egyptian convention (17.5°);
  /// UOIF (12°).
  final double ishaAngle;

  /// Asr shadow factor t in altitude = arccot(t + tan(|lat − decl|)).
  /// 1.0 = Maliki first mithl (mashhur; Mukhtasar Khalil "لآخر القامة").
  /// Source: spec §3.4.
  final double asrShadowFactor;

  /// Solar depression used for sunrise/sunset (upper limb + refraction).
  /// 0.833° = 50 arc-minutes. Source: spec §3.2/§3.5 — MWL 1986 decision.
  final double solarDepression;

  /// Precautionary delay after solar transit, in minutes.
  /// Source: spec §3.3/§4.2 — MWL fatwa (+2 min); searchtruth.com (+1 min).
  /// A precautionary convention, not part of the fiqh definition.
  final int dhuhrIhtiyatMinutes;

  /// Precautionary delay after sunset, in minutes.
  /// Source: spec §3.5/§4.2 — +0–2 min ihtiyat convention.
  /// A precautionary convention, not part of the fiqh definition.
  final int maghribIhtiyatMinutes;

  const PrayerProfile({
    required this.id,
    required this.name,
    required this.basis,
    required this.fajrAngle,
    required this.ishaAngle,
    required this.asrShadowFactor,
    required this.solarDepression,
    required this.dhuhrIhtiyatMinutes,
    required this.maghribIhtiyatMinutes,
  });
}

/// Named calculation profiles. The default is a PROPOSED profile —
/// pending scholarly review — not a settled or scholar-reviewed method.
class PrayerProfiles {
  static const PrayerProfile malikiMwlWestAfrica = PrayerProfile(
    id: 'maliki-mwl-west-africa',
    name: 'Maliki — MWL West Africa',
    basis:
        'MWL Islamic Fiqh Council 1986: Fajr 18 deg, Isha 17 deg (red twilight); '
        'Asr factor 1 = Maliki first mithl (Mukhtasar Khalil). '
        'Angles are astronomical conventions, not fiqh rulings.',
    fajrAngle: 18.0,
    ishaAngle: 17.0,
    asrShadowFactor: 1.0,
    solarDepression: 0.833,
    dhuhrIhtiyatMinutes: 1,
    maghribIhtiyatMinutes: 1,
  );

  static const PrayerProfile malikiEgyptian = PrayerProfile(
    id: 'maliki-egyptian',
    name: 'Maliki — Egyptian (19.5/17.5)',
    basis:
        'Egyptian General Authority of Survey convention: Fajr 19.5 deg, '
        'Isha 17.5 deg; Asr factor 1 (Maliki). Named alternative.',
    fajrAngle: 19.5,
    ishaAngle: 17.5,
    asrShadowFactor: 1.0,
    solarDepression: 0.833,
    dhuhrIhtiyatMinutes: 1,
    maghribIhtiyatMinutes: 1,
  );

  static const PrayerProfile malikiUoif = PrayerProfile(
    id: 'maliki-uoif',
    name: 'Maliki — UOIF (12/12)',
    basis:
        'UOIF (France) convention: Fajr 12 deg, Isha 12 deg; '
        'Asr factor 1 (Maliki). Named alternative.',
    fajrAngle: 12.0,
    ishaAngle: 12.0,
    asrShadowFactor: 1.0,
    solarDepression: 0.833,
    dhuhrIhtiyatMinutes: 1,
    maghribIhtiyatMinutes: 1,
  );

  static const List<PrayerProfile> all = [
    malikiMwlWestAfrica,
    malikiEgyptian,
    malikiUoif,
  ];

  /// Proposed default profile (pending scholarly review).
  static const PrayerProfile defaultProfile = malikiMwlWestAfrica;
}
