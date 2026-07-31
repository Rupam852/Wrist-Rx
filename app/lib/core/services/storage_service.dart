import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static final _secure = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  // Secure storage (API keys)
  static Future<void> saveApiKey(String key) async {
    await _secure.write(key: 'gemini_api_key', value: key);
  }

  static Future<String?> getApiKey() async {
    return await _secure.read(key: 'gemini_api_key');
  }

  static Future<void> deleteApiKey() async {
    await _secure.delete(key: 'gemini_api_key');
  }

  // Local Health Readings (Stored only on device, deleted on app uninstall)
  static Future<void> saveLocalHealthReading(Map<String, dynamic> jsonMap) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('local_health_reading', jsonEncode(jsonMap));
  }

  static Future<Map<String, dynamic>?> getLocalHealthReading() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString('local_health_reading');
    if (str != null) {
      try {
        return jsonDecode(str) as Map<String, dynamic>;
      } catch (_) {}
    }
    return null;
  }

  static Future<void> clearLocalHealthReading() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('local_health_reading');
  }

  // SharedPreferences (general settings)
  static Future<void> saveSetting(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool) await prefs.setBool(key, value);
    if (value is String) await prefs.setString(key, value);
    if (value is int) await prefs.setInt(key, value);
  }

  static Future<T?> getSetting<T>(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.get(key) as T?;
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await _secure.deleteAll();
  }
}

