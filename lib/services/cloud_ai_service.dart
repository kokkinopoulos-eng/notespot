import 'package:flutter/material.dart';
import '../main.dart';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/ai_analysis.dart';
import '../models/ai_provider.dart';
import 'ai_settings_service.dart';

const kGeminiModel = 'gemini-2.0-flash';

class CloudAiService {
  CloudAiService._();
  static final instance = CloudAiService._();

  /// Set when the last AI call failed; UI can show it.
  String? lastError;

  void _emitError(String msg) {
    lastError = msg;
    final m = rootMessengerKey.currentState;
    m?.showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 6)),
    );
  }

  String _friendlyError(int status, String body) {
    final b = body.toLowerCase();
    if (b.contains('credit balance') ||
        b.contains('quota') ||
        b.contains('billing') ||
        b.contains('insufficient')) {
      return 'Τελείωσαν τα credits του AI κλειδιού σας. Ελέγξτε χρέωση/υπόλοιπο στον πάροχο.';
    }
    if (status == 401 ||
        status == 403 ||
        b.contains('api key') ||
        b.contains('api_key') ||
        b.contains('invalid x-api-key')) {
      return 'Μη έγκυρο API key. Ελέγξτε το κλειδί στις Ρυθμίσεις → AI.';
    }
    if (status == 429) {
      return 'Υπέρβαση ορίου αιτημάτων. Δοκιμάστε ξανά σε λίγο.';
    }
    return 'Η AI ανάλυση απέτυχε (κωδικός $status).';
  }

  static const _timeout = Duration(seconds: 30);

  static const _imagePromptTemplate =
      'You are analyzing a photo for a note-taking app. '
      'First identify the MAIN subject: the object in the foreground, closest to the camera and in focus. '
      'IGNORE background items such as papers, documents, desks, devices, furniture - '
      'unless a document IS the main subject filling most of the frame. '
      'Respond ONLY with valid JSON, no markdown fences, no extra text: '
      '{"title": "short title describing the MAIN subject, max 6 words, in <LANG>", '
      '"category": "one of [passwords, contacts, shopping, receipts, finance, work, health, travel, ideas, addresses, pets, food, education, tech, vehicle, home, appointments, bills, personal, other] matching the MAIN subject", '
      '"tags": ["3-6 keywords about the MAIN subject in <LANG>"], '
      '"extracted_text": "text readable on the MAIN subject verbatim (brand, label, amounts), empty string if none"}';

  static const _textPromptTemplate =
      'Analyze this text for a note-taking app. '
      'Respond ONLY with valid JSON, no markdown fences, no extra text: '
      '{"title": "short title max 6 words in <LANG>", '
      '"category": "one of [passwords, contacts, shopping, receipts, finance, work, health, travel, ideas, addresses, pets, food, education, tech, vehicle, home, appointments, bills, personal, other]", '
      '"tags": ["3-6 keywords in <LANG>"], '
      '"extracted_text": ""}';

  String _imagePrompt(String lang) =>
      _imagePromptTemplate.replaceAll('<LANG>', lang);

  String _textPrompt(String lang, String text) =>
      '${_textPromptTemplate.replaceAll('<LANG>', lang)}\n\nText to analyze:\n$text';

  String _audioPrompt(String lang) =>
      'Transcribe and analyze this audio recording for a note-taking app. '
      'Respond ONLY with valid JSON, no markdown fences, no extra text: '
      '{"title": "short title max 6 words in $lang", '
      '"category": "one of [passwords, contacts, shopping, receipts, finance, work, health, travel, ideas, addresses, pets, food, education, tech, vehicle, home, appointments, bills, personal, other]", '
      '"tags": ["3-6 keywords in $lang"], '
      '"extracted_text": "verbatim transcription of the audio in $lang"}';

  String _mimeFor(String path) {
    // Detect from magic bytes, not extension - gallery images often have
    // a .jpg name but PNG content (or vice versa).
    try {
      final bytes = File(path).readAsBytesSync();
      if (bytes.length >= 8 &&
          bytes[0] == 0x89 &&
          bytes[1] == 0x50 &&
          bytes[2] == 0x4E &&
          bytes[3] == 0x47) {
        return 'image/png';
      }
      if (bytes.length >= 3 &&
          bytes[0] == 0xFF &&
          bytes[1] == 0xD8 &&
          bytes[2] == 0xFF) {
        return 'image/jpeg';
      }
      if (bytes.length >= 12 &&
          bytes[0] == 0x52 &&
          bytes[1] == 0x49 &&
          bytes[2] == 0x46 &&
          bytes[3] == 0x46 &&
          bytes[8] == 0x57 &&
          bytes[9] == 0x45 &&
          bytes[10] == 0x42 &&
          bytes[11] == 0x50) {
        return 'image/webp';
      }
    } catch (_) {}
    // Fallback to extension
    final ext = path.toLowerCase();
    if (ext.endsWith('.png')) return 'image/png';
    if (ext.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  AiAnalysis? _parse(String raw) {
    try {
      final cleaned = raw
          .replaceAll(RegExp(r'```json\s*'), '')
          .replaceAll(RegExp(r'```\s*'), '')
          .trim();
      final json = jsonDecode(cleaned) as Map<String, dynamic>;
      return AiAnalysis.fromJson(json);
    } catch (e) {
      // ignore: avoid_print
      print('[AI] parse error: $e');
      return null;
    }
  }

  Future<AiAnalysis?> analyzeImage(
      String imagePath, String languageName, {String? userText}) async {
    lastError = null;
    final svc = AiSettingsService.instance;
    if (!await svc.aiEnabled) return null;
    final provider = await svc.getSelectedProvider();
    final key = await svc.getApiKey(provider);
    if (key == null || key.trim().isEmpty) return null;
    try {
      final bytes = await File(imagePath).readAsBytes();
      final b64 = base64Encode(bytes);
      final mime = _mimeFor(imagePath);
      final extra = userText != null && userText.isNotEmpty
          ? '\n\nThe user also typed this text in the same note - use BOTH the image and this text for title/category/tags:\n$userText'
          : '';
      final prompt = _imagePrompt(languageName) + extra;
      return await _callProvider(provider, key.trim(), prompt, b64, mime);
    } catch (e) {
      // ignore: avoid_print
      print('[AI] analyzeImage error');
      return null;
    }
  }

  Future<AiAnalysis?> analyzeText(String text, String languageName) async {
    final svc = AiSettingsService.instance;
    if (!await svc.aiEnabled) return null;
    final provider = await svc.getSelectedProvider();
    final key = await svc.getApiKey(provider);
    if (key == null || key.trim().isEmpty) return null;
    try {
      final prompt = _textPrompt(languageName, text);
      return await _callProvider(provider, key.trim(), prompt, null, null);
    } catch (e) {
      // ignore: avoid_print
      print('[AI] analyzeText error');
      return null;
    }
  }

  Future<AiAnalysis?> analyzeAudio(
      String path, String languageName) async {
    final svc = AiSettingsService.instance;
    if (!await svc.aiEnabled) return null;
    final provider = await svc.getSelectedProvider();
    if (provider != AiProvider.gemini) return null;
    final key = await svc.getApiKey(provider);
    if (key == null || key.trim().isEmpty) return null;
    try {
      final bytes = await File(path).readAsBytes();
      final b64 = base64Encode(bytes);
      final prompt = _audioPrompt(languageName);
      final parts = <Map<String, dynamic>>[
        {'text': prompt},
        {'inline_data': {'mime_type': 'audio/mp4', 'data': b64}},
      ];
      final body = jsonEncode({
        'contents': [{'parts': parts}],
        'generationConfig': {
          'response_mime_type': 'application/json',
          'temperature': 0.2,
        },
      });
      final res = await http.post(
        Uri.parse(
            'https://generativelanguage.googleapis.com/v1beta/models/$kGeminiModel:generateContent?key=$key'),
        headers: {'content-type': 'application/json'},
        body: body,
      ).timeout(_timeout);
      if (res.statusCode != 200) {
        // ignore: avoid_print
        print('[AI] Gemini audio HTTP ${res.statusCode}: ${res.body.substring(0, res.body.length.clamp(0, 300))}');
        return null;
      }
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final text = json['candidates'][0]['content']['parts'][0]['text'] as String;
      return _parse(text);
    } catch (e) {
      // ignore: avoid_print
      print('[AI] analyzeAudio error');
      return null;
    }
  }

  Future<AiAnalysis?> _callProvider(
    AiProvider provider,
    String key,
    String prompt,
    String? imageB64,
    String? mime,
  ) async {
    switch (provider) {
      case AiProvider.gemini:
        return _callGemini(key, prompt, imageB64, mime);
      case AiProvider.claude:
        return _callClaude(key, prompt, imageB64, mime);
      case AiProvider.openai:
        return _callOpenAi(key, prompt, imageB64, mime);
    }
  }

  Future<AiAnalysis?> _callGemini(
      String key, String prompt, String? imageB64, String? mime) async {
    final parts = <Map<String, dynamic>>[
      {'text': prompt},
      if (imageB64 != null)
        {'inline_data': {'mime_type': mime ?? 'image/jpeg', 'data': imageB64}},
    ];
    final body = jsonEncode({
      'contents': [{'parts': parts}],
      'generationConfig': {
        'response_mime_type': 'application/json',
        'temperature': 0.2,
      },
    });
    final res = await http.post(
      Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/$kGeminiModel:generateContent?key=$key'),
      headers: {'content-type': 'application/json'},
      body: body,
    ).timeout(_timeout);
    if (res.statusCode != 200) {
      // ignore: avoid_print
      print('[AI] Gemini error');
      _emitError(_friendlyError(res.statusCode, res.body));
      return null;
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final text = json['candidates'][0]['content']['parts'][0]['text'] as String;
    return _parse(text);
  }

  Future<AiAnalysis?> _callClaude(
      String key, String prompt, String? imageB64, String? mime) async {
    final content = <Map<String, dynamic>>[
      if (imageB64 != null)
        {
          'type': 'image',
          'source': {
            'type': 'base64',
            'media_type': mime ?? 'image/jpeg',
            'data': imageB64,
          }
        },
      {'type': 'text', 'text': prompt},
    ];
    final body = jsonEncode({
      'model': 'claude-haiku-4-5',
      'max_tokens': 1024,
      'temperature': 0.2,
      'messages': [{'role': 'user', 'content': content}],
    });
    final res = await http.post(
      Uri.parse('https://api.anthropic.com/v1/messages'),
      headers: {
        'content-type': 'application/json',
        'x-api-key': key,
        'anthropic-version': '2023-06-01',
      },
      body: body,
    ).timeout(_timeout);
    if (res.statusCode != 200) {
      // ignore: avoid_print
      print('[AI] Claude HTTP ${res.statusCode}: ${res.body.substring(0, res.body.length.clamp(0, 300))}');
      _emitError(_friendlyError(res.statusCode, res.body));
      return null;
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final text = json['content'][0]['text'] as String;
    return _parse(text);
  }

  Future<AiAnalysis?> _callOpenAi(
      String key, String prompt, String? imageB64, String? mime) async {
    final contentParts = <Map<String, dynamic>>[
      {'type': 'text', 'text': prompt},
      if (imageB64 != null)
        {
          'type': 'image_url',
          'image_url': {'url': 'data:${mime ?? 'image/jpeg'};base64,$imageB64'},
        },
    ];
    final body = jsonEncode({
      'model': 'gpt-4o-mini',
      'temperature': 0.2,
      'response_format': {'type': 'json_object'},
      'messages': [{'role': 'user', 'content': contentParts}],
    });
    final res = await http.post(
      Uri.parse('https://api.openai.com/v1/chat/completions'),
      headers: {
        'content-type': 'application/json',
        'Authorization': 'Bearer $key',
      },
      body: body,
    ).timeout(_timeout);
    if (res.statusCode != 200) {
      // ignore: avoid_print
      print('[AI] OpenAI HTTP ${res.statusCode}: ${res.body.substring(0, res.body.length.clamp(0, 300))}');
      return null;
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final text = json['choices'][0]['message']['content'] as String;
    return _parse(text);
  }

  // ─────────────────────────────────────────────────────────────
  // AI Assistant — generic text completion (Pro v1.1)
  // Χρησιμοποιείται από το AiAssistantService για editing operations
  // (grammar fix, summarize, expand, tone change) και voice structuring.
  // Επιστρέφει raw text αντί για AiAnalysis. Default model: Haiku 4.5.
  // ─────────────────────────────────────────────────────────────

  /// Generic text completion. Επιστρέφει raw text ή null σε αποτυχία.
  /// Routes στον επιλεγμένο provider μέσω AiSettingsService.
  Future<String?> complete(String prompt, {int maxTokens = 1500}) async {
    lastError = null;
    final svc = AiSettingsService.instance;
    final provider = await svc.getSelectedProvider();
    final key = await svc.getApiKey(provider);
    if (key == null || key.trim().isEmpty) {
      _emitError('Δεν έχει οριστεί API key για ${provider.name}.');
      return null;
    }
    try {
      switch (provider) {
        case AiProvider.gemini:
          return await _completeGemini(key.trim(), prompt, maxTokens);
        case AiProvider.claude:
          return await _completeClaude(key.trim(), prompt, maxTokens);
        case AiProvider.openai:
          return await _completeOpenAi(key.trim(), prompt, maxTokens);
      }
    } catch (e) {
      _emitError('Αποτυχία AI: $e');
      return null;
    }
  }

  Future<String?> _completeClaude(
      String key, String prompt, int maxTokens) async {
    final res = await http.post(
      Uri.parse('https://api.anthropic.com/v1/messages'),
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': key,
        'anthropic-version': '2023-06-01',
      },
      body: jsonEncode({
        'model': 'claude-haiku-4-5',
        'max_tokens': maxTokens,
        'messages': [
          {'role': 'user', 'content': prompt}
        ],
      }),
    );
    if (res.statusCode != 200) {
      _emitError(_friendlyError(res.statusCode, res.body));
      return null;
    }
    final json = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final content = json['content'] as List?;
    if (content == null || content.isEmpty) return null;
    final first = content.first as Map<String, dynamic>;
    return (first['text'] as String?)?.trim();
  }

  Future<String?> _completeOpenAi(
      String key, String prompt, int maxTokens) async {
    final res = await http.post(
      Uri.parse('https://api.openai.com/v1/chat/completions'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $key',
      },
      body: jsonEncode({
        'model': 'gpt-4o-mini',
        'max_tokens': maxTokens,
        'messages': [
          {'role': 'user', 'content': prompt}
        ],
      }),
    );
    if (res.statusCode != 200) {
      _emitError(_friendlyError(res.statusCode, res.body));
      return null;
    }
    final json = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final choices = json['choices'] as List?;
    if (choices == null || choices.isEmpty) return null;
    final msg = (choices.first as Map<String, dynamic>)['message']
        as Map<String, dynamic>?;
    return (msg?['content'] as String?)?.trim();
  }

  Future<String?> _completeGemini(
      String key, String prompt, int maxTokens) async {
    final res = await http.post(
      Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$kGeminiModel:generateContent?key=$key',
      ),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': prompt}
            ]
          }
        ],
        'generationConfig': {'maxOutputTokens': maxTokens},
      }),
    );
    if (res.statusCode != 200) {
      _emitError(_friendlyError(res.statusCode, res.body));
      return null;
    }
    final json = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final candidates = json['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) return null;
    final first = candidates.first as Map<String, dynamic>;
    final cont = first['content'] as Map<String, dynamic>?;
    final parts = cont?['parts'] as List?;
    if (parts == null || parts.isEmpty) return null;
    return ((parts.first as Map<String, dynamic>)['text'] as String?)?.trim();
  }
}