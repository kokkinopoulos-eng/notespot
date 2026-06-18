// lib/services/ai_assistant_service.dart
//
// High-level API για AI Assistant operations.
// Συνδυάζει AiPrompts + CloudAiService.complete() σε χρηστικές methods.
//
// Pro v1.1 — used by AI button menu (note detail screen) και voice note
// structuring flow. Default model: Haiku 4.5 (μέσω cloud_ai_service).

import 'dart:convert';
import 'ai_assistant_prompts.dart';
import 'cloud_ai_service.dart';

class AiAssistantService {
  AiAssistantService._();
  static final instance = AiAssistantService._();

  final CloudAiService _ai = CloudAiService.instance;

  /// Last error message από την τελευταία κλήση. Null αν επιτυχία.
  String? get lastError => _ai.lastError;

  // ───────────────────────────────────────────────────────────────
  // Text editing operations (AI button)
  // ───────────────────────────────────────────────────────────────

  /// Διόρθωση ορθογραφίας/γραμματικής. Επιστρέφει το διορθωμένο
  /// κείμενο ή null σε αποτυχία (δες lastError).
  Future<String?> grammarFix(String text) =>
      _ai.complete(AiPrompts.grammarFix(text));

  /// Σύνοψη σε 1-2 προτάσεις.
  Future<String?> summarize(String text) =>
      _ai.complete(AiPrompts.summarize(text), maxTokens: 300);

  /// Επέκταση σύντομου κειμένου με σχετικές λεπτομέρειες.
  Future<String?> expand(String text) =>
      _ai.complete(AiPrompts.expand(text), maxTokens: 2000);

  /// Σύντμηση στο μισό περίπου μήκος.
  Future<String?> shorten(String text) =>
      _ai.complete(AiPrompts.shorten(text));

  /// Αλλαγή τόνου (επίσημο/φιλικό/επαγγελματικό/χιουμοριστικό).
  Future<String?> changeTone(String text, ToneStyle tone) =>
      _ai.complete(AiPrompts.changeTone(text, tone));

  /// Ξαναγραφή με διαφορετικά λόγια.
  Future<String?> paraphrase(String text) =>
      _ai.complete(AiPrompts.paraphrase(text));

  // ───────────────────────────────────────────────────────────────
  // Voice → Structured Note
  // ───────────────────────────────────────────────────────────────

  /// Μετατροπή φωνητικού transcript σε structured note.
  /// Επιστρέφει null σε αποτυχία AI ή plain-text fallback αν αποτύχει
  /// το JSON parsing.
  Future<VoiceStructureResult?> structureVoiceInput(String transcript) async {
    if (transcript.trim().isEmpty) return null;

    final prompt =
        AiPrompts.structureVoiceInput(transcript, DateTime.now());
    final raw = await _ai.complete(prompt, maxTokens: 1500);
    if (raw == null) return null;

    final cleaned = _stripCodeFences(raw).trim();

    try {
      final json = jsonDecode(cleaned) as Map<String, dynamic>;
      return VoiceStructureResult.fromJson(json);
    } catch (_) {
      // Fallback: μη valid JSON → plain text note με το transcript
      return VoiceStructureResult(
        type: VoiceNoteType.text,
        title: _firstWords(transcript, 5),
        content: transcript,
      );
    }
  }

  // ───────────────────────────────────────────────────────────────
  // Helpers
  // ───────────────────────────────────────────────────────────────

  String _stripCodeFences(String s) {
    var t = s.trim();
    if (t.startsWith('```')) {
      final firstNewline = t.indexOf('\n');
      if (firstNewline > 0) {
        t = t.substring(firstNewline + 1);
      }
      if (t.endsWith('```')) {
        t = t.substring(0, t.length - 3);
      }
    }
    return t;
  }

  String _firstWords(String s, int n) {
    final words = s.trim().split(RegExp(r'\s+'));
    return words.take(n).join(' ');
  }
}

// ─────────────────────────────────────────────────────────────────────
// Voice structure result types
// ─────────────────────────────────────────────────────────────────────

enum VoiceNoteType { checklist, text, reminder }

class VoiceStructureResult {
  final VoiceNoteType type;
  final String title;
  final List<String>? items;
  final String? content;
  final DateTime? reminderAt;

  const VoiceStructureResult({
    required this.type,
    required this.title,
    this.items,
    this.content,
    this.reminderAt,
  });

  factory VoiceStructureResult.fromJson(Map<String, dynamic> json) {
    final type = _parseType(json['type'] as String?);
    final rawTitle = (json['title'] as String?)?.trim();
    final title = (rawTitle != null && rawTitle.isNotEmpty)
        ? rawTitle
        : 'Σημείωση';

    List<String>? items;
    if (type == VoiceNoteType.checklist) {
      final rawItems = json['items'] as List?;
      if (rawItems != null) {
        items = rawItems.map((e) {
          if (e is Map) {
            return (e['text'] as String?) ?? '';
          }
          return e.toString();
        }).where((s) => s.isNotEmpty).toList();
      }
    }

    final content = (json['content'] as String?)?.trim();

    DateTime? reminderAt;
    final reminderStr = json['reminder_at'] as String?;
    if (reminderStr != null && reminderStr.isNotEmpty) {
      reminderAt = DateTime.tryParse(reminderStr);
    }

    return VoiceStructureResult(
      type: type,
      title: title,
      items: items,
      content: content,
      reminderAt: reminderAt,
    );
  }

  static VoiceNoteType _parseType(String? raw) {
    switch (raw?.toLowerCase()) {
      case 'checklist':
        return VoiceNoteType.checklist;
      case 'reminder':
        return VoiceNoteType.reminder;
      default:
        return VoiceNoteType.text;
    }
  }
}