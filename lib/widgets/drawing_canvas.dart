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
  bool eraserMode = false;
  Size? lastLayoutSize;

  bool get isEmpty => strokes.isEmpty;

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
    eraserMode = false;
    notifyListeners();
  }

  void setWidth(double w) {
    width = w;
    eraserMode = false;
    notifyListeners();
  }

  void setStylusOnly(bool v) {
    stylusOnly = v;
    notifyListeners();
  }

  void setEraser(bool v) {
    eraserMode = v;
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

  /// Removes every stroke passing near [p].
  void eraseAt(Offset p) {
    final r = 18.0;
    final before = strokes.length;
    strokes.removeWhere(
        (s) => s.points.any((q) => (q - p).distance <= r + s.width / 2));
    if (strokes.length != before) notifyListeners();
  }

  void beginStroke(Offset pos) {
    if (eraserMode) {
      eraseAt(_clamp(pos));
      return;
    }
    current = DrawingStroke(color: color, width: width)
      ..points.add(_clamp(pos));
    notifyListeners();
  }

  void addPoint(Offset pos) {
    if (eraserMode) {
      eraseAt(_clamp(pos));
      return;
    }
    current?.points.add(_clamp(pos));
    notifyListeners();
  }

  /// Scribble-to-erase: fast back-and-forth in a confined bounding box.
  /// Works with S Pen (dense points, low pressure variance).
  bool _isScribble(DrawingStroke s) {
    if (s.points.length < 10) return false;
    // Bounding box
    double minX = s.points[0].dx, maxX = minX;
    double minY = s.points[0].dy, maxY = minY;
    for (final p in s.points) {
      if (p.dx < minX) minX = p.dx;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy < minY) minY = p.dy;
      if (p.dy > maxY) maxY = p.dy;
    }
    final w = maxX - minX;
    final h = maxY - minY;
    // Must be wide (horizontal scribble) or a compact zigzag
    if (w < 40 && h < 40) return false;
    // Count horizontal direction reversals
    int flips = 0;
    double prevDx = 0;
    for (int i = 4; i < s.points.length; i += 3) {
      final dx = s.points[i].dx - s.points[i - 3].dx;
      if (dx.abs() > 3) {
        if (prevDx != 0 && dx.sign != prevDx.sign) flips++;
        prevDx = dx;
      }
    }
    // Total path length vs bounding box perimeter
    double len = 0;
    for (int i = 1; i < s.points.length; i++) {
      len += (s.points[i] - s.points[i - 1]).distance;
    }
    final perim = 2 * (w + h);
    // Scribble = many reversals AND path much longer than bounding box
    return flips >= 3 && len > 1.8 * perim;
  }

  void endStroke() {
    final c = current;
    if (c == null) return;
    current = null;
    if (!eraserMode && _isScribble(c)) {
      // Erase all strokes that overlap with the scribble path
      strokes.removeWhere((s) => s.points.any((q) =>
          c.points.any((p) => (q - p).distance <= 16 + s.width / 2)));
      notifyListeners();
      return;
    }
    strokes.add(c);
    notifyListeners();
  }

  Future<Uint8List?> toPngBytes() async {
    if (strokes.isEmpty || lastLayoutSize == null) return null;
    return renderPagesToPng([this]);
  }
}

/// Renders one or more ink pages into a single tall PNG:
/// page 1 on top, page 2 below, etc., separated by a thin grey line.
Future<Uint8List?> renderPagesToPng(List<DrawingCanvasController> pages) async {
  final drawn =
      pages.where((p) => !p.isEmpty && p.lastLayoutSize != null).toList();
  if (drawn.isEmpty) return null;

  const sep = 3.0;
  double width = 0;
  double totalH = 0;
  for (final p in drawn) {
    final s = p.lastLayoutSize!;
    if (s.width > width) width = s.width;
    totalH += s.height;
  }
  totalH += sep * (drawn.length - 1);

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    Rect.fromLTWH(0, 0, width, totalH),
    Paint()..color = Colors.white,
  );

  double y = 0;
  for (int i = 0; i < drawn.length; i++) {
    final p = drawn[i];
    canvas.save();
    canvas.translate(0, y);
    DrawPainter.paintStrokes(canvas, p.strokes);
    canvas.restore();
    y += p.lastLayoutSize!.height;
    if (i < drawn.length - 1) {
      canvas.drawRect(
        Rect.fromLTWH(0, y, width, sep),
        Paint()..color = const Color(0xFFE0E0E0),
      );
      y += sep;
    }
  }

  final picture = recorder.endRecording();
  final img = await picture.toImage(width.toInt(), totalH.toInt());
  final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
  return byteData?.buffer.asUint8List();
}

/// Ink surface. Clipped to its own bounds; strokes are clamped so they
/// can never bleed into neighbouring panes.
class DrawingSurface extends StatelessWidget {
  const DrawingSurface(
      {super.key, required this.controller, this.onDrawStart});

  final DrawingCanvasController controller;
  final VoidCallback? onDrawStart;

  void _down(PointerDownEvent e) {
    if (controller.stylusOnly && e.kind != PointerDeviceKind.stylus) return;
    onDrawStart?.call();
    controller.beginStroke(e.localPosition);
  }

  void _move(PointerMoveEvent e) {
    if (controller.stylusOnly && e.kind != PointerDeviceKind.stylus) return;
    if (!controller.eraserMode && controller.current == null) return;
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

/// Pen toolbar: colors, widths, eraser, undo, clear, stylus-only toggle.
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
    final active = !controller.eraserMode && controller.color.value == c.value;
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



  Widget _toolBtn({
    required IconData icon,
    required VoidCallback? onPressed,
    String? tooltip,
    bool active = false,
    required ColorScheme cs,
  }) {
    return SizedBox(
      width: 44,
      height: 36,
      child: IconButton(
        icon: Icon(icon, size: 20),
        tooltip: tooltip,
        color: active ? cs.primary : cs.onSurface,
        style: active
            ? IconButton.styleFrom(backgroundColor: cs.primaryContainer)
            : null,
        visualDensity: VisualDensity.compact,
        onPressed: onPressed,
        padding: EdgeInsets.zero,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => Container(
        color: cs.surface,
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Row 1: colors + widths
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ..._colors.map((c) => _swatch(context, c)),
                Container(width: 1, height: 24, color: cs.outlineVariant),
                ..._widths.map((w) {
                  final active = !controller.eraserMode && controller.width == w;
                  return GestureDetector(
                    onTap: () => controller.setWidth(w),
                    child: SizedBox(
                      width: 36,
                      height: 36,
                      child: Center(
                        child: Container(
                          width: w + 10,
                          height: w + 10,
                          decoration: BoxDecoration(
                            color: active ? controller.color : Colors.grey,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
            Divider(height: 6, thickness: 0.5, color: cs.outlineVariant),
            // Row 2: tools — evenly spaced, same size
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _toolBtn(
                  icon: Icons.auto_fix_normal,
                  tooltip: 'Eraser',
                  active: controller.eraserMode,
                  cs: cs,
                  onPressed: () => controller.setEraser(!controller.eraserMode),
                ),
                _toolBtn(
                  icon: Icons.undo,
                  tooltip: l10n.undo,
                  cs: cs,
                  onPressed: controller.isEmpty ? null : controller.undo,
                ),
                _toolBtn(
                  icon: Icons.delete_sweep,
                  tooltip: l10n.clearAll,
                  cs: cs,
                  onPressed: () => _confirmClear(context, l10n),
                ),
                _toolBtn(
                  icon: Icons.edit,
                  tooltip: l10n.stylusOnly,
                  active: controller.stylusOnly,
                  cs: cs,
                  onPressed: () =>
                      controller.setStylusOnly(!controller.stylusOnly),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}