import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/ai_provider.dart';

class AiSettingsService {
  AiSettingsService._();
  static final instance = AiSettingsService._();

  static const _providerKey = 'ai_provider';
  static const _enabledKey = 'ai_enabled';
  final _storage = const FlutterSecureStorage();

  Future<void> setApiKey(AiProvider p, String key) =>
      _storage.write(key: p.storageKey, value: key);

  Future<String?> getApiKey(AiProvider p) =>
      _storage.read(key: p.storageKey);

  Future<void> deleteApiKey(AiProvider p) =>
      _storage.delete(key: p.storageKey);

  Future<AiProvider> getSelectedProvider() async {
    final prefs = await SharedPreferences.getInstance();
    final val = prefs.getString(_providerKey);
    return AiProvider.values.firstWhere(
      (e) => e.name == val,
      orElse: () => AiProvider.gemini,
    );
  }

  Future<void> setSelectedProvider(AiProvider p) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_providerKey, p.name);
  }

  Future<bool> get aiEnabled async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enabledKey) ?? false;
  }

  Future<void> setAiEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, value);
  }

  Future<bool> testApiKey(AiProvider provider, String key) async {
    try {
      switch (provider) {
        case AiProvider.claude:
          final res = await http.post(
            Uri.parse('https://api.anthropic.com/v1/messages'),
            headers: {
              'x-api-key': key,
              'anthropic-version': '2023-06-01',
              'content-type': 'application/json',
            },
            body: jsonEncode({
              'model': 'claude-haiku-4-5',
              'max_tokens': 1,
              'messages': [
                {'role': 'user', 'content': 'hi'},
              ],
            }),
          );
          return res.statusCode == 200;
        case AiProvider.gemini:
          final res = await http.get(
            Uri.parse(
              'https://generativelanguage.googleapis.com/v1beta/models?key=$key',
            ),
          );
          return res.statusCode == 200;
        case AiProvider.openai:
          final res = await http.get(
            Uri.parse('https://api.openai.com/v1/models'),
            headers: {'Authorization': 'Bearer $key'},
          );
          return res.statusCode == 200;
      }
    } catch (_) {
      return false;
    }
  }
}
