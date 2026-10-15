import 'package:flutter/material.dart';
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
import 'package:malikiprayertimes/services/location_service.dart';
import 'package:malikiprayertimes/services/notification_service.dart';
import 'package:malikiprayertimes/services/settings_service.dart';
import 'package:malikiprayertimes/utils/fonts.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = await SettingsService.load();
  final location = await LocationService.load();
  final notifications = NotificationService(
    scheduler: PluginNotificationScheduler(),
  );
  runApp(MalikiPrayerTimesApp(
    settings: settings,
    location: location,
    notifications: notifications,
  ));
}

/// Root of the Maliki prayer-times app (standalone, Milestone 2).
///
/// The [SettingsService] and [LocationService] are loaded once in [main] and
/// passed down through constructors (no provider package). This shell listens
/// to both services so every tab rebuilds when the location or settings
/// change.
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

  @override
  void initState() {
    super.initState();
    widget.settings.addListener(_onServicesChanged);
    widget.location.addListener(_onServicesChanged);
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
      // The Builder gives a context below MaterialApp, where the
      // localizations are available (the State's own context is above it).
      // _NotificationBootstrap initializes notifications once that context
      // exists and reschedules whenever location or settings change.
      home: Builder(
        builder: (context) {
          final l10n = AppLocalizations.of(context)!;
          final notifications = widget.notifications;
          final scaffold = Scaffold(
            body: _currentPage(),
            bottomNavigationBar: BottomNavigationBar(
              type: BottomNavigationBarType.fixed,
              currentIndex: _index,
              onTap: (i) => setState(() => _index = i),
              items: [
                BottomNavigationBarItem(
                    icon: const Icon(Icons.home), label: l10n.navHome),
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
          if (notifications == null) return scaffold;
          return _NotificationBootstrap(
            notifications: notifications,
            settings: widget.settings,
            location: widget.location,
            child: scaffold,
          );
        },
      ),
    );
  }

  Widget _currentPage() {
    // Device-timezone frame: every computation in this app uses
    // `DateTime.now().timeZoneOffset`. Manual far-away locations are
    // therefore approximate — a documented Milestone 2 limitation.
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
          locationName: loc.name,
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
    return Center(
      child: Card(
        margin: const EdgeInsets.all(24),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.chooseLocationTitle,
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(l10n.chooseLocationBody, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          LocationScreen(locationService: location),
                    ),
                  );
                },
                child: Text(l10n.setLocation),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
