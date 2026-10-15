import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:malikiprayertimes/engine/coordinates.dart';
import 'package:malikiprayertimes/engine/prayer_times.dart';
import 'package:malikiprayertimes/l10n/app_localizations.dart';
import 'package:malikiprayertimes/screens/home_screen.dart';
import 'package:malikiprayertimes/screens/location_screen.dart';
import 'package:malikiprayertimes/screens/monthly_screen.dart';
import 'package:malikiprayertimes/screens/profiles_screen.dart';
import 'package:malikiprayertimes/screens/qibla_screen.dart';
import 'package:malikiprayertimes/screens/settings_screen.dart';
import 'package:malikiprayertimes/screens/splash_screen.dart';
import 'package:malikiprayertimes/services/location_service.dart';
import 'package:malikiprayertimes/services/notification_service.dart';
import 'package:malikiprayertimes/services/settings_service.dart';
import 'package:malikiprayertimes/utils/fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Immediate deep-green brand splash while the services load; replaced by
  // the main app below. Widget tests pump MalikiPrayerTimesApp directly and
  // never see this.
  final splashStart = DateTime.now();
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: SplashScreen(),
    ),
  );
  // Load in parallel — never sequential awaits on the launch path.
  final (settings, location) = await (
    SettingsService.load(),
    LocationService.load(),
  ).wait;
  final notifications = NotificationService(
    scheduler: PluginNotificationScheduler(),
  );
  // Brief brand moment, but never slower than the actual init: only wait
  // out the remainder of a short minimum so the splash can't flash by.
  final elapsed = DateTime.now().difference(splashStart);
  const minSplash = Duration(milliseconds: 700);
  if (elapsed < minSplash) {
    await Future<void>.delayed(minSplash - elapsed);
  }
  runApp(MalikiPrayerTimesApp(
    settings: settings,
    location: location,
    notifications: notifications,
  ));
}

/// Root of the Maliki prayer-times app (standalone).
///
/// The [SettingsService] and [LocationService] are loaded once in [main] and
/// passed down through constructors (no provider package). This shell listens
/// to both services so every tab rebuilds when the location or settings
/// change. The app chrome — top bar and bottom navigation — lives here;
/// individual tab screens render body content only.
class MalikiPrayerTimesApp extends StatefulWidget {
  final SettingsService settings;
  final LocationService location;

  /// Null in widget tests, where no real notification plugin exists.
  final NotificationService? notifications;

  const MalikiPrayerTimesApp({
    super.key,
    required this.settings,
    required this.location,
    this.notifications,
  });

  @override
  State<MalikiPrayerTimesApp> createState() => _MalikiPrayerTimesAppState();
}

class _MalikiPrayerTimesAppState extends State<MalikiPrayerTimesApp> {
  int _index = 0;

  /// Guard so the notification permission prompt appears exactly once.
  static const _notifAskedKey = 'notif_permission_asked_v1';

  @override
  void initState() {
    super.initState();
    widget.settings.addListener(_onServicesChanged);
    widget.location.addListener(_onServicesChanged);
    _askNotificationPermissionOnce();
  }

  /// Asks for notification permission right after the splash closes, once
  /// ever. Skipped in widget tests (no real notification plugin there).
  Future<void> _askNotificationPermissionOnce() async {
    final notifications = widget.notifications;
    if (notifications == null) return;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_notifAskedKey) == true) return;
    await notifications.requestPermissions();
    await prefs.setBool(_notifAskedKey, true);
  }

  @override
  void dispose() {
    widget.settings.removeListener(_onServicesChanged);
    widget.location.removeListener(_onServicesChanged);
    super.dispose();
  }

  void _onServicesChanged() {
    if (mounted) setState(() {});
  }

  String _screenTitle(AppLocalizations l10n) => switch (_index) {
        0 => l10n.navHome,
        1 => l10n.navMonthly,
        2 => l10n.navQibla,
        3 => l10n.navProfiles,
        _ => l10n.navSettings,
      };

  void _openLocation(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LocationScreen(locationService: widget.location),
      ),
    );
  }

  /// Exit confirmation shown on the home tab's back press.
  Future<void> _confirmExit(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final exit = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.exitAppTitle),
        content: Text(l10n.exitAppMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.exitAppCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.exitAppExit),
          ),
        ],
      ),
    );
    if (exit == true) await SystemNavigator.pop();
  }

  /// The global top bar.
  ///
  /// Two zones: the brand block (app logo + "Maliki Prayer" wordmark +
  /// Arabic subtitle) gets the full toolbar row, so the Arabic subtitle
  /// renders in full and wraps (never truncates) even at large text sizes;
  /// below it, a strip carries the current screen title and the tappable
  /// location chip. The bar grows with the system text scale so the brand
  /// block never overflows; the chip keeps its full name in its
  /// tooltip/semantics label.
  PreferredSizeWidget _topBar(
      BuildContext context, AppLocalizations l10n, ThemeData theme) {
    final scheme = theme.colorScheme;
    final loc = widget.location.current;
    final locationName = loc == null
        ? l10n.setLocation
        : loc.displayName(l10n.deviceLocationName);
    // Taller at large text scales: the brand block can wrap to two lines.
    final textScale = MediaQuery.textScalerOf(context).scale(1.0);
    return AppBar(
      toolbarHeight: (78 * textScale).clamp(78.0, 150.0),
      titleSpacing: 16,
      title: Row(
        children: [
          ClipOval(
            child: Image.asset(
              'assets/branding/compass_mark.jpg',
              width: 46,
              height: 46,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Maliki Prayer',
                  style: theme.textTheme.headlineSmall,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                const SizedBox(height: 2),
                Text(
                  'أوقات الصلاة المالكية',
                  style: TextStyle(
                    fontFamily: AppFonts.arabic,
                    fontSize: 13,
                    color: scheme.onSurfaceVariant,
                  ),
                  // Wraps instead of truncating: the subtitle is never cut.
                  softWrap: true,
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ],
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(49),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _screenTitle(l10n).toUpperCase(),
                      style: AppFonts.eyebrow(context).copyWith(
                        color: scheme.secondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _LocationChip(
                    label: locationName,
                    onTap: () => _openLocation(context),
                  ),
                ],
              ),
            ),
            Container(height: 1, color: scheme.outlineVariant),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // A null locale lets Flutter resolve from the device locales against
    // supportedLocales; a saved language code pins the UI to it.
    final code = widget.settings.languageCode;
    final locale = code == null ? null : Locale(code);
    return MaterialApp(
      title: 'Maliki Prayer Times',
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
        Locale('ur'),
        Locale('ar'),
        Locale('fr'),
      ],
      locale: locale,
      theme: AppFonts.themeFor(locale, seedColor: Colors.teal),
      // The design is light-mode-only: never follow the platform into dark
      // mode (dark scaffold + light cards rendered screens unreadable).
      themeMode: ThemeMode.light,
      // The Builder gives a context below MaterialApp, where the
      // localizations are available (the State's own context is above it).
      // _NotificationBootstrap initializes notifications once that context
      // exists and reschedules whenever location or settings change.
      home: Builder(
        builder: (context) {
          final l10n = AppLocalizations.of(context)!;
          final theme = Theme.of(context);
          final notifications = widget.notifications;
          final scaffold = Scaffold(
            appBar: _topBar(context, l10n, theme),
            body: _currentPage(l10n),
            bottomNavigationBar: BottomNavigationBar(
              type: BottomNavigationBarType.fixed,
              currentIndex: _index,
              onTap: (i) => setState(() => _index = i),
              selectedFontSize: 11,
              unselectedFontSize: 11,
              items: [
                BottomNavigationBarItem(
                    icon: const Icon(Icons.house), label: l10n.navHome),
                BottomNavigationBarItem(
                    icon: const Icon(Icons.calendar_month),
                    label: l10n.navMonthly),
                BottomNavigationBarItem(
                    icon: const Icon(Icons.explore), label: l10n.navQibla),
                BottomNavigationBarItem(
                    icon: const Icon(Icons.tune), label: l10n.navProfiles),
                BottomNavigationBarItem(
                    icon: const Icon(Icons.settings),
                    label: l10n.navSettings),
              ],
            ),
          );
          // Widget tests pass no NotificationService: skip bootstrapping.
          // On the home tab the system back button asks for exit
          // confirmation; pushed inner screens keep normal back navigation
          // (the top route handles its own pop before this scope is reached).
          final scoped = PopScope(
            canPop: _index != 0,
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop && _index == 0) _confirmExit(context);
            },
            child: scaffold,
          );
          if (notifications == null) return scoped;
          return _NotificationBootstrap(
            notifications: notifications,
            settings: widget.settings,
            location: widget.location,
            child: scoped,
          );
        },
      ),
    );
  }

  Widget _currentPage(AppLocalizations l10n) {
    // Device-timezone frame: every computation in this app uses
    // `DateTime.now().timeZoneOffset`. Manual far-away locations are
    // therefore approximate — a documented limitation.
    final offset = DateTime.now().timeZoneOffset;
    final loc = widget.location.current;
    final profile = widget.settings.effectiveProfile;

    if (_index == 0) {
      return HomeScreen(
        settings: widget.settings,
        location: widget.location,
      );
    }
    // The non-Home tabs need coordinates: show the choose-location prompt
    // instead of silently falling back to a default city.
    if (loc == null) {
      return _ChooseLocationPrompt(location: widget.location);
    }
    final coords = Coordinates(loc.latitude, loc.longitude);
    return switch (_index) {
      1 => MonthlyScreen(
          coordinates: coords,
          profile: profile,
          timeZoneOffset: offset,
        ),
      2 => QiblaScreen(
          coordinates: coords,
          locationName: loc.displayName(l10n.deviceLocationName),
          timeZoneOffset: offset,
          notifications: widget.notifications,
        ),
      3 => ProfilesScreen(
          settings: widget.settings,
          coordinates: coords,
          timeZoneOffset: offset,
        ),
      _ => SettingsScreen(
          settings: widget.settings,
          coordinates: coords,
          timeZoneOffset: offset,
          notifications: widget.notifications,
        ),
    };
  }
}

/// Compact location chip used in the top bar: near_me icon + short name.
/// Tapping opens the location picker. Never a dead button.
class _LocationChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _LocationChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // The visible label ellipsizes, but the full location name is always
    // available via tooltip and semantics.
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        label: label,
        child: Material(
          color: scheme.secondaryContainer,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 8, 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.near_me,
                      size: 16, color: scheme.onSecondaryContainer),
                  const SizedBox(width: 6),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 150),
                    child: Text(
                      label,
                      style:
                          Theme.of(context).textTheme.labelMedium?.copyWith(
                                color: scheme.onSecondaryContainer,
                              ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  Icon(Icons.chevron_right,
                      size: 16, color: scheme.onSecondaryContainer),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Initializes the notification plugin once the localizations are available
/// and reschedules notifications whenever the location or settings change.
///
/// Notification delivery is best-effort: Android Doze/battery optimization
/// and iOS background limits can delay or drop notifications. The settings
/// screen says this plainly instead of promising exact delivery.
class _NotificationBootstrap extends StatefulWidget {
  final NotificationService notifications;
  final SettingsService settings;
  final LocationService location;
  final Widget child;

  const _NotificationBootstrap({
    required this.notifications,
    required this.settings,
    required this.location,
    required this.child,
  });

  @override
  State<_NotificationBootstrap> createState() => _NotificationBootstrapState();
}

class _NotificationBootstrapState extends State<_NotificationBootstrap> {
  @override
  void initState() {
    super.initState();
    widget.settings.addListener(_reschedule);
    widget.location.addListener(_reschedule);
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  @override
  void dispose() {
    widget.settings.removeListener(_reschedule);
    widget.location.removeListener(_reschedule);
    super.dispose();
  }

  Future<void> _init() async {
    if (!mounted) return;
    final texts = _notificationTexts(AppLocalizations.of(context)!);
    await widget.notifications.init(texts: texts);
    await _reschedule();
  }

  Future<void> _reschedule() async {
    if (!mounted) return;
    final loc = widget.location.current;
    if (loc == null) return;
    final texts = _notificationTexts(AppLocalizations.of(context)!);
    await widget.notifications.rescheduleAll(
      coords: Coordinates(loc.latitude, loc.longitude),
      profile: widget.settings.effectiveProfile,
      settings: widget.settings,
      timeZoneOffset: DateTime.now().timeZoneOffset,
      texts: texts,
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Builds localized notification strings from the app localizations.
NotificationTexts _notificationTexts(AppLocalizations l10n) {
  String prayerName(Prayer p) => switch (p) {
        Prayer.fajr => l10n.prayerFajr,
        Prayer.sunrise => l10n.prayerSunrise,
        Prayer.dhuhr => l10n.prayerDhuhr,
        Prayer.asr => l10n.prayerAsr,
        Prayer.maghrib => l10n.prayerMaghrib,
        Prayer.isha => l10n.prayerIsha,
      };
  return NotificationTexts(
    titleFor: (p) => l10n.notifTitle(prayerName(p)),
    bodyFor: (p) => l10n.notifBody(prayerName(p)),
    reminderTitleFor: (p, m) => l10n.notifReminderTitle(prayerName(p), '$m'),
    reminderBodyFor: (p, m) => l10n.notifReminderBody(prayerName(p), '$m'),
  );
}

/// Card shown on any tab when no location is set yet. Navigates to the
/// location picker instead of falling back to a default city.
class _ChooseLocationPrompt extends StatelessWidget {
  final LocationService location;

  const _ChooseLocationPrompt({required this.location});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final scheme = theme.colorScheme;
    return Center(
      child: Card(
        margin: const EdgeInsets.all(24),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: scheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.near_me,
                    color: scheme.onSecondaryContainer, size: 24),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.chooseLocationTitle,
                style: theme.textTheme.displaySmall,
              ),
              const SizedBox(height: 8),
              Text(l10n.chooseLocationBody, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          LocationScreen(locationService: location),
                    ),
                  );
                },
                icon: const Icon(Icons.add_location_alt),
                label: Text(l10n.setLocation),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
