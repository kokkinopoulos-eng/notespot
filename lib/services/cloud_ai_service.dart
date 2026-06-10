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

  static const _timeout = Duration(seconds: 30);

  static const _imagePromptTemplate =
      'You are analyzing a photo for a note-taking app. '
      'First identify the MAIN subject: the object in the foreground, closest to the camera and in focus. '
      'IGNORE background items such as papers, documents, desks, devices, furniture - '
      'unless a document IS the main subject filling most of the frame. '
      'Respond ONLY with valid JSON, no markdown fences, no extra text: '
      '{"title": "short title describing the MAIN subject, max 6 words, in <LANG>", '
      '"category": "one of [receipts, work, personal, shopping, ideas, food, travel, other] matching the MAIN subject", '
      '"tags": ["3-6 keywords about the MAIN subject in <LANG>"], '
      '"extracted_text": "text readable on the MAIN subject verbatim (brand, label, amounts), empty string if none"}';

  static const _textPromptTemplate =
      'Analyze this text for a note-taking app. '
      'Respond ONLY with valid JSON, no markdown fences, no extra text: '
      '{"title": "short title max 6 words in <LANG>", '
      '"category": "one of [receipts, work, personal, shopping, ideas, food, travel, other]", '
      '"tags": ["3-6 keywords in <LANG>"], '
      '"extracted_text": ""}';

  String _imagePrompt(String lang) =>
      _imagePromptTemplate.replaceAll('<LANG>', lang);

  String _textPrompt(String lang, String text) =>
      '${_textPromptTemplate.replaceAll('<LANG>', lang)}\n\nText to analyze:\n$text';

  AiAnalysis? _parse(String raw) {
    debugPrint('[AI] raw response: $raw');
    try {
      final cleaned = raw
          .replaceAll(RegExp(r'```json\s*'), '')
          .replaceAll(RegExp(r'```\s*'), '')
          .trim();
      final json = jsonDecode(cleaned) as Map<String, dynamic>;
      return AiAnalysis.fromJson(json);
    } catch (e) {
      debugPrint('[AI] parse error: $e');
      return null;
    }
  }

  Future<AiAnalysis?> analyzeImage(String imagePath, String languageName) async {
    final svc = AiSettingsService.instance;
    if (!await svc.aiEnabled) return null;
    final provider = await svc.getSelectedProvider();
    final key = await svc.getApiKey(provider);
    if (key == null || key.trim().isEmpty) return null;

    try {
      final bytes = await File(imagePath).readAsBytes();
      final b64 = base64Encode(bytes);
      final prompt = _imagePrompt(languageName);
      return await _callProvider(provider, key.trim(), prompt, b64);
    } catch (e) {
      debugPrint('[AI] analyzeImage error');
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
      return await _callProvider(provider, key.trim(), prompt, null);
    } catch (e) {
      debugPrint('[AI] analyzeText error');
      return null;
    }
  }

  Future<AiAnalysis?> _callProvider(
    AiProvider provider,
    String key,
    String prompt,
    String? imageB64,
  ) async {
    switch (provider) {
      case AiProvider.gemini:
        return _callGemini(key, prompt, imageB64);
      case AiProvider.claude:
        return _callClaude(key, prompt, imageB64);
      case AiProvider.openai:
        return _callOpenAi(key, prompt, imageB64);
    }
  }

  Future<AiAnalysis?> _callGemini(
      String key, String prompt, String? imageB64) async {
    final parts = <Map<String, dynamic>>[
      {'text': prompt},
      if (imageB64 != null)
        {
          'inline_data': {'mime_type': 'image/jpeg', 'data': imageB64}
        },
    ];
    final body = jsonEncode({
      'contents': [
        {'parts': parts}
      ],
      'generationConfig': {
        'response_mime_type': 'application/json',
        'temperature': 0.2,
      },
    });
    final res = await http
        .post(
          Uri.parse(
              'https://generativelanguage.googleapis.com/v1beta/models/$kGeminiModel:generateContent?key=$key'),
          headers: {'content-type': 'application/json'},
          body: body,
        )
        .timeout(_timeout);
    if (res.statusCode != 200) {
      debugPrint('[AI] Gemini HTTP ${res.statusCode}');
      return null;
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final text =
        json['candidates'][0]['content']['parts'][0]['text'] as String;
    return _parse(text);
  }

  Future<AiAnalysis?> _callClaude(
      String key, String prompt, String? imageB64) async {
    final content = <Map<String, dynamic>>[
      if (imageB64 != null)
        {
          'type': 'image',
          'source': {
            'type': 'base64',
            'media_type': 'image/jpeg',
            'data': imageB64,
          }
        },
      {'type': 'text', 'text': prompt},
    ];
    final body = jsonEncode({
      'model': 'claude-haiku-4-5',
      'max_tokens': 1024,
      'temperature': 0.2,
      'messages': [
        {'role': 'user', 'content': content}
      ],
    });
    final res = await http
        .post(
          Uri.parse('https://api.anthropic.com/v1/messages'),
          headers: {
            'content-type': 'application/json',
            'x-api-key': key,
            'anthropic-version': '2023-06-01',
          },
          body: body,
        )
        .timeout(_timeout);
    if (res.statusCode != 200) {
      debugPrint('[AI] Claude HTTP ${res.statusCode}');
      return null;
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final text = json['content'][0]['text'] as String;
    return _parse(text);
  }

  Future<AiAnalysis?> _callOpenAi(
      String key, String prompt, String? imageB64) async {
    final contentParts = <Map<String, dynamic>>[
      {'type': 'text', 'text': prompt},
      if (imageB64 != null)
        {
          'type': 'image_url',
          'image_url': {'url': 'data:image/jpeg;base64,$imageB64'},
        },
    ];
    final body = jsonEncode({
      'model': 'gpt-4o-mini',
      'temperature': 0.2,
      'response_format': {'type': 'json_object'},
      'messages': [
        {'role': 'user', 'content': contentParts}
      ],
    });
    final res = await http
        .post(
          Uri.parse('https://api.openai.com/v1/chat/completions'),
          headers: {
            'content-type': 'application/json',
            'Authorization': 'Bearer $key',
          },
          body: body,
        )
        .timeout(_timeout);
    if (res.statusCode != 200) {
      debugPrint('[AI] OpenAI HTTP ${res.statusCode}');
      return null;
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final text = json['choices'][0]['message']['content'] as String;
    return _parse(text);
  }
}

// ignore: avoid_print
void debugPrint(String msg) => print(msg);