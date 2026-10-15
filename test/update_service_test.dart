import 'package:flutter_test/flutter_test.dart';
import 'package:malikiprayertimes/services/update_service.dart';

/// Test double for [ReleaseFetcher]: scripts the release JSON (or throws).
class FakeReleaseFetcher implements ReleaseFetcher {
  Map<String, dynamic>? release;
  bool throws = false;

  FakeReleaseFetcher({this.release, this.throws = false});

  @override
  Future<Map<String, dynamic>> fetchLatestRelease() async {
    if (throws) throw Exception('offline');
    return release ?? {};
  }
}

AppUpdateService _service({
  Map<String, dynamic>? release,
  bool throws = false,
  String installedBuild = '2',
}) {
  return AppUpdateService(
    fetcher: FakeReleaseFetcher(release: release, throws: throws),
    installedBuildNumber: () async => installedBuild,
  );
}

Map<String, dynamic> _release(String tag) => {
      'tag_name': tag,
      'html_url': 'https://github.com/TalhaGoharWeb/maliki-prayer-times-app/releases/tag/$tag',
      'assets': [
        {
          'name': 'app-release.apk',
          'browser_download_url':
              'https://github.com/TalhaGoharWeb/maliki-prayer-times-app/releases/download/$tag/app-release.apk',
        },
      ],
    };

void main() {
  group('AppUpdateService.buildNumberFromTag', () {
    test('parses v1.1.0+2', () {
      expect(AppUpdateService.buildNumberFromTag('v1.1.0+2'), 2);
    });
    test('returns null without a build suffix', () {
      expect(AppUpdateService.buildNumberFromTag('v1.1.0'), isNull);
      expect(AppUpdateService.buildNumberFromTag(null), isNull);
      expect(AppUpdateService.buildNumberFromTag('v1.1.0+'), isNull);
      expect(AppUpdateService.buildNumberFromTag('v1.1.0+abc'), isNull);
    });
  });

  group('AppUpdateService.check', () {
    test('newer build available with the APK download URL', () async {
      final service = _service(release: _release('v1.1.0+5'));
      final result = await service.check();

      expect(result.outcome, UpdateCheckOutcome.available);
      expect(result.latestTag, 'v1.1.0+5');
      expect(result.downloadUrl, contains('app-release.apk'));
    });

    test('same build is up to date', () async {
      final service = _service(release: _release('v1.1.0+2'));
      final result = await service.check();

      expect(result.outcome, UpdateCheckOutcome.upToDate);
    });

    test('older remote build is up to date', () async {
      final service = _service(
        release: _release('v1.0.0+1'),
        installedBuild: '2',
      );
      final result = await service.check();

      expect(result.outcome, UpdateCheckOutcome.upToDate);
    });

    test('malformed tag yields unknown', () async {
      final service = _service(release: _release('v1.1.0'));
      expect((await service.check()).outcome, UpdateCheckOutcome.unknown);

      final missing = _service(release: {'html_url': 'x'});
      expect((await missing.check()).outcome, UpdateCheckOutcome.unknown);
    });

    test('network failure yields unknown and never throws', () async {
      final service = _service(throws: true);
      final result = await service.check(); // must not throw

      expect(result.outcome, UpdateCheckOutcome.unknown);
    });

    test('release page is the fallback when no APK asset exists', () async {
      final service = _service(release: {
        'tag_name': 'v9.9.9+9',
        'html_url': 'https://example.com/release',
        'assets': [],
      });
      final result = await service.check();

      expect(result.outcome, UpdateCheckOutcome.available);
      expect(result.downloadUrl, 'https://example.com/release');
    });
  });
}
