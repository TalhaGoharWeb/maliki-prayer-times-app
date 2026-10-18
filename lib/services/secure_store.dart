import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Injectable seam around platform secure storage, so the data layer can
/// be tested without platform channels.
///
/// Bleeding records are health data: their JSON lives behind this seam
/// only, never in shared_preferences.
abstract class SecureBackend {
  Future<void> write({required String key, required String value});
  Future<String?> read({required String key});
  Future<void> delete({required String key});
  Future<void> deleteAll();
}

/// Production backend backed by flutter_secure_storage.
class FlutterSecureStorageBackend implements SecureBackend {
  final FlutterSecureStorage _storage;

  FlutterSecureStorageBackend([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  @override
  Future<void> write({required String key, required String value}) =>
      _storage.write(key: key, value: value);

  @override
  Future<String?> read({required String key}) => _storage.read(key: key);

  @override
  Future<void> delete({required String key}) => _storage.delete(key: key);

  @override
  Future<void> deleteAll() => _storage.deleteAll();
}

/// In-memory fake for tests.
class InMemorySecureBackend implements SecureBackend {
  final Map<String, String> _values = {};

  @override
  Future<void> write({required String key, required String value}) async {
    _values[key] = value;
  }

  @override
  Future<String?> read({required String key}) async => _values[key];

  @override
  Future<void> delete({required String key}) async {
    _values.remove(key);
  }

  @override
  Future<void> deleteAll() async {
    _values.clear();
  }
}

/// Thin JSON wrapper over a [SecureBackend].
class SecureStore {
  final SecureBackend _backend;

  SecureStore({SecureBackend? backend})
    : _backend = backend ?? FlutterSecureStorageBackend();

  /// Writes [json] encoded as a single string value.
  Future<void> writeJson(String key, Map<String, dynamic> json) =>
      _backend.write(key: key, value: jsonEncode(json));

  /// Reads and decodes the JSON object at [key], or null when absent.
  /// Throws a typed [FormatException] when the stored value is not a
  /// JSON object.
  Future<Map<String, dynamic>?> readJson(String key) async {
    final raw = await _backend.read(key: key);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
      throw FormatException(
        'SecureStore: value for "$key" is not a JSON object.',
      );
    } catch (e) {
      if (e is FormatException) rethrow;
      throw FormatException('SecureStore: corrupt JSON for "$key": $e');
    }
  }

  Future<void> delete(String key) => _backend.delete(key: key);

  Future<void> deleteAll() => _backend.deleteAll();
}
