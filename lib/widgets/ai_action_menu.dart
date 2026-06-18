// lib/widgets/ai_action_menu.dart
//
// Bottom-sheet menu for AI Assistant actions (Pro v1.1).
// Orchestrates: action menu → (tone submenu if needed) → AI call
// with loading dialog → preview dialog. Returns the final AiPreviewResult.

import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
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
  const _ActionOption({required this.type, required this.icon});
}

const List<_ActionOption> _options = [
  _ActionOption(type: AiActionType.grammarFix, icon: Icons.spellcheck),
  _ActionOption(type: AiActionType.summarize, icon: Icons.short_text),
  _ActionOption(type: AiActionType.expand, icon: Icons.unfold_more),
  _ActionOption(type: AiActionType.shorten, icon: Icons.unfold_less),
  _ActionOption(type: AiActionType.changeTone, icon: Icons.theater_comedy),
  _ActionOption(type: AiActionType.paraphrase, icon: Icons.autorenew),
];

class AiActionMenu {
  /// Shows the menu, gets the user's choice, calls AI, shows preview.
  /// Returns [AiPreviewResult] with the final decision or null.
  static Future<AiPreviewResult?> show({
    required BuildContext context,
    required String text,
  }) async {
    final l10n = AppLocalizations.of(context);
    if (text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.aiNoText)),
      );
      return null;
    }

    // Step 1: Action menu
    final action = await _showActionSheet(context, l10n);
    if (action == null || !context.mounted) return null;

    // Step 2: Tone submenu if needed
    ToneStyle? tone;
    if (action == AiActionType.changeTone) {
      tone = await _showToneSheet(context, l10n);
      if (tone == null || !context.mounted) return null;
    }

    // Step 3: AI call with loading dialog
    final firstResult = await _runWithLoading(
      context: context,
      l10n: l10n,
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
  // Label resolvers
  // ───────────────────────────────────────────────────────────────

  static String _actionLabel(AppLocalizations l10n, AiActionType type) =>
      switch (type) {
        AiActionType.grammarFix => l10n.aiActionGrammarFix,
        AiActionType.summarize => l10n.aiActionSummarize,
        AiActionType.expand => l10n.aiActionExpand,
        AiActionType.shorten => l10n.aiActionShorten,
        AiActionType.changeTone => l10n.aiActionChangeTone,
        AiActionType.paraphrase => l10n.aiActionParaphrase,
      };

  static String _actionDesc(AppLocalizations l10n, AiActionType type) =>
      switch (type) {
        AiActionType.grammarFix => l10n.aiActionGrammarFixDesc,
        AiActionType.summarize => l10n.aiActionSummarizeDesc,
        AiActionType.expand => l10n.aiActionExpandDesc,
        AiActionType.shorten => l10n.aiActionShortenDesc,
        AiActionType.changeTone => l10n.aiActionChangeToneDesc,
        AiActionType.paraphrase => l10n.aiActionParaphraseDesc,
      };

  static String _toneLabel(AppLocalizations l10n, ToneStyle tone) =>
      switch (tone) {
        ToneStyle.formal => l10n.toneFormal,
        ToneStyle.friendly => l10n.toneFriendly,
        ToneStyle.professional => l10n.toneProfessional,
        ToneStyle.humorous => l10n.toneHumorous,
      };

  // ───────────────────────────────────────────────────────────────
  // Internal helpers
  // ───────────────────────────────────────────────────────────────

  static Future<AiActionType?> _showActionSheet(
    BuildContext context,
    AppLocalizations l10n,
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
                    l10n.aiAssistantTitle,
                    style: Theme.of(ctx).textTheme.titleLarge,
                  ),
                ),
              ),
              const Divider(height: 1),
              for (final o in _options)
                ListTile(
                  leading: Icon(o.icon),
                  title: Text(_actionLabel(l10n, o.type)),
                  subtitle: Text(_actionDesc(l10n, o.type)),
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

  static Future<ToneStyle?> _showToneSheet(
    BuildContext context,
    AppLocalizations l10n,
  ) {
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
                    l10n.aiChooseTone,
                    style: Theme.of(ctx).textTheme.titleLarge,
                  ),
                ),
              ),
              const Divider(height: 1),
              for (final t in ToneStyle.values)
                ListTile(
                  leading: const Icon(Icons.theater_comedy_outlined),
                  title: Text(_toneLabel(l10n, t)),
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
    required AppLocalizations l10n,
    required Future<T?> Function() operation,
  }) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
              const SizedBox(width: 20),
              Text(l10n.aiProcessing),
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
      final err = AiAssistantService.instance.lastError ?? l10n.aiUnknownError;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.aiFailure(err))),
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
