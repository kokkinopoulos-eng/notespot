import 'dart:async';
import 'dart:io' as dart_io;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';
import '../../models/note.dart';
import '../../services/cloud_ai_service.dart';
import '../../services/db_service.dart';
import '../../services/media_service.dart';
import '../../widgets/drawing_canvas.dart';

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
  double _split = 0.5;
  ui.Image? _ghostImage;

  DrawingCanvasController get _ink => _pages[_page];

  @override
  void initState() {
    super.initState();
    _loadEditNote();
  }

  Future<void> _loadEditNote() async {
    final note = widget.editNote;
    if (note == null) return;
    _titleCtrl.text = note.title;
    _contentCtrl.text = note.content;
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
        ..bgColor = from.bgColor;
    });
  }

  void _addPage() {
    if (_pages.length >= kMaxInkPages) return;
    final from = _ink;
    setState(() {
      _pages.add(DrawingCanvasController()
        ..color = from.color
        ..width = from.width
        ..stylusOnly = from.stylusOnly
        ..bgColor = from.bgColor);
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
      double yOff = 0;
      for (final p in drawnPages) {
        canvas.save();
        canvas.translate(0, yOff);
        DrawPainter.paintStrokes(canvas, p.strokes);
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
    Navigator.pop(context, true);
  }

  Future<void> _enrichImage(int noteId, String path, String lang) async {
    final analysis = await CloudAiService.instance.analyzeImage(path, lang);
    if (analysis == null) return;
    final note = await DbService.instance.getById(noteId);
    if (note == null) return;
    await DbService.instance.update(note.copyWith(
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

  Widget _divider(BuildContext context, double totalHeight) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragUpdate: (d) {
        if (totalHeight <= 0) return;
        setState(() {
          _split = (_split + d.delta.dy / totalHeight).clamp(0.2, 0.8);
        });
      },
      child: Container(
        height: 22,
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          border: Border.symmetric(
            horizontal: BorderSide(color: cs.outlineVariant, width: 0.6),
          ),
        ),
        child: Center(
          child: Container(
            width: 48,
            height: 5,
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final textFlex = (_split * 1000).round();
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
          AnimatedBuilder(
            animation: Listenable.merge(_pages),
            builder: (_, _) => TextButton(
              onPressed: _hasContent ? () => _save(l10n) : null,
              child: Text(l10n.save),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => Column(
            children: [
              // ================= Text pane =================
              Expanded(
                flex: textFlex,
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
                                padding:
                                    const EdgeInsets.fromLTRB(16, 4, 16, 8),
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
              // ================= Divider handle =================
              _divider(context, constraints.maxHeight),
              // ================= Ink pane =================
              Expanded(
                flex: 1000 - textFlex,
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
                                  atLast ? Icons.add : Icons.chevron_right,
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
                                  painter:
                                      _NotebookPainter(bgColor: _ink.bgColor),
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
              DrawingToolbar(controller: _ink),
            ],
          ),
        ),
      ),
    );
  }
}
