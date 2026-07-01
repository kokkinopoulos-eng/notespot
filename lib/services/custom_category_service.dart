import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class CustomCategoryService {
  CustomCategoryService._();
  static final instance = CustomCategoryService._();

  static const _key = 'custom_categories';

  Future<List<String>> getCategories() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    return List<String>.from(jsonDecode(raw) as List);
  }

  Future<void> addCategory(String name) async {
    final cats = await getCategories();
    if (cats.contains(name)) return;
    cats.add(name);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(cats));
  }

  Future<void> removeCategory(String name) async {
    final cats = await getCategories();
    cats.remove(name);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(cats));
  }
}
