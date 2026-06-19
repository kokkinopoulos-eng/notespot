// lib/screens/voice/voice_note_screen.dart
//
// Smart Voice flow (Pro v1.1 Wave 2):
// User dictates → STT transcript → optional AI structuring → returns
// VoiceNoteResult στον caller (home_screen converts to a Note).
//
// TODO l10n: hardcoded Greek strings — θα μετακινηθούν σε ARB στο
// επόμενο localization pass (Code CLI).

import 'package:flutter/material.dart';
import '../../core/feature_flags.dart';
import '../../l10n/app_localizations.dart';
import '../../services/ai_assistant_service.dart';
import '../../services/voice_structuring_service.dart';

/// Αποτέλεσμα που επιστρέφεται στον caller.
class VoiceNoteResult {
  final String transcript;

  /// null αν ο χρήστης επέλεξε plain text αντί για AI structuring.
  final VoiceStructureResult? structured;

  const VoiceNoteResult({
    required this.transcript,
    this.structured,
  });
}

enum _VoiceState {
  idle,
  listening,
  transcribed,
  structuring,
  ready,
}

class VoiceNoteScreen extends StatefulWidget {
  final String localeId;

  const VoiceNoteScreen({
    super.key,
    this.localeId = 'el_GR',
  });

  /// Push the screen και επιστρέφει το αποτέλεσμα.
  static Future<VoiceNoteResult?> show(
    BuildContext context, {
    String localeId = 'el_GR',
  }) {
    return Navigator.of(context).push<VoiceNoteResult>(
      MaterialPageRoute(
        builder: (_) => VoiceNoteScreen(localeId: localeId),
      ),
    );
  }

  @override
  State<VoiceNoteScreen> createState() => _VoiceNoteScreenState();
}

class _VoiceNoteScreenState extends State<VoiceNoteScreen> {
  final _service = VoiceStructuringService.instance;

  _VoiceState _state = _VoiceState.idle;
  String _transcript = '';
  double _soundLevel = 0;
  String? _error;
  VoiceStructureResult? _structuredResult;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _service.cancel();
    super.dispose();
  }

  Future<void> _initialize() async {
    final ok = await _service.initialize(
      onError: (e) {
        if (!mounted) return;
        setState(() {
          _error = e;
          _state = _VoiceState.idle;
        });
      },
    );
    if (!ok && mounted) {
      setState(() {
        // TODO l10n
        _error = 'Δεν μπόρεσα να ξεκινήσω την αναγνώριση φωνής. '
            'Έλεγξε ότι έδωσες δικαίωμα μικροφώνου.';
      });
    }
  }

  Future<void> _startListening() async {
    setState(() {
      _state = _VoiceState.listening;
      _transcript = '';
      _error = null;
    });

    final started = await _service.startListening(
      localeId: widget.localeId,
      onResult: (transcript, isFinal) {
        if (!mounted) return;
        setState(() {
          _transcript = transcript;
          if (isFinal) {
            _state = _VoiceState.transcribed;
          }
        });
      },
      onSoundLevel: (level) {
        if (!mounted) return;
        setState(() => _soundLevel = level);
      },
    );

    if (!started && mounted) {
      setState(() {
        _state = _VoiceState.idle;
        // TODO l10n
        _error = _service.lastError ?? 'Σφάλμα εκκίνησης.';
      });
    }
  }

  Future<void> _stopListening() async {
    await _service.stopListening();
    if (!mounted) return;
    setState(() {
      _state = _VoiceState.transcribed;
    });
  }

  Future<void> _structureWithAi() async {
    if (_transcript.trim().isEmpty) return;
    setState(() => _state = _VoiceState.structuring);

    final result = await _service.structure(_transcript);
    if (!mounted) return;

    if (result == null) {
      setState(() {
        _state = _VoiceState.transcribed;
        // TODO l10n
        _error = AiAssistantService.instance.lastError ??
            'Δεν μπόρεσα να δομήσω τη σημείωση.';
      });
      return;
    }

    setState(() {
      _structuredResult = result;
      _state = _VoiceState.ready;
    });
  }

  void _saveAsText() {
    Navigator.of(context).pop(
      VoiceNoteResult(transcript: _transcript),
    );
  }

  void _saveStructured() {
    Navigator.of(context).pop(
      VoiceNoteResult(
        transcript: _transcript,
        structured: _structuredResult,
      ),
    );
  }

  void _restart() {
    setState(() {
      _state = _VoiceState.idle;
      _transcript = '';
      _structuredResult = null;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context).smartVoiceTitle)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_state) {
      case _VoiceState.idle:
        return _buildIdle();
      case _VoiceState.listening:
        return _buildListening();
      case _VoiceState.transcribed:
        return _buildTranscribed();
      case _VoiceState.structuring:
        return _buildStructuring();
      case _VoiceState.ready:
        return _buildReady();
    }
  }

  // ───────────────────────────────────────────────────────────────
  // States
  // ───────────────────────────────────────────────────────────────

  Widget _buildIdle() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.mic, size: 96, color: Colors.grey),
        const SizedBox(height: 24),
        // TODO l10n
        const Text(
          'Πάτα το μικρόφωνο για να ξεκινήσεις',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16),
        ),
        const SizedBox(height: 32),
        if (_error != null) _ErrorBanner(error: _error!),
        const SizedBox(height: 32),
        FilledButton.icon(
          onPressed: _startListening,
          icon: const Icon(Icons.mic),
          // TODO l10n
          label: const Text('Ξεκίνα'),
          style: FilledButton.styleFrom(
            padding:
                const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildListening() {
    final primary = Theme.of(context).colorScheme.primary;
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 100),
              width: 120 + _soundLevel * 4,
              height: 120 + _soundLevel * 4,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: primary.withOpacity(0.2),
              ),
            ),
            const Icon(Icons.mic, size: 64, color: Colors.red),
          ],
        ),
        const SizedBox(height: 16),
        // TODO l10n
        const Text('Ακούω...', style: TextStyle(fontSize: 16)),
        const SizedBox(height: 24),
        Expanded(
          child: SingleChildScrollView(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                // TODO l10n
                _transcript.isEmpty ? 'Μίλα...' : _transcript,
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _stopListening,
          icon: const Icon(Icons.stop),
          // TODO l10n
          label: const Text('Σταμάτα'),
          style: FilledButton.styleFrom(
            padding:
                const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildTranscribed() {
    final isEmpty = _transcript.trim().isEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: SelectableText(
                // TODO l10n
                _transcript.isEmpty ? '(κενό)' : _transcript,
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          _ErrorBanner(error: _error!),
        ],
        const SizedBox(height: 16),
        if (kCloudAiEnabled)
          FilledButton.icon(
            onPressed: isEmpty ? null : _structureWithAi,
            icon: const Icon(Icons.auto_awesome),
            // TODO l10n
            label: const Text('Δομή με AI'),
          ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: isEmpty ? null : _saveAsText,
          icon: const Icon(Icons.text_fields),
          // TODO l10n
          label: const Text('Αποθήκευσε ως κείμενο'),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: _restart,
          icon: const Icon(Icons.refresh),
          // TODO l10n
          label: const Text('Ξανά'),
        ),
      ],
    );
  }

  Widget _buildStructuring() {
    // TODO l10n
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Επεξεργασία...'),
        ],
      ),
    );
  }

  Widget _buildReady() {
    final r = _structuredResult;
    if (r == null) return _buildTranscribed();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(r.title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        _TypeChip(type: r.type),
        const SizedBox(height: 16),
        Expanded(
          child: SingleChildScrollView(
            child: _StructuredPreview(result: r),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _saveStructured,
          icon: const Icon(Icons.save),
          // TODO l10n
          label: const Text('Αποθήκευσε'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _saveAsText,
          icon: const Icon(Icons.text_fields),
          // TODO l10n
          label: const Text('Αντί για αυτό, αποθήκευσε ως κείμενο'),
        ),
        TextButton.icon(
          onPressed: _restart,
          icon: const Icon(Icons.refresh),
          // TODO l10n
          label: const Text('Ξανά'),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Helper widgets
// ─────────────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  final String error;
  const _ErrorBanner({required this.error});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        error,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onErrorContainer,
        ),
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  final VoiceNoteType type;
  const _TypeChip({required this.type});

  @override
  Widget build(BuildContext context) {
    final IconData icon;
    final String label;
    switch (type) {
      case VoiceNoteType.checklist:
        icon = Icons.checklist;
        // TODO l10n
        label = 'Λίστα';
        break;
      case VoiceNoteType.reminder:
        icon = Icons.notifications;
        // TODO l10n
        label = 'Υπενθύμιση';
        break;
      case VoiceNoteType.text:
        icon = Icons.text_fields;
        // TODO l10n
        label = 'Κείμενο';
        break;
    }
    return Chip(avatar: Icon(icon, size: 18), label: Text(label));
  }
}

class _StructuredPreview extends StatelessWidget {
  final VoiceStructureResult result;
  const _StructuredPreview({required this.result});

  @override
  Widget build(BuildContext context) {
    final r = result;
    switch (r.type) {
      case VoiceNoteType.checklist:
        final items = r.items ?? <String>[];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: items
              .map((item) => ListTile(
                    leading: const Icon(Icons.check_box_outline_blank),
                    title: Text(item),
                    dense: true,
                  ))
              .toList(),
        );
      case VoiceNoteType.reminder:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (r.reminderAt != null)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  // TODO l10n
                  'Πότε: ${r.reminderAt!.toLocal()}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            if (r.content != null && r.content!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(r.content!),
              ),
          ],
        );
      case VoiceNoteType.text:
        return Padding(
          padding: const EdgeInsets.all(8),
          child: SelectableText(
            r.content ?? '',
            style: const TextStyle(fontSize: 16),
          ),
        );
    }
  }
}