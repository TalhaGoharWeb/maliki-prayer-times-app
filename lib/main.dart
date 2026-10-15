import 'package:flutter/material.dart';
import 'package:malikiprayertimes/engine/coordinates.dart';
import 'package:malikiprayertimes/screens/home_screen.dart';
import 'package:malikiprayertimes/screens/location_screen.dart';
import 'package:malikiprayertimes/screens/monthly_screen.dart';
import 'package:malikiprayertimes/screens/profiles_screen.dart';
import 'package:malikiprayertimes/screens/qibla_screen.dart';
import 'package:malikiprayertimes/screens/settings_screen.dart';
import 'package:malikiprayertimes/services/location_service.dart';
import 'package:malikiprayertimes/services/settings_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = await SettingsService.load();
  final location = await LocationService.load();
  runApp(MalikiPrayerTimesApp(settings: settings, location: location));
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

  const MalikiPrayerTimesApp({
    super.key,
    required this.settings,
    required this.location,
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
    return MaterialApp(
      title: 'Maliki Prayer Times',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: Scaffold(
        body: _currentPage(),
        bottomNavigationBar: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          currentIndex: _index,
          onTap: (i) => setState(() => _index = i),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
            BottomNavigationBarItem(
                icon: Icon(Icons.calendar_month), label: 'Monthly'),
            BottomNavigationBarItem(
                icon: Icon(Icons.explore), label: 'Qibla'),
            BottomNavigationBarItem(
                icon: Icon(Icons.tune), label: 'Profiles'),
            BottomNavigationBarItem(
                icon: Icon(Icons.settings), label: 'Settings'),
          ],
        ),
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
        ),
    };
  }
}

/// Card shown on any tab when no location is set yet. Navigates to the
/// location picker instead of falling back to a default city.
class _ChooseLocationPrompt extends StatelessWidget {
  final LocationService location;

  const _ChooseLocationPrompt({required this.location});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Card(
        margin: const EdgeInsets.all(24),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Choose your location',
                  style: theme.textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(
                'Prayer times are computed for a specific place. Pick your '
                'location to continue.',
                style: theme.textTheme.bodyMedium,
              ),
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
                child: const Text('Set location'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
