import 'prayer_times.dart';

/// High-latitude fallback methods for days when a solar event has no
/// solution (|cos H| > 1).
///
/// ## Integrity boundary
/// Every value here is an **institutional/software convention** — the
/// research found no Maliki body prescribing any high-latitude method
/// (D1 Strand D negative finding; D5 §3.7). They are NEVER Maliki rulings,
/// and the UI must label them as conventions wherever they appear.
///
/// The default is [middleOfNight], matching adhan's
/// `HighLatitudeRule.recommended()`.
enum HighLatitudeFallback {
  /// Fajr and Isha both at the night midpoint: `fajr = sunrise − N/2`,
  /// `isha = sunset + N/2`, where N is the night each event belongs to
  /// (D5 §3.7). The default.
  middleOfNight,

  /// `fajr = sunrise − N/7`, `isha = sunset + N/7` (D5 §3.7).
  oneSeventhOfNight,

  /// A twilight-angle-proportional portion of the night:
  /// `fajr = sunrise − (fajrAngle/60)·N`,
  /// `isha = sunset + (ishaAngle/60)·N` (D5 §3.7).
  angleBased,

  /// Times are borrowed whole from the nearest day on which every event
  /// has a solution (search ±183 days — half a year, so the convention
  /// works where it is needed most; past preferred on ties); the source
  /// date is recorded on [PrayerTimes.nearestDaySourceDate] and must be
  /// shown. The only method usable when no night frame exists at all
  /// (adhan's AqrabYaum idea; D5 §4.3 case c1).
  nearestDay,
}

/// Why a day's prayer times have no solution.
enum NoSolutionReason {
  /// The sun never sets on this date: no night frame exists, so no
  /// fallback can be constructed from sunset/sunrise (D5 §4.3 case c1,
  /// Tromsø 2026-06-21).
  polarDay,

  /// The sun never rises on this date: the solar-day frame is absent.
  /// Twilight-based Fajr/Isha may be mathematically solvable, but the
  /// honest default is to suppress the day pending scholarly review of
  /// the partial-day question (D5 §5 E5).
  polarNight,
}

/// The typed outcome of [calculatePrayerTimes]: either a computed day or
/// an explicit, typed absence. A calculation failure NEVER produces a
/// plausible-but-unsupported time — the UI renders [PrayerTimesNoSolution]
/// as an honest empty state.
sealed class PrayerTimesResult {
  const PrayerTimesResult();
}

/// One day of prayer times was computed (possibly with a labeled
/// high-latitude fallback — see [PrayerTimes.fallbackMethod]).
final class PrayerTimesComputed extends PrayerTimesResult {
  final PrayerTimes times;

  const PrayerTimesComputed(this.times);
}

/// No times could be computed for the date and location. The UI must show
/// an honest unavailable state and offer the fallback choice — never a
/// fabricated time.
final class PrayerTimesNoSolution extends PrayerTimesResult {
  final NoSolutionReason reason;

  const PrayerTimesNoSolution(this.reason);
}
