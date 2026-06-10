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

class _DrawPainter extends CustomPainter {
  const _DrawPainter(this.strokes, this.current);
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
  bool shouldRepaint(_DrawPainter old) => true;
}

class DrawingCanvasController extends ChangeNotifier {
  final List<DrawingStroke> strokes = [];
  DrawingStroke? current;
  Color color = Colors.black;
  double width = 3.0;
  bool stylusOnly = false;
  Size? lastLayoutSize;

  bool get isEmpty => strokes.isEmpty;

  void setColor(Color c) { color = c; notifyListeners(); }
  void setWidth(double w) { width = w; notifyListeners(); }
  void setStylusOnly(bool v) { stylusOnly = v; notifyListeners(); }

  void undo() {
    if (strokes.isNotEmpty) { strokes.removeLast(); notifyListeners(); }
  }

  void clear() { strokes.clear(); current = null; notifyListeners(); }

  void beginStroke(Offset pos) {
    current = DrawingStroke(color: color, width: width)..points.add(pos);
    notifyListeners();
  }

  void addPoint(Offset pos) { current?.points.add(pos); notifyListeners(); }

  void endStroke() {
    if (current != null) { strokes.add(current!); current = null; notifyListeners(); }
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
    _DrawPainter.paintStrokes(canvas, strokes);
    final picture = recorder.endRecording();
    final img = await picture.toImage(size.width.toInt(), size.height.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }
}

class DrawingCanvas extends StatefulWidget {
  const DrawingCanvas({super.key, required this.controller});
  final DrawingCanvasController controller;

  @override
  State<DrawingCanvas> createState() => _DrawingCanvasState();
}

class _DrawingCanvasState extends State<DrawingCanvas> {
  static const _colors = [
    Colors.black,
    Color(0xFF1565C0),
    Color(0xFFC62828),
    Color(0xFF2E7D32),
  ];
  static const _widths = [2.0, 4.0, 8.0];

  DrawingCanvasController get _ctrl => widget.controller;

  void _onPointerDown(PointerDownEvent e) {
    if (_ctrl.stylusOnly && e.kind != PointerDeviceKind.stylus) return;
    _ctrl.beginStroke(e.localPosition);
  }

  void _onPointerMove(PointerMoveEvent e) {
    if (_ctrl.current == null) return;
    if (_ctrl.stylusOnly && e.kind != PointerDeviceKind.stylus) return;
    _ctrl.addPoint(e.localPosition);
  }

  void _onPointerUp(PointerUpEvent e) => _ctrl.endStroke();

  Future<void> _confirmClear(AppLocalizations l10n) async {
    if (_ctrl.strokes.isEmpty) return;
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
    if (confirmed == true) _ctrl.clear();
  }

  Widget _colorSwatch(Color c) {
    final active = _ctrl.color.value == c.value;
    return GestureDetector(
      onTap: () => setState(() => _ctrl.setColor(c)),
      child: Container(
        width: 28, height: 28,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: c,
          shape: BoxShape.circle,
          border: Border.all(
            color: active ? Theme.of(context).colorScheme.primary : Colors.transparent,
            width: 3,
          ),
        ),
      ),
    );
  }

  Widget _widthBtn(double w) {
    final active = _ctrl.width == w;
    return GestureDetector(
      onTap: () => setState(() => _ctrl.setWidth(w)),
      child: Container(
        width: w + 12, height: w + 12,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: active ? _ctrl.color : Colors.grey,
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) => Column(
        children: [
          Expanded(
            child: Container(
              color: Colors.white,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  _ctrl.lastLayoutSize = constraints.biggest;
                  return Listener(
                    onPointerDown: _onPointerDown,
                    onPointerMove: _onPointerMove,
                    onPointerUp: _onPointerUp,
                    child: CustomPaint(
                      painter: _DrawPainter(_ctrl.strokes, _ctrl.current),
                      child: const SizedBox.expand(),
                    ),
                  );
                },
              ),
            ),
          ),
          Container(
            color: Theme.of(context).colorScheme.surface,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: _colors.map(_colorSwatch).toList()),
                Row(children: _widths.map(_widthBtn).toList()),
                Row(children: [
                  IconButton(
                    icon: const Icon(Icons.undo),
                    tooltip: l10n.undo,
                    onPressed: _ctrl.isEmpty ? null : _ctrl.undo,
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_sweep),
                    tooltip: l10n.clearAll,
                    onPressed: () => _confirmClear(l10n),
                  ),
                  IconButton(
                    icon: Icon(Icons.edit,
                      color: _ctrl.stylusOnly
                          ? Theme.of(context).colorScheme.primary
                          : null),
                    tooltip: l10n.stylusOnly,
                    onPressed: () =>
                        setState(() => _ctrl.setStylusOnly(!_ctrl.stylusOnly)),
                  ),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}