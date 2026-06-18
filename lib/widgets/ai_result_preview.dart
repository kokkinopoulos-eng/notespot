// lib/widgets/ai_result_preview.dart
//
// Preview dialog για AI Assistant results (Pro v1.1).
// Δείχνει το αποτέλεσμα με 4 actions: Αντικατάσταση / Προσθήκη / Ξανά / Άκυρο.
// Το retry γίνεται internally χωρίς να κλείνει το dialog.

import 'package:flutter/material.dart';

/// Πιθανές ενέργειες αποτελέσματος.
enum AiPreviewAction { replace, append }

/// Result wrapper που επιστρέφει το dialog στον caller.
class AiPreviewResult {
  final AiPreviewAction action;
  final String text;
  const AiPreviewResult(this.action, this.text);
}

class AiResultPreview {
  /// Εμφανίζει το preview dialog. Επιστρέφει [AiPreviewResult] ή null
  /// αν ο χρήστης ακύρωσε.
  ///
  /// - [initialResult]: το αρχικό αποτέλεσμα που έφερε η AI
  /// - [onRetry]: callback που τρέχει ξανά την AI κλήση (επιστρέφει
  ///   νέο text ή null σε αποτυχία)
  /// - [title]: header του dialog
  static Future<AiPreviewResult?> show({
    required BuildContext context,
    required String initialResult,
    required Future<String?> Function() onRetry,
    String title = '✨ Αποτέλεσμα',
  }) {
    return showDialog<AiPreviewResult>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _AiPreviewDialog(
        initialResult: initialResult,
        onRetry: onRetry,
        title: title,
      ),
    );
  }
}

class _AiPreviewDialog extends StatefulWidget {
  final String initialResult;
  final Future<String?> Function() onRetry;
  final String title;

  const _AiPreviewDialog({
    required this.initialResult,
    required this.onRetry,
    required this.title,
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
    try {
      final result = await widget.onRetry();
      if (!mounted) return;
      setState(() {
        _isRetrying = false;
        if (result != null && result.isNotEmpty) {
          _currentResult = result;
        } else {
          _error = 'Δεν λάβαμε αποτέλεσμα. Δοκίμασε ξανά.';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isRetrying = false;
        _error = 'Σφάλμα: $e';
      });
    }
  }

  void _close([AiPreviewResult? result]) {
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
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
                      widget.title,
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Άκυρο',
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
                          color: theme.colorScheme.surface.withOpacity(0.75),
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
                    label: const Text('Ξανά'),
                    onPressed: _isRetrying ? null : _retry,
                  ),
                  TextButton(
                    onPressed: _isRetrying ? null : () => _close(),
                    child: const Text('Άκυρο'),
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Προσθήκη'),
                    onPressed: _isRetrying
                        ? null
                        : () => _close(AiPreviewResult(
                              AiPreviewAction.append,
                              _currentResult,
                            )),
                  ),
                  FilledButton.icon(
                    icon: const Icon(Icons.check),
                    label: const Text('Αντικατάσταση'),
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