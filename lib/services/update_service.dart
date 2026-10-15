import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:package_info_plus/package_info_plus.dart';

/// Outcome of an update check against the GitHub releases feed.
enum UpdateCheckOutcome {
  /// A newer build is published.
  available,

  /// The installed build is current.
  upToDate,

  /// The check could not complete (offline, malformed response, timeout).
  unknown,
}

/// Result of [AppUpdateService.check].
class UpdateCheckResult {
  final UpdateCheckOutcome outcome;

  /// The remote tag (e.g. "v1.1.0+2"), when one was parsed.
  final String? latestTag;

  /// Where to fetch the update: the release APK asset when present,
  /// otherwise the release page.
  final String? downloadUrl;

  const UpdateCheckResult(this.outcome, {this.latestTag, this.downloadUrl});
}

/// Fetches the latest release metadata. Injectable so tests never touch
/// the network.
abstract class ReleaseFetcher {
  Future<Map<String, dynamic>> fetchLatestRelease();
}

/// Production [ReleaseFetcher]: the GitHub releases API with an ~8s
/// timeout. Never throws: HTTP and parse failures surface as exceptions
/// for [AppUpdateService] to convert into [UpdateCheckOutcome.unknown].
class GithubReleaseFetcher implements ReleaseFetcher {
  static const Duration timeout = Duration(seconds: 8);
  static final Uri latestReleaseUrl = Uri.parse(
    'https://api.github.com/repos/TalhaGoharWeb/maliki-prayer-times-app/releases/latest',
  );

  const GithubReleaseFetcher();

  @override
  Future<Map<String, dynamic>> fetchLatestRelease() async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(latestReleaseUrl).timeout(timeout);
      request.headers.set('Accept', 'application/vnd.github+json');
      final response = await request.close().timeout(timeout);
      final body =
          await response.transform(utf8.decoder).join().timeout(timeout);
      if (response.statusCode != 200) {
        throw HttpException('GitHub API returned ${response.statusCode}');
      }
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('release JSON is not an object');
      }
      return decoded;
    } finally {
      client.close();
    }
  }
}

/// Checks whether a newer published build exists. Never throws and never
/// blocks the UI: any failure yields [UpdateCheckOutcome.unknown].
class AppUpdateService {
  final ReleaseFetcher _fetcher;
  final Future<String> Function() _installedBuildNumber;

  AppUpdateService({
    ReleaseFetcher? fetcher,
    Future<String> Function()? installedBuildNumber,
  })  : _fetcher = fetcher ?? const GithubReleaseFetcher(),
        _installedBuildNumber =
            installedBuildNumber ?? _platformBuildNumber;

  static Future<String> _platformBuildNumber() async =>
      (await PackageInfo.fromPlatform()).buildNumber;

  /// Parses the build number from a tag like "v1.1.0+2".
  static int? buildNumberFromTag(String? tag) {
    if (tag == null) return null;
    final plus = tag.lastIndexOf('+');
    if (plus < 0 || plus == tag.length - 1) return null;
    return int.tryParse(tag.substring(plus + 1));
  }

  Future<UpdateCheckResult> check() async {
    try {
      final release = await _fetcher.fetchLatestRelease().timeout(
            GithubReleaseFetcher.timeout + const Duration(seconds: 2),
          );
      final tag = release['tag_name'] as String?;
      final remoteBuild = buildNumberFromTag(tag);
      if (tag == null || remoteBuild == null) {
        return const UpdateCheckResult(UpdateCheckOutcome.unknown);
      }
      final installed = int.tryParse(await _installedBuildNumber()) ?? 0;
      if (remoteBuild > installed) {
        return UpdateCheckResult(
          UpdateCheckOutcome.available,
          latestTag: tag,
          downloadUrl: _downloadUrl(release),
        );
      }
      return const UpdateCheckResult(UpdateCheckOutcome.upToDate);
    } catch (_) {
      return const UpdateCheckResult(UpdateCheckOutcome.unknown);
    }
  }

  /// Prefers the attached APK asset; falls back to the release page.
  static String? _downloadUrl(Map<String, dynamic> release) {
    final assets = release['assets'];
    if (assets is List) {
      for (final a in assets) {
        if (a is Map<String, dynamic>) {
          final url = a['browser_download_url'] as String?;
          final name = (a['name'] as String? ?? '').toLowerCase();
          if (url != null && name.endsWith('.apk')) return url;
        }
      }
      for (final a in assets) {
        if (a is Map<String, dynamic>) {
          final url = a['browser_download_url'] as String?;
          if (url != null) return url;
        }
      }
    }
    return release['html_url'] as String?;
  }
}
