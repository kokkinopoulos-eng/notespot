// lib/widgets/ai_result_preview.dart
//
// Preview dialog for AI Assistant results (Pro v1.1).
// Shows the result with 4 actions: Replace / Append / Retry / Cancel.
// Retry is handled internally without closing the dialog.

import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

/// Possible result actions.
enum AiPreviewAction { replace, append }

/// Result wrapper returned by the dialog to the caller.
class AiPreviewResult {
  final AiPreviewAction action;
  final String text;
  const AiPreviewResult(this.action, this.text);
}

class AiResultPreview {
  /// Shows the preview dialog. Returns [AiPreviewResult] or null if cancelled.
  ///
  /// - [initialResult]: the initial text returned by the AI
  /// - [onRetry]: callback that re-runs the AI call (returns new text or null)
  static Future<AiPreviewResult?> show({
    required BuildContext context,
    required String initialResult,
    required Future<String?> Function() onRetry,
  }) {
    return showDialog<AiPreviewResult>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _AiPreviewDialog(
        initialResult: initialResult,
        onRetry: onRetry,
      ),
    );
  }
}

class _AiPreviewDialog extends StatefulWidget {
  final String initialResult;
  final Future<String?> Function() onRetry;

  const _AiPreviewDialog({
    required this.initialResult,
    required this.onRetry,
  });

  @override
  State<_AiPreviewDialog> createState() => _AiPreviewDialogState();
}

class _AiPreviewDialogState extends State<_AiPreviewDialog> {
  late String _currentResult;
  bool _isRetrying = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _currentResult = widget.initialResult;
  }

  Future<void> _retry() async {
    setState(() {
      _isRetrying = true;
      _error = null;
    });
    final l10n = AppLocalizations.of(context);
    try {
      final result = await widget.onRetry();
      if (!mounted) return;
      setState(() {
        _isRetrying = false;
        if (result != null && result.isNotEmpty) {
          _currentResult = result;
        } else {
          _error = l10n.aiNoResult;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isRetrying = false;
        _error = l10n.aiErrorDetail(e.toString());
      });
    }
  }

  void _close([AiPreviewResult? result]) {
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 720),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ─── Title bar ────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.aiPreviewTitle,
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: l10n.cancel,
                    onPressed: _isRetrying ? null : () => _close(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // ─── Content ──────────────────────────────────────────
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Stack(
                  children: [
                    SelectableText(
                      _currentResult,
                      style: theme.textTheme.bodyLarge,
                    ),
                    if (_isRetrying)
                      Positioned.fill(
                        child: Container(
                          color: theme.colorScheme.surface.withValues(alpha: 0.75),
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // ─── Error banner ─────────────────────────────────────
            if (_error != null)
              Container(
                width: double.infinity,
                color: theme.colorScheme.errorContainer,
                padding: const EdgeInsets.all(12),
                child: Text(
                  _error!,
                  style: TextStyle(
                    color: theme.colorScheme.onErrorContainer,
                  ),
                ),
              ),

            const Divider(height: 1),

            // ─── Actions ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.refresh),
                    label: Text(l10n.aiRetry),
                    onPressed: _isRetrying ? null : _retry,
                  ),
                  TextButton(
                    onPressed: _isRetrying ? null : () => _close(),
                    child: Text(l10n.cancel),
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.add),
                    label: Text(l10n.aiAppend),
                    onPressed: _isRetrying
                        ? null
                        : () => _close(AiPreviewResult(
                              AiPreviewAction.append,
                              _currentResult,
                            )),
                  ),
                  FilledButton.icon(
                    icon: const Icon(Icons.check),
                    label: Text(l10n.aiReplace),
                    onPressed: _isRetrying
                        ? null
                        : () => _close(AiPreviewResult(
                              AiPreviewAction.replace,
                              _currentResult,
                            )),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
