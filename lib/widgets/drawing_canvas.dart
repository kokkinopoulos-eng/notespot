import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

import '../l10n/app_localizations.dart';

class MathAnnotation {
  const MathAnnotation({
    required this.text,
    required this.position,
    required this.fontSize,
    required this.color,
  });

  final String text;
  final Offset position;
  final double fontSize;
  final Color color;
}

class DrawingStroke {
  DrawingStroke({required this.color, required this.width});
  final Color color;
  final double width;
  final List<Offset> points = [];
}

class DrawPainter extends CustomPainter {
  DrawPainter(this.strokes, this.current, this.annotations);
  final List<DrawingStroke> strokes;
  final DrawingStroke? current;
  final List<MathAnnotation> annotations;

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

  static void paintAnnotations(
      Canvas canvas, List<MathAnnotation> annotations) {
    for (final ann in annotations) {
      final tp = TextPainter(
        text: TextSpan(
          text: ann.text,
          style: TextStyle(
            fontFamily: 'Caveat',
            fontSize: ann.fontSize,
            color: ann.color,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(minWidth: 0, maxWidth: double.infinity);
      tp.paint(canvas, ann.position);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final all = [...strokes, ?current];
    paintStrokes(canvas, all);
    paintAnnotations(canvas, annotations);
  }

  @override
  bool shouldRepaint(DrawPainter old) => true;
}

class DrawingCanvasController extends ChangeNotifier {
  final List<DrawingStroke> strokes = [];
  final List<MathAnnotation> mathAnnotations = [];
  // Tracks insertion order for undo: true = stroke, false = annotation.
  final List<bool> _undoStack = [];
  DrawingStroke? current;
  Color color = Colors.white;
  double width = 3.0;
  bool stylusOnly = false;
  bool stylusDetected = false;
  bool eraserMode = false;
  Color bgColor = Colors.black;
  Color strokeColor = Colors.white;
  Size? lastLayoutSize;
  Size? _maxLayout;

  /// Largest size the canvas has ever had — an open keyboard can never
  /// shrink the saved drawing.
  Size? get renderSize => _maxLayout ?? lastLayoutSize;

  void updateLayout(Size s) {
    lastLayoutSize = s;
    final m = _maxLayout;
    if (m == null) {
      _maxLayout = s;
    } else if (s.width > m.width || s.height > m.height) {
      _maxLayout = Size(
        s.width > m.width ? s.width : m.width,
        s.height > m.height ? s.height : m.height,
      );
    }
  }

  bool get isEmpty => strokes.isEmpty && mathAnnotations.isEmpty;

  /// True when there is at least one stroke or annotation that can be undone.
  bool get canUndo => strokes.isNotEmpty || mathAnnotations.isNotEmpty;

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

  Color _lastColor = Colors.white;
  void markStylusDetected() {
    if (!stylusDetected) {
      stylusDetected = true;
      notifyListeners();
    }
  }

  void setEraser(bool v) {
    if (v) {
      _lastColor = color;
    } else {
      color = _lastColor;
    }
    eraserMode = v;
    notifyListeners();
  }

  void setBgColor(Color c) {
    bgColor = c;
    // Auto-switch stroke to white on dark backgrounds, back to black on light.
    if (c.computeLuminance() < 0.3 && color == Colors.black) {
      color = Colors.white;
    } else if (c.computeLuminance() >= 0.3 && color == Colors.white) {
      color = Colors.black;
    }
    notifyListeners();
  }

  /// Undoes the last drawn stroke or added math annotation, in insertion order.
  void undo() {
    // Walk the stack from the end, skipping entries for items already erased.
    while (_undoStack.isNotEmpty) {
      final isStroke = _undoStack.removeLast();
      if (isStroke && strokes.isNotEmpty) {
        strokes.removeLast();
        notifyListeners();
        return;
      } else if (!isStroke && mathAnnotations.isNotEmpty) {
        mathAnnotations.removeLast();
        notifyListeners();
        return;
      }
      // Entry is orphaned (item was erased); consume it and try the next one.
    }
    // Stack exhausted — fall back to direct removal so the button stays useful.
    if (mathAnnotations.isNotEmpty) {
      mathAnnotations.removeLast();
      notifyListeners();
    } else if (strokes.isNotEmpty) {
      strokes.removeLast();
      notifyListeners();
    }
  }

  void clear() {
    strokes.clear();
    mathAnnotations.clear();
    _undoStack.clear();
    current = null;
    notifyListeners();
  }

  void addMathAnnotation(MathAnnotation a) {
    mathAnnotations.add(a);
    _undoStack.add(false);
    notifyListeners();
  }

  /// Removes every stroke passing near [p], and any math annotation whose
  /// rendered bounding box overlaps the eraser circle.
  void eraseAt(Offset p) {
    const r = 18.0;
    final strokesBefore = strokes.length;
    strokes.removeWhere(
        (s) => s.points.any((q) => (q - p).distance <= r + s.width / 2));

    final annBefore = mathAnnotations.length;
    mathAnnotations.removeWhere((a) {
      // Estimate text width from character count (Caveat is ~0.55× em wide).
      final estW = a.text.length * a.fontSize * 0.55;
      return p.dx >= a.position.dx - r &&
          p.dx <= a.position.dx + estW + r &&
          p.dy >= a.position.dy - r &&
          p.dy <= a.position.dy + a.fontSize + r;
    });

    if (strokes.length != strokesBefore || mathAnnotations.length != annBefore) {
      notifyListeners();
    }
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
  bool _isScribble(DrawingStroke s) {
    if (s.points.length < 10) return false;
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
    if (w < 40 && h < 40) return false;
    int flips = 0;
    double prevDx = 0;
    for (int i = 4; i < s.points.length; i += 3) {
      final dx = s.points[i].dx - s.points[i - 3].dx;
      if (dx.abs() > 3) {
        if (prevDx != 0 && dx.sign != prevDx.sign) flips++;
        prevDx = dx;
      }
    }
    double len = 0;
    for (int i = 1; i < s.points.length; i++) {
      len += (s.points[i] - s.points[i - 1]).distance;
    }
    final perim = 2 * (w + h);
    return flips >= 3 && len > 1.8 * perim;
  }

  void endStroke() {
    final c = current;
    if (c == null) return;
    current = null;
    if (!eraserMode && _isScribble(c)) {
      strokes.removeWhere((s) => s.points.any((q) =>
          c.points.any((p) => (q - p).distance <= 16 + s.width / 2)));
      notifyListeners();
      return;
    }
    strokes.add(c);
    _undoStack.add(true);
    notifyListeners();
  }

  Future<Uint8List?> toPngBytes() async {
    if (strokes.isEmpty || lastLayoutSize == null) return null;
    return renderPagesToPng([this]);
  }
}

/// Renders one or more ink pages into a single tall PNG.
/// Each page section is filled with that page's bgColor before strokes.
Future<Uint8List?> renderPagesToPng(List<DrawingCanvasController> pages) async {
  final drawn =
      pages.where((p) => !p.isEmpty && p.renderSize != null).toList();
  if (drawn.isEmpty) return null;

  const sep = 3.0;
  double width = 0;
  double totalH = 0;
  for (final p in drawn) {
    final s = p.renderSize!;
    if (s.width > width) width = s.width;
    totalH += s.height;
  }
  totalH += sep * (drawn.length - 1);

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);

  double y = 0;
  for (int i = 0; i < drawn.length; i++) {
    final p = drawn[i];
    canvas.save();
    canvas.translate(0, y);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, width, p.renderSize!.height),
      Paint()..color = p.bgColor,
    );
    DrawPainter.paintStrokes(canvas, p.strokes);
    DrawPainter.paintAnnotations(canvas, p.mathAnnotations);
    canvas.restore();
    y += p.renderSize!.height;
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
    if (e.kind == PointerDeviceKind.stylus) {
      controller.markStylusDetected();
    }
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
            controller.updateLayout(constraints.biggest);
            return Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: _down,
              onPointerMove: _move,
              onPointerUp: _up,
              child: CustomPaint(
                painter: DrawPainter(controller.strokes, controller.current,
                    controller.mathAnnotations),
                child: const SizedBox.expand(),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Pen toolbar: stroke colors, widths, eraser, undo, clear, stylus-only,
/// and canvas background color picker.
class DrawingToolbar extends StatelessWidget {
  const DrawingToolbar({super.key, required this.controller});

  final DrawingCanvasController controller;

  static const _colors = [
    Colors.white,
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

  Future<void> _pickBgColor(
      BuildContext context, AppLocalizations l10n) async {
    Color picked = controller.bgColor;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Canvas color'),
        content: StatefulBuilder(
          builder: (ctx, setS) => ColorPicker(
            pickerColor: picked,
            onColorChanged: (c) => setS(() => picked = c),
            pickerAreaHeightPercent: 0.7,
            enableAlpha: false,
            displayThumbColor: true,
            labelTypes: const [],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              controller.setBgColor(picked);
              Navigator.pop(ctx);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _swatch(BuildContext context, Color c) {
    final cs = Theme.of(context).colorScheme;
    final active =
        !controller.eraserMode && controller.color.toARGB32() == c.toARGB32();
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
                ? cs.primary
                : (c.computeLuminance() > 0.8
                    ? cs.outlineVariant
                    : Colors.transparent),
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
            // Row 1: stroke colors + widths
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ..._colors.map((c) => _swatch(context, c)),
                Container(width: 1, height: 24, color: cs.outlineVariant),
                ..._widths.map((w) {
                  final active =
                      !controller.eraserMode && controller.width == w;
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
            // Row 2: tools + bg color swatch
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
                  onPressed: controller.canUndo ? controller.undo : null,
                ),
                _toolBtn(
                  icon: Icons.delete_sweep,
                  tooltip: l10n.clearAll,
                  cs: cs,
                  onPressed: () => _confirmClear(context, l10n),
                ),
                if (controller.stylusDetected)
                  _toolBtn(
                    icon: Icons.draw,
                    tooltip: l10n.stylusOnly,
                    active: controller.stylusOnly,
                    cs: cs,
                    onPressed: () =>
                        controller.setStylusOnly(!controller.stylusOnly),
                  ),
                GestureDetector(
                  onTap: () => _pickBgColor(context, l10n),
                  child: Tooltip(
                    message: 'Canvas color',
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: controller.bgColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: cs.outline, width: 1.5),
                      ),
                      child: Icon(Icons.palette_outlined,
                          size: 14, color: cs.outline),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
