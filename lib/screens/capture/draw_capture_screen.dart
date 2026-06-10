import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../l10n/app_localizations.dart';
import '../../models/note.dart';
import '../../services/cloud_ai_service.dart';
import '../../services/db_service.dart';
import '../../services/media_service.dart';

class _Stroke {
  _Stroke({required this.color, required this.width});
  final Color color;
  final double width;
  final List<Offset> points = [];
}

class _DrawPainter extends CustomPainter {
  const _DrawPainter(this.strokes, this.current);
  final List<_Stroke> strokes;
  final _Stroke? current;

  static void paintStrokes(Canvas canvas, List<_Stroke> strokes) {
    for (final stroke in strokes) {
      if (stroke.points.isEmpty) continue;
      final paint = Paint()
        ..color = stroke.color
        ..strokeWidth = stroke.width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;
      final path = Path()..moveTo(stroke.points[0].dx, stroke.points[0].dy);
      for (int i = 1; i < stroke.points.length; i++) {
        path.lineTo(stroke.points[i].dx, stroke.points[i].dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final all = [...strokes, if (current != null) current!];
    paintStrokes(canvas, all);
  }

  @override
  bool shouldRepaint(_DrawPainter old) => true;
}

class DrawCaptureScreen extends StatefulWidget {
  const DrawCaptureScreen({super.key});

  @override
  State<DrawCaptureScreen> createState() => _DrawCaptureScreenState();
}

class _DrawCaptureScreenState extends State<DrawCaptureScreen> {
  final _canvasKey = GlobalKey();
  final List<_Stroke> _strokes = [];
  _Stroke? _current;
  Color _color = Colors.black;
  double _width = 3.0;
  bool _stylusOnly = false;

  static const _colors = [
    Colors.black,
    Color(0xFF1565C0),
    Color(0xFFC62828),
    Color(0xFF2E7D32),
  ];
  static const _widths = [2.0, 4.0, 8.0];

  void _onPointerDown(PointerDownEvent e) {
    if (_stylusOnly && e.kind != PointerDeviceKind.stylus) return;
    setState(() {
      _current = _Stroke(color: _color, width: _width)
        ..points.add(e.localPosition);
    });
  }

  void _onPointerMove(PointerMoveEvent e) {
    if (_current == null) return;
    if (_stylusOnly && e.kind != PointerDeviceKind.stylus) return;
    setState(() => _current!.points.add(e.localPosition));
  }

  void _onPointerUp(PointerUpEvent e) {
    if (_current == null) return;
    setState(() {
      _strokes.add(_current!);
      _current = null;
    });
  }

  Future<void> _save(AppLocalizations l10n) async {
    final box =
        _canvasKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final size = box.size;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = Colors.white,
    );
    _DrawPainter.paintStrokes(canvas, _strokes);
    final picture = recorder.endRecording();
    final img =
        await picture.toImage(size.width.toInt(), size.height.toInt());
    final byteData =
        await img.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null || !mounted) return;
    final bytes = byteData.buffer.asUint8List();
    final path = await MediaService.instance.savePngBytes(bytes);
    final now = DateTime.now();
    final stamp = DateFormat('d/M HH:mm').format(now);
    final langName =
        Localizations.localeOf(context).languageCode == 'el' ? 'Greek' : 'English';
    final noteId = await DbService.instance.insert(Note(
      type: NoteType.handwriting,
      title: '${l10n.drawNote} $stamp',
      mediaPath: path,
      createdAt: now,
      updatedAt: now,
    ));
    unawaited(_enrich(noteId, path, langName));
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  Future<void> _enrich(int noteId, String imagePath, String langName) async {
    final analysis =
        await CloudAiService.instance.analyzeImage(imagePath, langName);
    if (analysis == null) return;
    final note = await DbService.instance.getById(noteId);
    if (note == null) return;
    final updated = Note(
      id: note.id,
      type: note.type,
      title: note.title,
      content: analysis.extractedText.isNotEmpty
          ? analysis.extractedText
          : note.content,
      category: analysis.category,
      tags: analysis.tags,
      mediaPath: note.mediaPath,
      createdAt: note.createdAt,
      updatedAt: DateTime.now(),
    );
    await DbService.instance.update(updated);
  }

  Future<void> _confirmClear(AppLocalizations l10n) async {
    if (_strokes.isEmpty) return;
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
            child: Text(l10n.clearAll),
          ),
        ],
      ),
    );
    if (confirmed == true) setState(() => _strokes.clear());
  }

  Widget _colorSwatch(Color c) {
    final active = _color.value == c.value;
    return GestureDetector(
      onTap: () => setState(() => _color = c),
      child: Container(
        width: 28,
        height: 28,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: c,
          shape: BoxShape.circle,
          border: Border.all(
            color: active
                ? Theme.of(context).colorScheme.primary
                : Colors.transparent,
            width: 3,
          ),
        ),
      ),
    );
  }

  Widget _widthBtn(double w) {
    final active = _width == w;
    return GestureDetector(
      onTap: () => setState(() => _width = w),
      child: Container(
        width: w + 12,
        height: w + 12,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: active ? _color : Colors.grey,
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.drawNote),
        actions: [
          TextButton(
            onPressed: _strokes.isEmpty ? null : () => _save(l10n),
            child: Text(l10n.save),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              color: Colors.white,
              child: Listener(
                onPointerDown: _onPointerDown,
                onPointerMove: _onPointerMove,
                onPointerUp: _onPointerUp,
                child: CustomPaint(
                  key: _canvasKey,
                  painter: _DrawPainter(_strokes, _current),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Container(
              color: Theme.of(context).colorScheme.surface,
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Colors
                  Row(children: _colors.map(_colorSwatch).toList()),
                  // Widths
                  Row(children: _widths.map(_widthBtn).toList()),
                  // Actions
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.undo),
                        tooltip: l10n.undo,
                        onPressed: _strokes.isEmpty
                            ? null
                            : () => setState(() => _strokes.removeLast()),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_sweep),
                        tooltip: l10n.clearAll,
                        onPressed: () => _confirmClear(l10n),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.edit,
                          color: _stylusOnly
                              ? Theme.of(context).colorScheme.primary
                              : null,
                        ),
                        tooltip: l10n.stylusOnly,
                        onPressed: () =>
                            setState(() => _stylusOnly = !_stylusOnly),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}