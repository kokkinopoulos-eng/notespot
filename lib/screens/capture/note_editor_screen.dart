import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';
import '../../models/note.dart';
import '../../services/cloud_ai_service.dart';
import '../../services/db_service.dart';
import '../../services/media_service.dart';
import '../../widgets/drawing_canvas.dart';

const int kMaxInkPages = 5;

class _NotebookPainter extends CustomPainter {
  const _NotebookPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = const Color(0xFFB7D3E8)
      ..strokeWidth = 1;
    const step = 30.0;
    for (double y = step; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
    }
    final margin = Paint()
      ..color = const Color(0xFFE8A0A0)
      ..strokeWidth = 1.2;
    canvas.drawLine(
        const Offset(42, 0), Offset(42, size.height), margin);
  }

  @override
  bool shouldRepaint(_NotebookPainter old) => false;
}

class NoteEditorScreen extends StatefulWidget {
  const NoteEditorScreen({super.key});

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

  DrawingCanvasController get _ink => _pages[_page];

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
      // keep pen settings consistent across pages
      _ink
        ..color = from.color
        ..width = from.width
        ..stylusOnly = from.stylusOnly;
    });
  }

  void _addPage() {
    if (_pages.length >= kMaxInkPages) return;
    final from = _ink;
    setState(() {
      _pages.add(DrawingCanvasController()
        ..color = from.color
        ..width = from.width
        ..stylusOnly = from.stylusOnly);
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

    final noteId = await DbService.instance.insert(Note(
      type: type,
      title: title,
      content: content,
      mediaPath: mediaPath,
      createdAt: now,
      updatedAt: now,
    ));

    if (mediaPath != null) {
      unawaited(_enrichImage(noteId, mediaPath, langName));
    } else if (content.isNotEmpty) {
      unawaited(_enrichText(noteId, content, langName));
    }

    if (!mounted) return;
    Navigator.pop(context, true);
  }

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
            builder: (_, __) => TextButton(
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
                        child: Scrollbar(
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
                                hintStyle:
                                    TextStyle(color: Colors.grey.shade400),
                                border: InputBorder.none,
                              ),
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 15,
                                height: 1.5,
                                color: Colors.black87,
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // ================= Divider handle =================
              _divider(context, constraints.maxHeight),
              // ================= Ink pane: fixed page, no scrolling =====
              Expanded(
                flex: 1000 - textFlex,
                child: Container(
                  color: Colors.white,
                  child: Column(
                    children: [
                      AnimatedBuilder(
                        animation: Listenable.merge(_pages),
                        builder: (_, __) => _paneHeader(
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
                      ),
                      Expanded(
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: CustomPaint(
                                painter:
                                    _NotebookPainter(),
                              ),
                            ),
                            Positioned.fill(
                              child: Listener(
                                onPointerDown: (_) =>
                                    _contentFocus.unfocus(),
                                child:
                                    DrawingSurface(controller: _ink),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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