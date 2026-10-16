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
    testWidgets('renders the rose brand, title, loader and credit lines',
        (tester) async {
      // Real-size phone frame (1080x2400 @3x).
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(home: SplashScreen()),
      );
      await tester.pump();
      expect(tester.takeException(), isNull,
          reason: 'no overflow on a real-size frame');

      final image = tester.widget<Image>(find.byType(Image));
      expect((image.image as AssetImage).assetName, SplashScreen.logoAsset,
          reason: 'splash shows the compass-rose brand art');
      expect(find.text('Maliki Prayer Times'), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets,
          reason: 'hand-drawn star loader is present');
      expect(find.byType(CircularProgressIndicator), findsNothing,
          reason: 'no generic spinner');
      expect(
          find.text('Developed by Muhammad Talha Bin Farid Al Maliki'),
          findsOneWidget);
      expect(find.text('Maliki Fiqh Subcontinent'), findsOneWidget);

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, const Color(0xFF003527),
          reason: 'splash is deep green');

      final title = tester.widget<Text>(find.text('Maliki Prayer Times'));
      final titleStyle = title.style!;
      expect(titleStyle.fontFamily, 'Source Serif 4');
      expect(titleStyle.letterSpacing, 2.0);
    });

    testWidgets('precaches the logo so it paints on the first frame',
        (tester) async {
      PaintingBinding.instance.imageCache.clear();
      await tester.pumpWidget(
        const MaterialApp(home: SplashScreen()),
      );
      await tester.pump(); // didChangeDependencies -> precacheImage
      await tester.pump(const Duration(milliseconds: 100)); // decode
      final key = await const AssetImage(SplashScreen.logoAsset)
          .obtainKey(const ImageConfiguration());
      final status = PaintingBinding.instance.imageCache.statusForKey(key);
      expect(status.live || status.keepAlive, isTrue,
          reason: 'logo is in the image cache right after the splash builds');
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
