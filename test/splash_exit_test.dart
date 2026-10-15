import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:malikiprayertimes/l10n/app_localizations.dart';
import 'package:malikiprayertimes/main.dart';
import 'package:malikiprayertimes/screens/splash_screen.dart';
import 'package:malikiprayertimes/services/location_service.dart';
import 'package:malikiprayertimes/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

void main() {
  group('SplashScreen', () {
    testWidgets('renders the logo and both credit lines', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: SplashScreen()),
      );
      await tester.pump();

      expect(find.byType(Image), findsOneWidget);
      expect(
          find.text('Developed by Muhammad Talha Bin Farid Al Maliki'),
          findsOneWidget);
      expect(find.text('Maliki Fiqh Subcontinent'), findsOneWidget);

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, const Color(0xFF003527),
          reason: 'splash is deep green');
    });
  });

  group('exit confirmation', () {
    testWidgets('system back on the home tab shows the exit dialog',
        (tester) async {
      await tester.pumpWidget(const _TestApp());
      // Home runs a 1-second countdown timer: pump manually instead of
      // pumpAndSettle (which would time out on the periodic timer).
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);

      final l10n =
          await AppLocalizations.delegate.load(const Locale('en'));

      // Simulate the Android system back button on the home tab.
      await tester.binding.handlePopRoute();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text(l10n.exitAppTitle), findsOneWidget,
          reason: 'exit dialog appears on home-tab back press');
      expect(find.text(l10n.exitAppExit), findsOneWidget);
      expect(find.text(l10n.exitAppCancel), findsOneWidget);

      // Cancel keeps the app open.
      await tester.tap(find.text(l10n.exitAppCancel));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text(l10n.exitAppTitle), findsNothing,
          reason: 'dialog dismisses on cancel');
      expect(find.byType(Scaffold), findsWidgets,
          reason: 'app is still open after cancel');
    });
  });
}
