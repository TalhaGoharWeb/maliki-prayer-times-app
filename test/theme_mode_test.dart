import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:malikiprayertimes/main.dart';
import 'package:malikiprayertimes/services/location_service.dart';
import 'package:malikiprayertimes/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The design is light-mode-only: the app must never follow the platform
/// into dark mode (a dark scaffold with light cards rendered screens
/// unreadable on real devices).
void main() {
  testWidgets('app forces light theme even on a dark platform',
      (tester) async {
    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(platformBrightness: Brightness.dark),
        child: _TestApp(),
      ),
    );
    // Home runs a 1-second countdown timer: pump manually instead of
    // pumpAndSettle (which would time out on the periodic timer).
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.takeException(), isNull);

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.light,
        reason: 'MaterialApp must pin themeMode to light');
    final context = tester.element(find.byType(Scaffold).first);
    expect(Theme.of(context).brightness, Brightness.light,
        reason: 'resolved theme must be light on a dark platform');
  });
}

/// Loads the real services, then builds the real app shell.
class _TestApp extends StatefulWidget {
  const _TestApp();

  @override
  State<_TestApp> createState() => _TestAppState();
}

class _TestAppState extends State<_TestApp> {
  late final Future<_Loaded> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_Loaded> _load() async {
    SharedPreferences.setMockInitialValues({});
    return _Loaded(
      settings: await SettingsService.load(),
      location: await LocationService.load(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_Loaded>(
      future: _future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }
        final loaded = snapshot.data!;
        return MalikiPrayerTimesApp(
          settings: loaded.settings,
          location: loaded.location,
          notifications: null,
        );
      },
    );
  }
}

class _Loaded {
  final SettingsService settings;
  final LocationService location;

  _Loaded({required this.settings, required this.location});
}
