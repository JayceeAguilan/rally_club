import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class OfflineCacheStore {
  OfflineCacheStore._();

  static final OfflineCacheStore instance = OfflineCacheStore._();

  Future<void> writeMap(String key, Map<String, dynamic> value) {
    return _writeJson(key, value);
  }

  Future<Map<String, dynamic>?> readMap(String key) async {
    final decoded = await _readJson(key);
    if (decoded is! Map) {
      return null;
    }

    return Map<String, dynamic>.from(decoded);
  }

  Future<void> writeList(String key, List<Map<String, dynamic>> value) {
    return _writeJson(key, value);
  }

  Future<List<Map<String, dynamic>>?> readList(String key) async {
    final decoded = await _readJson(key);
    if (decoded is! List) {
      return null;
    }

    return decoded
        .whereType<Object?>()
        .map((entry) => Map<String, dynamic>.from(entry as Map))
        .toList();
  }

  Future<void> remove(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }

  Future<void> _writeJson(String key, Object value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(value));
  }

  Future<Object?> _readJson(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }

    try {
      return jsonDecode(raw);
    } catch (_) {
      await prefs.remove(key);
      return null;
    }
  }
}
