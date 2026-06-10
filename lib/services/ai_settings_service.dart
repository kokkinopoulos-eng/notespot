import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/ai_provider.dart';

class AiSettingsService {
  AiSettingsService._();
  static final instance = AiSettingsService._();

  static const _providerKey = 'ai_provider';
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
    final p = await getSelectedProvider();
    final key = await getApiKey(p);
    return key != null && key.trim().isNotEmpty;
  }
}