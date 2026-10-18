// Qada v2 / Hayd & Nifas localization parity tests.
//
// Reads the raw .arb files (not the generated localizations) so every key —
// including ones not yet referenced from Dart — is covered. Run after
// `flutter gen-l10n` so the generated files are in sync too.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Directory containing the .arb files. `flutter test` runs with the package
/// root as the working directory (and Platform.script points at a synthetic
/// main.dart there); fall back to resolving from the test file's directory.
Directory get _l10nDir {
  final candidates = [
    Directory('${Directory.current.path}/lib/l10n'),
    Directory(
        '${File(Platform.script.toFilePath()).parent.path}/lib/l10n'),
  ];
  for (final dir in candidates) {
    if (File('${dir.path}/app_en.arb').existsSync()) return dir;
  }
  return candidates.first;
}

/// Raw key -> value map for one locale, `@`-metadata entries excluded.
Map<String, String> _loadArb(String code) {
  final file = File('${_l10nDir.path}/app_$code.arb');
  expect(file.existsSync(), isTrue, reason: 'app_$code.arb exists');
  final raw = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  return {
    for (final e in raw.entries)
      if (!e.key.startsWith('@')) e.key: e.value as String,
  };
}

/// Keys added for the Qada v2 / Hayd & Nifas tracker.
bool _isQada2OrHn(String key) =>
    key.startsWith('qada2') || key.startsWith('hn');

final _placeholderPattern = RegExp(r'\{([a-zA-Z_][a-zA-Z0-9_]*)\b');

Set<String> _placeholders(String text) =>
    _placeholderPattern.allMatches(text).map((m) => m.group(1)!).toSet();

/// English single prayer names and their Urdu single-name convention.
const _prayerNamesEnToUr = {
  'Fajr': 'فجر',
  'Dhuhr': 'ظہر',
  'Asr': 'عصر',
  'Maghrib': 'مغرب',
  'Isha': 'عشاء',
};

/// Arabic companion names that must never sit next to the Urdu single name.
const _arabicCompanions = {
  'الفجر',
  'الظهر',
  'العصر',
  'المغرب',
  'العشاء',
};

// Banned "pending scholarly review" phrases (mirrors locale_test.dart).
// User directive: this text must appear nowhere in the UI, in any language.
const _bannedReviewPhrases = [
  'propos', // proposed / PROPOSED / proposé
  'pending scholarly review',
  'no scholar has reviewed',
  'examen par des savants',
  'révision savante',
  'مجوزہ',
  'مقترح',
  'بانتظار المراجعة',
  'المراجعة العلمية',
  'علمی جائزے',
  'علمی جائزہ',
  'شرعی توثیق',
];

final _arabicIndicDigits = RegExp(r'[٠-٩]');

void main() {
  late Map<String, String> en;
  late Map<String, String> ar;
  late Map<String, String> fr;
  late Map<String, String> ur;

  setUpAll(() {
    en = _loadArb('en');
    ar = _loadArb('ar');
    fr = _loadArb('fr');
    ur = _loadArb('ur');
  });

  group('qada2/hn arb parity', () {
    test('qada2/hn keys exist in the English source', () {
      final found = en.keys.where(_isQada2OrHn).toList();
      expect(found, isNotEmpty,
          reason: 'Worker C should have added qada2/hn keys to app_en.arb');
    });

    test('every English key exists in ar, fr, ur with a non-empty value',
        () {
      for (final entry in en.entries) {
        for (final locale in [('ar', ar), ('fr', fr), ('ur', ur)]) {
          final code = locale.$1;
          final map = locale.$2;
          expect(map.containsKey(entry.key), isTrue,
              reason: 'key "${entry.key}" missing from app_$code.arb');
          expect(map[entry.key]!.trim(), isNotEmpty,
              reason: 'key "${entry.key}" is empty in app_$code.arb');
        }
      }
    });

    test('every {placeholder} in English appears in each translation', () {
      for (final entry in en.entries) {
        final enPlaceholders = _placeholders(entry.value);
        for (final locale in [('ar', ar), ('fr', fr), ('ur', ur)]) {
          final code = locale.$1;
          final translated = locale.$2[entry.key] ?? '';
          final translatedPlaceholders = _placeholders(translated);
          expect(translatedPlaceholders, enPlaceholders,
              reason:
                  'key "${entry.key}": placeholders differ in app_$code.arb '
                  '(en: $enPlaceholders, $code: $translatedPlaceholders)');
        }
      }
    });

    test('Urdu single-prayer-name convention', () {
      // Any key whose English value is exactly one prayer name must use the
      // Urdu single name (فجر، ظہر، عصر، مغرب، عشاء) — never the Arabic
      // companion alongside it.
      for (final entry in en.entries) {
        final urName = _prayerNamesEnToUr[entry.value.trim()];
        if (urName == null) continue;
        final translated = ur[entry.key] ?? '';
        expect(translated.trim(), urName,
            reason:
                'key "${entry.key}": Urdu prayer name should be exactly '
                '"$urName", got "$translated"');
        for (final companion in _arabicCompanions) {
          expect(translated, isNot(contains(companion)),
              reason:
                  'key "${entry.key}": Arabic companion "$companion" must '
                  'not appear next to the Urdu name');
        }
      }
    });

    test('Urdu strings use standard 0-9 digits, not Arabic-Indic', () {
      for (final key in en.keys.where(_isQada2OrHn)) {
        final translated = ur[key] ?? '';
        expect(_arabicIndicDigits.hasMatch(translated), isFalse,
            reason: 'key "$key": Urdu must not use Arabic-Indic digits');
      }
    });

    test('no pending-scholarly-review text in qada2/hn strings', () {
      for (final key in en.keys.where(_isQada2OrHn)) {
        for (final locale in [
          ('en', en),
          ('ar', ar),
          ('fr', fr),
          ('ur', ur)
        ]) {
          final code = locale.$1;
          final text = locale.$2[key] ?? '';
          for (final phrase in _bannedReviewPhrases) {
            expect(text.toLowerCase(), isNot(contains(phrase.toLowerCase())),
                reason: 'key "$key" in app_$code.arb contains "$phrase"');
          }
        }
      }
    });
  });
}
