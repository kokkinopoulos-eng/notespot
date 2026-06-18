// lib/widgets/ai_action_menu.dart
//
// Bottom-sheet menu για AI Assistant actions (Pro v1.1).
// Orchestrates: action menu → (tone submenu αν χρειάζεται) → AI call
// με loading dialog → preview dialog. Επιστρέφει το τελικό AiPreviewResult.

import 'package:flutter/material.dart';
import '../services/ai_assistant_prompts.dart';
import '../services/ai_assistant_service.dart';
import 'ai_result_preview.dart';

enum AiActionType {
  grammarFix,
  summarize,
  expand,
  shorten,
  changeTone,
  paraphrase,
}

class _ActionOption {
  final AiActionType type;
  final IconData icon;
  final String label;
  final String? description;
  const _ActionOption({
    required this.type,
    required this.icon,
    required this.label,
    this.description,
  });
}

const List<_ActionOption> _options = [
  _ActionOption(
    type: AiActionType.grammarFix,
    icon: Icons.spellcheck,
    label: 'Διόρθωσε ορθογραφία/γραμματική',
    description: 'Διορθώνει λάθη χωρίς να αλλάζει το νόημα',
  ),
  _ActionOption(
    type: AiActionType.summarize,
    icon: Icons.short_text,
    label: 'Σύνοψε',
    description: '1-2 προτάσεις',
  ),
  _ActionOption(
    type: AiActionType.expand,
    icon: Icons.unfold_more,
    label: 'Επέκτεινε',
    description: 'Πρόσθεσε σχετικές λεπτομέρειες',
  ),
  _ActionOption(
    type: AiActionType.shorten,
    icon: Icons.unfold_less,
    label: 'Συντόμευσε',
    description: 'Στο μισό περίπου μήκος',
  ),
  _ActionOption(
    type: AiActionType.changeTone,
    icon: Icons.theater_comedy,
    label: 'Άλλαξε τόνο',
    description: 'Επίσημο, φιλικό, επαγγελματικό, χιουμοριστικό',
  ),
  _ActionOption(
    type: AiActionType.paraphrase,
    icon: Icons.autorenew,
    label: 'Ξαναγράψε',
    description: 'Με διαφορετικά λόγια',
  ),
];

class AiActionMenu {
  /// Εμφανίζει το menu, παίρνει την επιλογή του χρήστη, καλεί AI, δείχνει
  /// preview. Επιστρέφει [AiPreviewResult] με την τελική απόφαση ή null.
  static Future<AiPreviewResult?> show({
    required BuildContext context,
    required String text,
    String menuTitle = '✨ AI Assistant',
  }) async {
    if (text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Δεν υπάρχει κείμενο για επεξεργασία.')),
      );
      return null;
    }

    // Step 1: Action menu
    final action = await _showActionSheet(context, menuTitle);
    if (action == null || !context.mounted) return null;

    // Step 2: Tone submenu αν χρειάζεται
    ToneStyle? tone;
    if (action == AiActionType.changeTone) {
      tone = await _showToneSheet(context);
      if (tone == null || !context.mounted) return null;
    }

    // Step 3: AI call με loading dialog
    final firstResult = await _runWithLoading(
      context: context,
      operation: () => _callAi(text, action, tone),
    );
    if (firstResult == null || !context.mounted) return null;

    // Step 4: Preview dialog
    return await AiResultPreview.show(
      context: context,
      initialResult: firstResult,
      onRetry: () => _callAi(text, action, tone),
    );
  }

  // ───────────────────────────────────────────────────────────────
  // Internal helpers
  // ───────────────────────────────────────────────────────────────

  static Future<AiActionType?> _showActionSheet(
    BuildContext context,
    String title,
  ) {
    return showModalBottomSheet<AiActionType>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  title,
                  style: Theme.of(ctx).textTheme.titleLarge,
                ),
              ),
            ),
            const Divider(height: 1),
            for (final o in _options)
              ListTile(
                leading: Icon(o.icon),
                title: Text(o.label),
                subtitle: o.description != null ? Text(o.description!) : null,
                trailing: o.type == AiActionType.changeTone
                    ? const Icon(Icons.chevron_right)
                    : null,
                onTap: () => Navigator.of(ctx).pop(o.type),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  static Future<ToneStyle?> _showToneSheet(BuildContext context) {
    String cap(String s) =>
        s.isEmpty ? s : s.substring(0, 1).toUpperCase() + s.substring(1);
    return showModalBottomSheet<ToneStyle>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Διάλεξε τόνο',
                  style: Theme.of(ctx).textTheme.titleLarge,
                ),
              ),
            ),
            const Divider(height: 1),
            for (final t in ToneStyle.values)
              ListTile(
                leading: const Icon(Icons.theater_comedy_outlined),
                title: Text(cap(t.label)),
                onTap: () => Navigator.of(ctx).pop(t),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  static Future<T?> _runWithLoading<T>({
    required BuildContext context,
    required Future<T?> Function() operation,
  }) async {
    // Show loading dialog
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Dialog(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
              SizedBox(width: 20),
              Text('Επεξεργασία...'),
            ],
          ),
        ),
      ),
    );

    T? result;
    try {
      result = await operation();
    } catch (_) {
      result = null;
    }

    if (context.mounted) Navigator.of(context).pop();

    if (result == null && context.mounted) {
      final err = AiAssistantService.instance.lastError ?? 'Άγνωστο σφάλμα.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Αποτυχία AI: $err')),
      );
    }
    return result;
  }

  static Future<String?> _callAi(
    String text,
    AiActionType action,
    ToneStyle? tone,
  ) {
    final svc = AiAssistantService.instance;
    switch (action) {
      case AiActionType.grammarFix:
        return svc.grammarFix(text);
      case AiActionType.summarize:
        return svc.summarize(text);
      case AiActionType.expand:
        return svc.expand(text);
      case AiActionType.shorten:
        return svc.shorten(text);
      case AiActionType.changeTone:
        return svc.changeTone(text, tone ?? ToneStyle.friendly);
      case AiActionType.paraphrase:
        return svc.paraphrase(text);
    }
  }
}