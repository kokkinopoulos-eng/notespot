import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

class DrawingStroke {
  DrawingStroke({required this.color, required this.width});
  final Color color;
  final double width;
  final List<Offset> points = [];
}

class DrawPainter extends CustomPainter {
  const DrawPainter(this.strokes, this.current);
  final List<DrawingStroke> strokes;
  final DrawingStroke? current;

  static void paintStrokes(Canvas canvas, List<DrawingStroke> strokes) {
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
  bool shouldRepaint(DrawPainter old) => true;
}

class DrawingCanvasController extends ChangeNotifier {
  final List<DrawingStroke> strokes = [];
  DrawingStroke? current;
  Color color = Colors.black;
  double width = 3.0;
  bool stylusOnly = false;
  Size? lastLayoutSize;

  bool get isEmpty => strokes.isEmpty;

  /// Clamps a point inside the canvas bounds so strokes can never
  /// leave the ink pane (pointer capture keeps sending moves outside).
  Offset _clamp(Offset p) {
    final s = lastLayoutSize;
    if (s == null) return p;
    return Offset(
      p.dx.clamp(0.0, s.width),
      p.dy.clamp(0.0, s.height),
    );
  }

  void setColor(Color c) {
    color = c;
    notifyListeners();
  }

  void setWidth(double w) {
    width = w;
    notifyListeners();
  }

  void setStylusOnly(bool v) {
    stylusOnly = v;
    notifyListeners();
  }

  void undo() {
    if (strokes.isNotEmpty) {
      strokes.removeLast();
      notifyListeners();
    }
  }

  void clear() {
    strokes.clear();
    current = null;
    notifyListeners();
  }

  void beginStroke(Offset pos) {
    current = DrawingStroke(color: color, width: width)..points.add(_clamp(pos));
    notifyListeners();
  }

  void addPoint(Offset pos) {
    current?.points.add(_clamp(pos));
    notifyListeners();
  }

  void endStroke() {
    if (current != null) {
      strokes.add(current!);
      current = null;
      notifyListeners();
    }
  }

  Future<Uint8List?> toPngBytes() async {
    if (strokes.isEmpty || lastLayoutSize == null) return null;
    final size = lastLayoutSize!;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = Colors.white,
    );
    DrawPainter.paintStrokes(canvas, strokes);
    final picture = recorder.endRecording();
    final img =
        await picture.toImage(size.width.toInt(), size.height.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }
}

/// Ink surface. Clipped to its own bounds; strokes are clamped so they
/// can never bleed into neighbouring panes.
class DrawingSurface extends StatelessWidget {
  const DrawingSurface({super.key, required this.controller, this.onDrawStart});

  final DrawingCanvasController controller;
  final VoidCallback? onDrawStart;

  void _down(PointerDownEvent e) {
    if (controller.stylusOnly && e.kind != PointerDeviceKind.stylus) return;
    onDrawStart?.call();
    controller.beginStroke(e.localPosition);
  }

  void _move(PointerMoveEvent e) {
    if (controller.current == null) return;
    if (controller.stylusOnly && e.kind != PointerDeviceKind.stylus) return;
    controller.addPoint(e.localPosition);
  }

  void _up(PointerUpEvent e) => controller.endStroke();

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) => LayoutBuilder(
          builder: (context, constraints) {
            controller.lastLayoutSize = constraints.biggest;
            return Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: _down,
              onPointerMove: _move,
              onPointerUp: _up,
              child: CustomPaint(
                painter: DrawPainter(controller.strokes, controller.current),
                child: const SizedBox.expand(),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Pen toolbar: colors, widths, undo, clear, stylus-only toggle.
class DrawingToolbar extends StatelessWidget {
  const DrawingToolbar({super.key, required this.controller});

  final DrawingCanvasController controller;

  static const _colors = [
    Colors.black,
    Color(0xFF1565C0),
    Color(0xFFC62828),
    Color(0xFF2E7D32),
  ];
  static const _widths = [2.0, 4.0, 8.0];

  Future<void> _confirmClear(
      BuildContext context, AppLocalizations l10n) async {
    if (controller.strokes.isEmpty) return;
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
    if (confirmed == true) controller.clear();
  }

  Widget _swatch(BuildContext context, Color c) {
    final active = controller.color.value == c.value;
    return GestureDetector(
      onTap: () => controller.setColor(c),
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
    final active = controller.width == w;
    return GestureDetector(
      onTap: () => controller.setWidth(w),
      child: Container(
        width: w + 12,
        height: w + 12,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: active ? controller.color : Colors.grey,
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => Container(
        color: Theme.of(context).colorScheme.surface,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(children: _colors.map((c) => _swatch(context, c)).toList()),
            Row(children: _widths.map(_widthBtn).toList()),
            Row(children: [
              IconButton(
                icon: const Icon(Icons.undo),
                tooltip: l10n.undo,
                onPressed: controller.isEmpty ? null : controller.undo,
              ),
              IconButton(
                icon: const Icon(Icons.delete_sweep),
                tooltip: l10n.clearAll,
                onPressed: () => _confirmClear(context, l10n),
              ),
              IconButton(
                icon: Icon(Icons.edit,
                    color: controller.stylusOnly
                        ? Theme.of(context).colorScheme.primary
                        : null),
                tooltip: l10n.stylusOnly,
                onPressed: () =>
                    controller.setStylusOnly(!controller.stylusOnly),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}