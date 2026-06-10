import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../l10n/app_localizations.dart';
import '../../models/note.dart';
import '../../services/cloud_ai_service.dart';
import '../../services/db_service.dart';
import '../../services/media_service.dart';
import '../../widgets/drawing_canvas.dart';

enum _EditorMode { keyboard, pen }

class NoteEditorScreen extends StatefulWidget {
  const NoteEditorScreen({super.key});

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  final _titleCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();
  final _drawCtrl = DrawingCanvasController();
  final _speech = SpeechToText();
  _EditorMode _mode = _EditorMode.keyboard;
  String? _attachedPhotoPath;
  Uint8List? _drawPreview; // mini preview of the drawing in keyboard mode
  bool _listening = false;
  bool _speechAvailable = false;
  bool _saved = false; // guards the PopScope cleanup

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    _speechAvailable = await _speech.initialize(onStatus: _onSpeechStatus);
    if (mounted) setState(() {});
  }

  void _onSpeechStatus(String status) {
    if (!mounted) return;
    setState(() => _listening = _speech.isListening);
  }

  @override
  void dispose() {
    _speech.cancel();
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    _drawCtrl.dispose();
    super.dispose();
  }

  bool get _hasContent =>
      _contentCtrl.text.trim().isNotEmpty ||
      !_drawCtrl.isEmpty ||
      _attachedPhotoPath != null;

  Future<void> _switchToKeyboard() async {
    Uint8List? preview;
    if (!_drawCtrl.isEmpty) {
      preview = await _drawCtrl.toPngBytes();
    }
    if (!mounted) return;
    setState(() {
      _drawPreview = preview;
      _mode = _EditorMode.keyboard;
    });
  }

  void _switchToPen() {
    FocusScope.of(context).unfocus();
    setState(() => _mode = _EditorMode.pen);
  }

  Future<void> _capturePhoto() async {
    final path = await MediaService.instance.capturePhoto();
    if (path == null || !mounted) return;
    setState(() {
      _attachedPhotoPath = path;
      _mode = _EditorMode.keyboard;
    });
  }

  Future<void> _removePhoto() async {
    final path = _attachedPhotoPath;
    setState(() => _attachedPhotoPath = null);
    await MediaService.instance.deleteMedia(path);
  }

  Future<void> _toggleDictation() async {
    if (_listening) {
      await _speech.stop();
      return;
    }
    final localeId = Localizations.localeOf(context).languageCode == 'el'
        ? 'el-GR'
        : 'en-US';
    await _speech.listen(
      onResult: _onSpeechResult,
      localeId: localeId,
      listenOptions: SpeechListenOptions(
        partialResults: false,
        listenMode: ListenMode.dictation,
        cancelOnError: true,
      ),
      pauseFor: const Duration(seconds: 5),
      listenFor: const Duration(minutes: 2),
    );
    if (mounted) setState(() => _listening = true);
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    if (!result.finalResult || !mounted) return;
    final words = result.recognizedWords.trim();
    if (words.isEmpty) return;
    final current = _contentCtrl.text;
    _contentCtrl.text = current.isEmpty ? words : '$current $words';
    _contentCtrl.selection =
        TextSelection.collapsed(offset: _contentCtrl.text.length);
    setState(() {});
  }

  Future<void> _save(AppLocalizations l10n) async {
    final now = DateTime.now();
    final stamp = DateFormat('d/M HH:mm').format(now);
    final title = _titleCtrl.text.trim().isEmpty
        ? '${l10n.textNote} $stamp'
        : _titleCtrl.text.trim();
    final content = _contentCtrl.text.trim();
    final langName = Localizations.localeOf(context).languageCode == 'el'
        ? 'Greek'
        : 'English';

    String? mediaPath = _attachedPhotoPath;
    NoteType type;

    if (mediaPath != null) {
      type = NoteType.photo;
    } else if (!_drawCtrl.isEmpty) {
      final bytes = await _drawCtrl.toPngBytes();
      if (bytes != null) {
        mediaPath = await MediaService.instance.savePngBytes(bytes);
      } else {
        debugPrint('[EDITOR] toPngBytes returned null with strokes present');
      }
      type = content.isEmpty ? NoteType.handwriting : NoteType.text;
    } else {
      type = NoteType.text;
    }

    final noteId = await DbService.instance.insert(Note(
      type: type,
      title: title,
      content: content,
      mediaPath: mediaPath,
      createdAt: now,
      updatedAt: now,
    ));

    _saved = true; // PopScope must NOT delete media after this point

    if (mediaPath != null) {
      unawaited(_enrichImage(noteId, mediaPath, langName));
    } else if (content.isNotEmpty) {
      unawaited(_enrichText(noteId, content, langName));
    }

    if (!mounted) return;
    Navigator.pop(context, true);
  }

  /// AI extracted text must never overwrite what the user typed.
  String _mergeContent(String existing, String extracted) {
    final ex = extracted.trim();
    if (ex.isEmpty) return existing;
    if (existing.isEmpty) return ex;
    if (existing.contains(ex)) return existing;
    return '$existing\n\n$ex';
  }

  Future<void> _enrichImage(int noteId, String path, String lang) async {
    final analysis = await CloudAiService.instance.analyzeImage(path, lang);
    if (analysis == null) return;
    final note = await DbService.instance.getById(noteId);
    if (note == null) return;
    await DbService.instance.update(note.copyWith(
      content: _mergeContent(note.content, analysis.extractedText),
      category: analysis.category,
      tags: analysis.tags,
      updatedAt: DateTime.now(),
    ));
  }

  Future<void> _enrichText(int noteId, String text, String lang) async {
    final analysis = await CloudAiService.instance.analyzeText(text, lang);
    if (analysis == null) return;
    final note = await DbService.instance.getById(noteId);
    if (note == null) return;
    await DbService.instance.update(note.copyWith(
      category: analysis.category,
      tags: analysis.tags,
      updatedAt: DateTime.now(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final hasPhoto = _attachedPhotoPath != null;
    final hasStrokes = !_drawCtrl.isEmpty;
    final showDrawPreview =
        _mode == _EditorMode.keyboard && hasStrokes && _drawPreview != null;

    return PopScope(
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop && !_saved) {
          await MediaService.instance.deleteMedia(_attachedPhotoPath);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: TextField(
            controller: _titleCtrl,
            decoration: InputDecoration(
              hintText: l10n.titleLabel,
              border: InputBorder.none,
            ),
            style: Theme.of(context).textTheme.titleMedium,
            onChanged: (_) => setState(() {}),
          ),
          actions: [
            AnimatedBuilder(
              animation: _drawCtrl,
              builder: (_, __) => TextButton(
                onPressed: _hasContent ? () => _save(l10n) : null,
                child: Text(l10n.save),
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            if (hasPhoto)
              Stack(
                children: [
                  Image.file(File(_attachedPhotoPath!),
                      height: 160, width: double.infinity, fit: BoxFit.cover),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: CircleAvatar(
                      backgroundColor: Colors.black54,
                      child: IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: _removePhoto,
                      ),
                    ),
                  ),
                ],
              ),
            if (showDrawPreview)
              GestureDetector(
                onTap: _switchToPen,
                child: Container(
                  height: 110,
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: Theme.of(context).colorScheme.outlineVariant),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Image.memory(_drawPreview!,
                            fit: BoxFit.contain),
                      ),
                      Positioned(
                        right: 6,
                        bottom: 6,
                        child: Icon(Icons.gesture,
                            size: 18,
                            color: Theme.of(context).colorScheme.primary),
                      ),
                    ],
                  ),
                ),
              ),
            if (_listening)
              Container(
                width: double.infinity,
                color: Theme.of(context).colorScheme.errorContainer,
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(l10n.listening,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color:
                            Theme.of(context).colorScheme.onErrorContainer)),
              ),
            Expanded(
              child: IndexedStack(
                index: _mode == _EditorMode.keyboard ? 0 : 1,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: TextField(
                      controller: _contentCtrl,
                      maxLines: null,
                      expands: true,
                      decoration: InputDecoration(
                        hintText: l10n.noteHint,
                        border: InputBorder.none,
                      ),
                      style: Theme.of(context).textTheme.bodyLarge,
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  DrawingCanvas(controller: _drawCtrl),
                ],
              ),
            ),
            SafeArea(
              child: Container(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.keyboard_alt_outlined),
                      color: _mode == _EditorMode.keyboard
                          ? Theme.of(context).colorScheme.primary
                          : null,
                      onPressed: _switchToKeyboard,
                    ),
                    IconButton(
                      icon: const Icon(Icons.gesture),
                      color: _mode == _EditorMode.pen
                          ? Theme.of(context).colorScheme.primary
                          : null,
                      onPressed: hasPhoto ? null : _switchToPen,
                    ),
                    IconButton(
                      icon: const Icon(Icons.photo_camera_outlined),
                      onPressed: hasStrokes ? null : _capturePhoto,
                    ),
                    IconButton(
                      icon: Icon(
                        _listening ? Icons.mic : Icons.mic_outlined,
                        color: _listening
                            ? Theme.of(context).colorScheme.error
                            : null,
                      ),
                      onPressed: _speechAvailable ? _toggleDictation : null,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}