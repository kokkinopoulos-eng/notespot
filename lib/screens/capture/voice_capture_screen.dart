import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../l10n/app_localizations.dart';
import '../../models/note.dart';
import '../../services/cloud_ai_service.dart';
import '../../services/db_service.dart';

class VoiceCaptureScreen extends StatefulWidget {
  const VoiceCaptureScreen({super.key});

  @override
  State<VoiceCaptureScreen> createState() => _VoiceCaptureScreenState();
}

class _VoiceCaptureScreenState extends State<VoiceCaptureScreen> {
  final _speech = SpeechToText();
  bool _available = false;
  bool _listening = false;
  String _transcript = '';
  String _partial = '';

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _speech.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    _available = await _speech.initialize(onStatus: _onStatus);
    if (mounted) setState(() {});
  }

  void _onStatus(String status) {
    if (!mounted) return;
    setState(() => _listening = _speech.isListening);
  }

  Future<void> _toggle() async {
    if (_speech.isListening) {
      await _speech.stop();
      return;
    }
    final localeCode = Localizations.localeOf(context).languageCode;
    final localeId = localeCode == 'el' ? 'el-GR' : 'en-US';
    await _speech.listen(
      onResult: _onResult,
      localeId: localeId,
      listenOptions: SpeechListenOptions(
        partialResults: true,
        listenMode: ListenMode.dictation,
        cancelOnError: true,
      ),
      pauseFor: const Duration(seconds: 5),
      listenFor: const Duration(minutes: 2),
    );
    if (mounted) setState(() => _listening = true);
  }

  void _onResult(SpeechRecognitionResult result) {
    if (!mounted) return;
    setState(() {
      if (result.finalResult) {
        _transcript = ('$_transcript ${result.recognizedWords}').trim();
        _partial = '';
      } else {
        _partial = result.recognizedWords;
      }
    });
  }

  Future<void> _save() async {
    final text = ('$_transcript $_partial').trim();
    if (text.isEmpty) return;
    final l10n = AppLocalizations.of(context);
    final langName =
        Localizations.localeOf(context).languageCode == 'el' ? 'Greek' : 'English';
    await _speech.stop();
    final now = DateTime.now();
    final stamp = DateFormat('d/M HH:mm').format(now);
    final noteId = await DbService.instance.insert(Note(
      type: NoteType.voice,
      title: '${l10n.voiceNote} $stamp',
      content: text,
      createdAt: now,
      updatedAt: now,
    ));
    // fire-and-forget AI enrichment
    unawaited(_enrichNote(noteId, text: text, langName: langName));
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  Future<void> _enrichNote(int noteId,
      {required String text, required String langName}) async {
    final analysis =
        await CloudAiService.instance.analyzeText(text, langName);
    if (analysis == null) return;
    final note = await DbService.instance.getById(noteId);
    if (note == null) return;
    final updated = Note(
      id: note.id,
      type: note.type,
      title: note.title,
      content: note.content,
      category: analysis.category,
      tags: analysis.tags,
      mediaPath: note.mediaPath,
      createdAt: note.createdAt,
      updatedAt: DateTime.now(),
    );
    await DbService.instance.update(updated);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = ('$_transcript $_partial').trim();
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.voiceNote),
        actions: [
          TextButton(
            onPressed: text.isEmpty ? null : _save,
            child: Text(l10n.save),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  text.isEmpty
                      ? (_available ? l10n.tapToRecord : l10n.speechUnavailable)
                      : text,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_listening)
              Text(l10n.listening,
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.error)),
            const SizedBox(height: 16),
            FloatingActionButton.large(
              onPressed: _available ? _toggle : null,
              backgroundColor:
                  _listening ? Theme.of(context).colorScheme.error : null,
              child: Icon(_listening ? Icons.stop : Icons.mic),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}