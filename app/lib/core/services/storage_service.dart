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
