import 'dart:async';
import 'dart:io' as dart_io;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/feature_flags.dart';
import '../../l10n/app_localizations.dart';
import '../../services/premium_service.dart';
import '../../widgets/locked_feature.dart';
import '../../widgets/paywall_sheet.dart';
import '../../models/note.dart';
import '../../services/cloud_ai_service.dart';
import '../../services/db_service.dart';
import '../../services/eva_service.dart';
import '../../services/ink_math_service.dart';
import '../../services/ink_text_service.dart';
import '../../services/local_analysis_service.dart';
import '../../services/media_service.dart';
import '../../widgets/drawing_canvas.dart';
import '../../widgets/ai_action_menu.dart';
import '../../widgets/ai_result_preview.dart';

const int kMaxInkPages = 5;

/// Notebook lines for the ink canvas pane. Fills the bgColor first, then
/// draws ruled lines and a left margin guide on top.
class _NotebookPainter extends CustomPainter {
  const _NotebookPainter({this.bgColor = Colors.black});
  final Color bgColor;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = bgColor,
    );
  
  }

  @override
  bool shouldRepaint(_NotebookPainter old) => old.bgColor != bgColor;
}

/// Lightweight notebook lines for the text pane (always white bg).
/// Thin 0.5 px blue-tinted rules and margin, independent of canvas bg.
class _TextNotebookPainter extends CustomPainter {
  const _TextNotebookPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blue.withValues(alpha: 0.3)
      ..strokeWidth = 0.5;
    const step = 30.0;
    for (double y = step; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    canvas.drawLine(const Offset(42, 0), Offset(42, size.height), paint);
  }

  @override
  bool shouldRepaint(_TextNotebookPainter old) => false;
}

class NoteEditorScreen extends StatefulWidget {
  const NoteEditorScreen({super.key, this.editNote});

  /// If set, the editor opens in edit mode with existing ink as ghost layer.
  final Note? editNote;

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  final _titleCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();
  final _contentFocus = FocusNode();
  final _textScroll = ScrollController();
  final List<DrawingCanvasController> _pages = [DrawingCanvasController()];
  int _page = 0;
  int _paneMode = 1; // 1=text-only, 2=ink-only
  bool _mathLoading = false;
  bool _textLoading = false;
  ui.Image? _ghostImage;

  // AI chat mode
  bool _isAiChat = false;
  final _chatInputCtrl = TextEditingController();
  final _chatScrollCtrl = ScrollController();
  bool _aiChatLoading = false;

  DrawingCanvasController get _ink => _pages[_page];

  @override
  void initState() {
    super.initState();
    _loadEditNote();
    _loadPaneMode();
    _loadStylusPrefs();
  }

  Future<void> _loadPaneMode() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getInt('editor_pane_mode');
    if (saved != null && (saved == 1 || saved == 2) && mounted) {
      setState(() => _paneMode = saved);
    }
  }

  Future<void> _savePaneMode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('editor_pane_mode', _paneMode);
  }

  Future<void> _loadStylusPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final detected = prefs.getBool('stylus_detected') ?? false;
    final only = prefs.getBool('stylus_only') ?? false;
    if (!mounted) return;
    for (final p in _pages) {
      if (detected) p.stylusDetected = detected;
      if (only) p.stylusOnly = only;
      p.onStylusStateChanged = _saveStylusPrefs;
    }
    if (detected || only) setState(() {});
  }

  void _saveStylusPrefs(bool detected, bool only) {
    SharedPreferences.getInstance().then((prefs) {
      prefs.setBool('stylus_detected', detected);
      prefs.setBool('stylus_only', only);
    });
  }

  Future<void> _loadEditNote() async {
    final note = widget.editNote;
    if (note == null) return;
    _titleCtrl.text = note.title;
    _contentCtrl.text = note.content;
    if (note.isAiChat) {
      setState(() { _isAiChat = true; _paneMode = 1; });
      _scrollToBottom();
    }
    // Restore canvas background for all existing pages.
    for (final p in _pages) {
      p.bgColor = note.canvasBg;
    }
    final path = note.mediaPath;
    if (path != null) {
      try {
        final f = dart_io.File(path);
        final bytes = await f.readAsBytes();
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        if (mounted) setState(() => _ghostImage = frame.image);
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    _contentFocus.dispose();
    _textScroll.dispose();
    _chatInputCtrl.dispose();
    _chatScrollCtrl.dispose();
    for (final p in _pages) {
      p.dispose();
    }
    super.dispose();
  }

  bool get _hasContent =>
      _contentCtrl.text.trim().isNotEmpty ||
      _pages.any((p) => !p.isEmpty);

  void _goToPage(int i) {
    if (i < 0 || i >= _pages.length) return;
    final from = _ink;
    setState(() {
      _page = i;
      _ink
        ..color = from.color
        ..width = from.width
        ..stylusOnly = from.stylusOnly
        ..stylusDetected = from.stylusDetected
        ..bgColor = from.bgColor;
    });
  }

  void _addPage() {
    if (_pages.length >= kMaxInkPages) return;
    final from = _ink;
    setState(() {
      final page = DrawingCanvasController()
        ..color = from.color
        ..width = from.width
        ..stylusOnly = from.stylusOnly
        ..stylusDetected = from.stylusDetected
        ..bgColor = from.bgColor
        ..onStylusStateChanged = _saveStylusPrefs;
      _pages.add(page);
      _page = _pages.length - 1;
    });
  }

  Future<void> _confirmClearText(AppLocalizations l10n) async {
    if (_contentCtrl.text.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteConfirmTitle),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: Text(l10n.clearText),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      _contentCtrl.clear();
      setState(() {});
    }
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

    if (_isAiChat) {
      int noteId;
      if (widget.editNote != null) {
        final updated = widget.editNote!.copyWith(
          type: NoteType.text,
          title: title,
          content: content,
          isAiChat: true,
          updatedAt: now,
        );
        await DbService.instance.update(updated);
        noteId = updated.id!;
      } else {
        noteId = await DbService.instance.insert(Note(
          type: NoteType.text,
          title: title,
          content: content,
          isAiChat: true,
          createdAt: now,
          updatedAt: now,
        ));
      }
      if (content.isNotEmpty) {
        unawaited(_enrichText(noteId, content, langName));
      }
      if (!mounted) return;
      Navigator.pop(context, noteId);
      return;
    }

    final canvasBg = _pages[0].bgColor;

    String? mediaPath;
    NoteType type;

    final hasInk = _pages.any((p) => !p.isEmpty);
    if (hasInk) {
      final bytes = await renderPagesToPng(_pages);
      if (bytes != null) {
        mediaPath = await MediaService.instance.savePngBytes(bytes);
      } else {
        debugPrint('[EDITOR] renderPagesToPng returned null');
      }
      type = content.isEmpty ? NoteType.handwriting : NoteType.text;
    } else {
      type = NoteType.text;
    }

    // If editing and we have a ghost + new ink, composite them.
    if (widget.editNote != null &&
        _ghostImage != null &&
        mediaPath != null) {
      final ghost = _ghostImage!;
      final intermediate = mediaPath;
      final drawnPages =
          _pages.where((p) => !p.isEmpty && p.renderSize != null).toList();
      double pw = 0, ph = 0;
      for (final p in drawnPages) {
        if (p.renderSize!.width > pw) pw = p.renderSize!.width;
        ph += p.renderSize!.height;
      }
      final w = ghost.width.toDouble() > pw ? ghost.width.toDouble() : pw;
      final h = ghost.height.toDouble() > ph ? ghost.height.toDouble() : ph;
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawRect(
          Rect.fromLTWH(0, 0, w, h), Paint()..color = canvasBg);
      canvas.drawImage(ghost, Offset.zero, Paint());
      if (drawnPages.any((p) => p.mathAnnotations.isNotEmpty)) {
      }
      double yOff = 0;
      for (final p in drawnPages) {
        canvas.save();
        canvas.translate(0, yOff);
        DrawPainter.paintStrokes(canvas, p.strokes);
        DrawPainter.paintAnnotations(canvas, p.mathAnnotations);
        canvas.restore();
        yOff += p.renderSize!.height;
      }
      final pic = recorder.endRecording();
      final composed = await pic.toImage(w.toInt(), h.toInt());
      final bd = await composed.toByteData(format: ui.ImageByteFormat.png);
      if (bd != null) {
        mediaPath = await MediaService.instance
            .savePngBytes(bd.buffer.asUint8List());
        await MediaService.instance.deleteMedia(widget.editNote!.mediaPath);
        await MediaService.instance.deleteMedia(intermediate);
      }
    }

    int noteId;
    if (widget.editNote != null) {
      final updated = widget.editNote!.copyWith(
        type: type,
        title: title,
        content: content,
        mediaPath: mediaPath,
        canvasBg: canvasBg,
        updatedAt: now,
      );
      await DbService.instance.update(updated);
      noteId = updated.id!;
    } else {
      noteId = await DbService.instance.insert(Note(
        type: type,
        title: title,
        content: content,
        mediaPath: mediaPath,
        canvasBg: canvasBg,
        createdAt: now,
        updatedAt: now,
      ));
    }

    if (mediaPath != null) {
      unawaited(_enrichImage(noteId, mediaPath, langName));
    } else if (content.isNotEmpty) {
      unawaited(_enrichText(noteId, content, langName));
    }

    if (!mounted) return;
    Navigator.pop(context, noteId);
  }

  Future<void> _enrichImage(int noteId, String path, String lang) async {
    final local = await LocalAnalysisService.instance.analyzeImage(path);
    var note = await DbService.instance.getById(noteId);
    if (note == null) return;
    await DbService.instance.update(note.copyWith(
      ocrText: local.ocrText,
      category: local.category,
      tags: local.tags,
      updatedAt: DateTime.now(),
    ));
    if (kCloudAiEnabled) {
      final cloud = await CloudAiService.instance.analyzeImage(path, lang);
      if (cloud == null) return;
      note = await DbService.instance.getById(noteId);
      if (note == null) return;
      await DbService.instance.update(note.copyWith(
        category: cloud.category.isNotEmpty ? cloud.category : note.category,
        tags: cloud.tags.isNotEmpty ? cloud.tags : note.tags,
        updatedAt: DateTime.now(),
      ));
      if (cloud.category.isNotEmpty && cloud.category != 'other' && !note.categoryLocked) {
        final learnText = '${note.content} ${note.ocrText}'.trim();
        if (learnText.isNotEmpty) {
          await EvaService.instance.train(learnText, cloud.category);
        }
      }
    }
  }

  Future<void> _enrichText(int noteId, String text, String lang) async {
    final local = await LocalAnalysisService.instance.classifyText(text);
    var note = await DbService.instance.getById(noteId);
    if (note == null) return;
    await DbService.instance.update(note.copyWith(
      category: local.category,
      tags: local.tags,
      updatedAt: DateTime.now(),
    ));
    if (kCloudAiEnabled) {
      final cloud = await CloudAiService.instance.analyzeText(text, lang);
      if (cloud == null) return;
      note = await DbService.instance.getById(noteId);
      if (note == null) return;
      await DbService.instance.update(note.copyWith(
        category: cloud.category.isNotEmpty ? cloud.category : note.category,
        tags: cloud.tags.isNotEmpty ? cloud.tags : note.tags,
        updatedAt: DateTime.now(),
      ));
      if (cloud.category.isNotEmpty && cloud.category != 'other' && !note.categoryLocked) {
        await EvaService.instance.train(text, cloud.category);
      }
    }
  }

  // ── Handwriting Math Recognition ─────────────────────────────────────────

  Future<void> _runTextRecognition() async {
    if (_textLoading) return;
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    final strokes = List<DrawingStroke>.from(_ink.strokes);
    if (strokes.isEmpty) {
      messenger.showSnackBar(SnackBar(
        content: Text(l10n.inkNoStrokes),
        duration: const Duration(seconds: 3),
      ));
      return;
    }
    const lang = 'el';
    final ready = await InkTextService.instance.isModelReady(lang);
    if (!mounted) return;
    if (!ready) {
      messenger.showSnackBar(SnackBar(
        content: Row(children: [
          const SizedBox(
            width: 18, height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(l10n.inkModelGreekDownloading)),
        ]),
        duration: const Duration(seconds: 60),
      ));
    }
    setState(() => _textLoading = true);
    final modelError = await InkTextService.instance.ensureModel(lang);
    if (!mounted) return;
    if (!ready) messenger.hideCurrentSnackBar();
    if (modelError != null) {
      setState(() => _textLoading = false);
      messenger.showSnackBar(SnackBar(content: Text(modelError)));
      return;
    }
    final canvasSize = _ink.lastLayoutSize ?? const Size(400, 300);
    final candidates = await InkTextService.instance
        .recognizeCandidates(strokes, canvasSize, lang: lang);
    if (!mounted) return;
    setState(() => _textLoading = false);
    if (candidates.isEmpty) {
      messenger.showSnackBar(SnackBar(
        content: Text(l10n.inkTextNotRecognized),
        duration: const Duration(seconds: 3),
      ));
      return;
    }
    if (!mounted) return;
    final chosen = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) {
        final sl = AppLocalizations.of(ctx);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Text(sl.inkChooseText,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              for (final cand in candidates)
                ListTile(
                  leading: const Icon(Icons.text_fields),
                  title: Text(cand),
                  onTap: () => Navigator.pop(ctx, cand),
                ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.close),
                title: Text(sl.cancel),
                onTap: () => Navigator.pop(ctx),
              ),
            ],
          ),
        );
      },
    );
    if (chosen == null || !mounted) return;
    final existing = _contentCtrl.text;
    _contentCtrl.text =
        existing.isEmpty ? chosen : '$existing\n$chosen';
    setState(() {});
  }

  Future<void> _runMathRecognition() async {
    if (_mathLoading) return;
    // Capture context-dependent objects before any await.
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    final strokes = List<DrawingStroke>.from(_ink.strokes);
    if (strokes.isEmpty) {
      messenger.showSnackBar(SnackBar(
        content: Text(l10n.inkNoStrokes),
        duration: const Duration(seconds: 3),
      ));
      return;
    }

    final modelReady = await InkMathService.instance.isModelReady();
    if (!mounted) return;

    if (!modelReady) {
      messenger.showSnackBar(SnackBar(
        content: Row(children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(l10n.inkMathModelDownloading)),
        ]),
        duration: const Duration(seconds: 90),
      ));
    }

    setState(() => _mathLoading = true);
    final modelError = await InkMathService.instance.ensureModel();
    if (!modelReady) messenger.hideCurrentSnackBar();

    if (!mounted) return;
    if (modelError != null) {
      setState(() => _mathLoading = false);
      messenger.showSnackBar(SnackBar(content: Text(modelError)));
      return;
    }

    final canvasSize = _ink.lastLayoutSize ?? const Size(400, 300);
    final recognized = await InkMathService.instance.recognize(strokes, canvasSize);

    if (!mounted) return;
    setState(() => _mathLoading = false);

    if (recognized == null || recognized.trim().isEmpty) {
      messenger.showSnackBar(SnackBar(
        content: Text(l10n.inkMathNotRecognized),
        duration: const Duration(seconds: 4),
      ));
      return;
    }

    final result = await InkMathService.instance.evaluate(recognized);
    if (!mounted) return;

    if (result == null) {
      messenger.showSnackBar(SnackBar(
        content: Text(l10n.inkMathNoExpression(recognized)),
        duration: const Duration(seconds: 4),
      ));
      return;
    }

    final resultStr = (result == result.truncateToDouble() && result.abs() < 1e15)
        ? result.truncate().toString()
        : result.toStringAsFixed(6).replaceAll(RegExp(r'\.?0+$'), '');

    // Compute annotation placement from the bounding box of the recognized strokes.
    double bMinX = 0, bMaxX = 0, bMinY = 0, bMaxY = 0;
    bool bFirst = true;
    for (final stroke in strokes) {
      for (final p in stroke.points) {
        if (bFirst) {
          bMinX = bMaxX = p.dx;
          bMinY = bMaxY = p.dy;
          bFirst = false;
        } else {
          if (p.dx < bMinX) bMinX = p.dx;
          if (p.dx > bMaxX) bMaxX = p.dx;
          if (p.dy < bMinY) bMinY = p.dy;
          if (p.dy > bMaxY) bMaxY = p.dy;
        }
      }
    }
    if (bFirst) {
      bMinX = 0; bMaxX = 100; bMinY = 0; bMaxY = 50;
    }
    final exprH = (bMaxY - bMinY).clamp(24.0, 80.0);
    final annX = (bMaxX + 14.0).clamp(0.0, canvasSize.width - 80.0);
    final annY = (bMinY + (bMaxY - bMinY) * 0.25)
        .clamp(0.0, canvasSize.height - exprH);

    _ink.addMathAnnotation(MathAnnotation(
      text: '= $resultStr',
      position: Offset(annX, annY),
      fontSize: exprH,
      color: _ink.color,
    ));

    messenger.showSnackBar(SnackBar(
      content: Text('= $resultStr'),
      duration: const Duration(seconds: 6),
      action: SnackBarAction(
        label: l10n.inkInsertInText,
        onPressed: () => _insertMathResult(recognized, resultStr),
      ),
    ));
  }

  void _insertMathResult(String expression, String result) {
    final existing = _contentCtrl.text;
    final line = '$expression = $result';
    _contentCtrl.text =
        existing.isEmpty ? line : '${existing.trimRight()}\n$line';
    setState(() {});
  }

  // ── AI Chat ──────────────────────────────────────────────────────────────

  List<({bool isUser, String text})> _parseTurns(String content) {
    final result = <({bool isUser, String text})>[];
    // Σπάμε στους markers [USER] / [AI], ΟΧΙ σε διπλό newline,
    // ώστε οι πολυγραμμικές απαντήσεις (συνταγές κλπ) να μένουν ακέραιες.
    final pattern = RegExp(r'\[(USER|AI)\]\s', multiLine: true);
    final matches = pattern.allMatches(content).toList();
    for (var i = 0; i < matches.length; i++) {
      final m = matches[i];
      final isUser = m.group(1) == 'USER';
      final start = m.end;
      final end = (i + 1 < matches.length) ? matches[i + 1].start : content.length;
      final text = content.substring(start, end).trim();
      if (text.isNotEmpty) {
        result.add((isUser: isUser, text: text));
      }
    }
    return result;
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScrollCtrl.hasClients) {
        _chatScrollCtrl.animateTo(
          _chatScrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendChatMessage() async {
    final text = _chatInputCtrl.text.trim();
    if (text.isEmpty || _aiChatLoading) return;
    _chatInputCtrl.clear();

    final existing = _contentCtrl.text;
    final userLine = '[USER] $text';
    _contentCtrl.text =
        existing.isEmpty ? userLine : '$existing\n\n$userLine';
    setState(() => _aiChatLoading = true);
    _scrollToBottom();

    final prompt =
        'You are a helpful AI assistant embedded in a note-taking app. '
        'Answer the user\'s questions clearly and concisely.\n\n'
        'Conversation so far:\n${_contentCtrl.text}\n\n'
        'Reply to the last [USER] message. '
        'Do not include a "[AI] " prefix in your reply.';

    final reply =
        await CloudAiService.instance.complete(prompt, maxTokens: 1500);
    if (!mounted) return;

    final errMsg = CloudAiService.instance.lastError;
    final aiLine = '[AI] ${reply?.trim() ?? (errMsg != null ? 'Σφάλμα: ' + errMsg : '(No response)')}';
    _contentCtrl.text = '${_contentCtrl.text}\n\n$aiLine';
    setState(() => _aiChatLoading = false);
    _scrollToBottom();
  }

  Widget _buildChatBubble(({bool isUser, String text}) turn) {
    final cs = Theme.of(context).colorScheme;
    return Align(
      alignment: turn.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color:
              turn.isUser ? cs.primary : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(turn.isUser ? 16 : 4),
            bottomRight: Radius.circular(turn.isUser ? 4 : 16),
          ),
        ),
        child: Text(
          turn.text,
          style: TextStyle(
            color: turn.isUser ? cs.onPrimary : cs.onSurface,
            fontSize: 15,
            height: 1.4,
          ),
        ),
      ),
    );
  }

  Widget _buildChatBody(BuildContext context) {
    final turns = _parseTurns(_contentCtrl.text);
    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _chatScrollCtrl,
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            itemCount: turns.length,
            itemBuilder: (_, i) => _buildChatBubble(turns[i]),
          ),
        ),
        if (_aiChatLoading) const LinearProgressIndicator(),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _chatInputCtrl,
                    enabled: !_aiChatLoading,
                    decoration: InputDecoration(
                      hintText: '\u03a1\u03ce\u03c4\u03b7\u03c3\u03b5 \u03ba\u03ac\u03c4\u03b9\u2026',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                    ),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendChatMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _aiChatLoading ? null : _sendChatMessage,
                  icon: const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _showTitleDialog(BuildContext context) async {
    final tmp = TextEditingController(text: _titleCtrl.text);
    final l10n = AppLocalizations.of(context);
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.titleLabel),
        content: TextField(
          controller: tmp,
          autofocus: true,
          decoration: InputDecoration(
            hintText: l10n.titleLabel,
            border: const OutlineInputBorder(),
          ),
          onSubmitted: (_) => Navigator.pop(ctx),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Άκυρο'),
          ),
          FilledButton(
            onPressed: () {
              setState(() => _titleCtrl.text = tmp.text);
              Navigator.pop(ctx);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
    tmp.dispose();
  }

  Widget _paneHeader({
    required IconData icon,
    required String label,
    required Color bg,
    required Color fg,
    List<Widget> actions = const [],
  }) {
    return Container(
      height: 34,
      color: bg,
      child: Row(
        children: [
          const SizedBox(width: 12),
          Icon(icon, size: 15, color: fg),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.6,
                  color: fg)),
          const Spacer(),
          ...actions,
        ],
      ),
    );
  }

  Future<void> _onAiButtonPressed() async {
    final selection = _contentCtrl.selection;
    final hasSelection = selection.isValid && !selection.isCollapsed;
    final sourceText = hasSelection
        ? selection.textInside(_contentCtrl.text)
        : _contentCtrl.text;

    final result = await AiActionMenu.show(
      context: context,
      text: sourceText,
    );
    if (result == null || !mounted) return;

    setState(() {
      if (hasSelection) {
        final selStart = selection.start;
        final selEnd = selection.end;
        final original = _contentCtrl.text;
        switch (result.action) {
          case AiPreviewAction.replace:
            final newText = original.substring(0, selStart) +
                result.text +
                original.substring(selEnd);
            _contentCtrl.text = newText;
            _contentCtrl.selection = TextSelection.collapsed(
              offset: selStart + result.text.length,
            );
            break;
          case AiPreviewAction.append:
            final newText = original.substring(0, selEnd) +
                '\n\n' +
                result.text +
                original.substring(selEnd);
            _contentCtrl.text = newText;
            _contentCtrl.selection = TextSelection.collapsed(
              offset: selEnd + 2 + result.text.length,
            );
            break;
        }
      } else {
        switch (result.action) {
          case AiPreviewAction.replace:
            _contentCtrl.text = result.text;
            _contentCtrl.selection = TextSelection.collapsed(
              offset: result.text.length,
            );
            break;
          case AiPreviewAction.append:
            final separator = _contentCtrl.text.isEmpty ? '' : '\n\n';
            _contentCtrl.text =
                _contentCtrl.text + separator + result.text;
            _contentCtrl.selection = TextSelection.collapsed(
              offset: _contentCtrl.text.length,
            );
            break;
        }
      }
    });
  }
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final atLast = _page == _pages.length - 1;
    final canAdd = atLast && _pages.length < kMaxInkPages && !_ink.isEmpty;

    return Scaffold(
      resizeToAvoidBottomInset: true,
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
          IconButton(
            icon: Icon(
              _paneMode == 1 ? Icons.gesture : Icons.keyboard_alt_outlined,
              size: 22,
            ),
            tooltip: _paneMode == 1 ? l10n.drawNote : l10n.textNote,
            onPressed: () {
              setState(() => _paneMode = _paneMode == 1 ? 2 : 1);
              _savePaneMode();
            },
          ),
          ListenableBuilder(
            listenable: PremiumService.instance,
            builder: (context, _) {
              final isPremium = PremiumService.instance.isPremium;
              return LockedWrapper(
                locked: !isPremium,
                onLockedTap: () => showPaywall(context),
                child: PopupMenuButton<int>(
                  tooltip: 'AI',
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.auto_awesome,
                            size: 20,
                            color: _isAiChat ? cs.primary : null),
                        const SizedBox(width: 4),
                        Text('AI',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: _isAiChat ? cs.primary : null)),
                      ],
                    ),
                  ),
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 0,
                      child: Row(children: [
                        Icon(Icons.forum_outlined, size: 20),
                        SizedBox(width: 12),
                        Text('\u03a1\u03ce\u03c4\u03b7\u03c3\u03b5 \u03c4\u03bf\u03bd AI'),
                      ]),
                    ),
                    const PopupMenuItem(
                      value: 1,
                      child: Row(children: [
                        Icon(Icons.auto_fix_high, size: 20),
                        SizedBox(width: 12),
                        Text('AI \u0395\u03c1\u03b3\u03b1\u03bb\u03b5\u03af\u03b1'),
                      ]),
                    ),
                    if (widget.editNote?.mediaPath != null)
                      const PopupMenuItem(
                        value: 2,
                        child: Row(children: [
                          Icon(Icons.image_search, size: 20),
                          SizedBox(width: 12),
                          Text('\u03a0\u03b5\u03c1\u03af\u03b3\u03c1\u03b1\u03c8\u03b5 \u03c4\u03b7\u03bd \u03b5\u03b9\u03ba\u03cc\u03bd\u03b1'),
                        ]),
                      ),
                  ],
                  onSelected: (v) {
                    if (v == 0) {
                      setState(() { _isAiChat = !_isAiChat; if (_isAiChat) _paneMode = 1; });
                    } else if (v == 1) {
                      _onAiButtonPressed();
                    } else if (v == 2) {
                      _describeImageWithAi();
                    }
                  },
                ),
              );
            },
          ),
          AnimatedBuilder(
            animation: Listenable.merge(_pages),
            builder: (_, _) => TextButton(
              onPressed: _hasContent ? () => _save(l10n) : null,
              child: Text(l10n.save),
            ),
          ),
        ],
      ),
      floatingActionButton: null,
      body: SafeArea(
        child: _isAiChat
            ? _buildChatBody(context)
            : Column(
              children: [
                // ── Text pane: text-only mode (1) ─────────────────────
                if (_paneMode == 1)
                  Expanded(
                    child: Container(
                      color: Colors.white,
                      child: Column(
                        children: [
                          _paneHeader(
                            icon: Icons.keyboard_alt_outlined,
                            label: l10n.textNote.toUpperCase(),
                            bg: cs.secondaryContainer,
                            fg: cs.onSecondaryContainer,
                            actions: [
                              IconButton(
                                icon: const Icon(Icons.backspace_outlined,
                                    size: 17),
                                tooltip: l10n.clearText,
                                visualDensity: VisualDensity.compact,
                                onPressed: () => _confirmClearText(l10n),
                              ),
                            ],
                          ),
                          Expanded(
                            child: Stack(
                              children: [
                                const Positioned.fill(
                                  child: CustomPaint(
                                    painter: _TextNotebookPainter(),
                                  ),
                                ),
                                Scrollbar(
                                  controller: _textScroll,
                                  thumbVisibility: true,
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                        16, 4, 16, 8),
                                    child: TextField(
                                      controller: _contentCtrl,
                                      focusNode: _contentFocus,
                                      scrollController: _textScroll,
                                      maxLines: null,
                                      expands: true,
                                      decoration: InputDecoration(
                                        hintText: l10n.noteHint,
                                        hintStyle: TextStyle(
                                            color: Colors.grey.shade400),
                                        border: InputBorder.none,
                                      ),
                                      style: const TextStyle(
                                        fontFamily: 'monospace',
                                        fontSize: 20,
                                        height: 1.5,
                                        color: Colors.black87,
                                      ),
                                      onChanged: (_) => setState(() {}),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                // ── Ink pane: drawing-only mode (2) ───────────────────
                if (_paneMode == 2)
                  Expanded(
                    child: AnimatedBuilder(
                      animation: Listenable.merge(_pages),
                      builder: (_, _) => Container(
                        color: _ink.bgColor,
                        child: Column(
                          children: [
                            _paneHeader(
                              icon: Icons.gesture,
                              label: l10n.drawNote.toUpperCase(),
                              bg: cs.tertiaryContainer,
                              fg: cs.onTertiaryContainer,
                              actions: [
                                IconButton(
                                  icon: const Icon(Icons.title, size: 20),
                                  visualDensity: VisualDensity.compact,
                                  tooltip: l10n.titleLabel,
                                  onPressed: () => _showTitleDialog(context),
                                ),
                                if (_mathLoading || _textLoading)
                                  const SizedBox(
                                    width: 32,
                                    height: 32,
                                    child: Padding(
                                      padding: EdgeInsets.all(8),
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    ),
                                  )
                                else
                                  PopupMenuButton<String>(
                                    icon: const Icon(Icons.auto_fix_high,
                                        size: 18),
                                    tooltip: l10n.inkRecognize,
                                    enabled: !_ink.isEmpty,
                                    onSelected: (v) {
                                      if (v == 'math') _runMathRecognition();
                                      if (v == 'text') _runTextRecognition();
                                    },
                                    itemBuilder: (ctx) => [
                                      PopupMenuItem(
                                        value: 'math',
                                        child: Row(children: [
                                          const Icon(Icons.functions, size: 18),
                                          const SizedBox(width: 10),
                                          Text(l10n.inkMathAction),
                                        ]),
                                      ),
                                      PopupMenuItem(
                                        value: 'text',
                                        child: Row(children: [
                                          const Icon(Icons.text_fields, size: 18),
                                          const SizedBox(width: 10),
                                          Text(l10n.inkTextAction),
                                        ]),
                                      ),
                                    ],
                                  ),
                                IconButton(
                                  icon: const Icon(Icons.chevron_left, size: 20),
                                  visualDensity: VisualDensity.compact,
                                  onPressed: _page > 0
                                      ? () => _goToPage(_page - 1)
                                      : null,
                                ),
                                Text('${_page + 1}/${_pages.length}',
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: cs.onTertiaryContainer)),
                                IconButton(
                                  icon: Icon(
                                      atLast
                                          ? Icons.add
                                          : Icons.chevron_right,
                                      size: 20),
                                  visualDensity: VisualDensity.compact,
                                  onPressed: atLast
                                      ? (canAdd ? _addPage : null)
                                      : () => _goToPage(_page + 1),
                                ),
                              ],
                            ),
                            Expanded(
                              child: Stack(
                                children: [
                                  Positioned.fill(
                                    child: CustomPaint(
                                      painter: _NotebookPainter(
                                          bgColor: _ink.bgColor),
                                    ),
                                  ),
                                  if (_ghostImage != null)
                                    Positioned.fill(
                                      child: Opacity(
                                        opacity: 0.3,
                                        child: RawImage(
                                            image: _ghostImage,
                                            fit: BoxFit.fill),
                                      ),
                                    ),
                                  Positioned.fill(
                                    child: Listener(
                                      onPointerDown: (_) =>
                                          _contentFocus.unfocus(),
                                      child: DrawingSurface(controller: _ink),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                if (_paneMode == 2) DrawingToolbar(controller: _ink),
              ],
            ),
      ),
    );
  }

  Future<void> _describeImageWithAi() async {
    final path = widget.editNote?.mediaPath;
    if (path == null) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(
        content: Text('\u0391\u03bd\u03ac\u03bb\u03c5\u03c3\u03b7 \u03b5\u03b9\u03ba\u03cc\u03bd\u03b1\u03c2\u2026'),
        duration: Duration(seconds: 4),
      ),
    );
    final langName = Localizations.localeOf(context).languageCode == 'el'
        ? 'Greek'
        : 'English';
    final result = await CloudAiService.instance.analyzeImage(path, langName);
    if (!mounted) return;
    final desc = result?.description.trim() ?? '';
    if (desc.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('\u0397 AI \u03b4\u03b5\u03bd \u03b5\u03c0\u03ad\u03c3\u03c4\u03c1\u03b5\u03c8\u03b5 \u03c0\u03b5\u03c1\u03b9\u03b3\u03c1\u03b1\u03c6\u03ae.'),
        ),
      );
      return;
    }
    final existing = _contentCtrl.text.trim();
    final newText = existing.isEmpty ? desc : '$existing\n\n$desc';
    setState(() {
      _contentCtrl.text = newText;
      _contentCtrl.selection = TextSelection.fromPosition(
        TextPosition(offset: newText.length),
      );
    });
  }
}