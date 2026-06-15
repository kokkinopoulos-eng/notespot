import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Size;
import 'package:google_mlkit_digital_ink_recognition/google_mlkit_digital_ink_recognition.dart';

import '../widgets/drawing_canvas.dart';

/// Recognizes handwritten arithmetic from ink strokes and evaluates the result.
///
/// Model: "en-US" (English) — the best available for digit + operator recognition.
/// There is no dedicated math model in the ML Kit Digital Ink base model catalogue;
/// the English model reliably recognizes digits and common symbols (+, -, ×, ÷).
class InkMathService {
  static final InkMathService instance = InkMathService._();
  InkMathService._();

  static const _modelTag = 'en-US';

  final _modelManager = DigitalInkRecognizerModelManager();
  DigitalInkRecognizer? _recognizer;

  /// Returns true when the model is already on-device.
  Future<bool> isModelReady() async {
    try {
      return await _modelManager.isModelDownloaded(_modelTag);
    } catch (_) {
      return false;
    }
  }

  /// Downloads the model if not present. Returns null on success, error string on failure.
  Future<String?> ensureModel() async {
    try {
      final already = await _modelManager.isModelDownloaded(_modelTag);
      if (already) {
        _recognizer ??= DigitalInkRecognizer(languageCode: _modelTag);
        return null;
      }
      final ok = await _modelManager.downloadModel(
        _modelTag,
        isWifiRequired: false,
      );
      if (!ok) return 'Αποτυχία λήψης μοντέλου — ελέγξτε τη σύνδεση';
      _recognizer ??= DigitalInkRecognizer(languageCode: _modelTag);
      return null;
    } catch (e) {
      return 'Σφάλμα μοντέλου: $e';
    }
  }

  /// Converts strokes to ML Kit Ink, runs recognition, returns top candidate text.
  /// Timestamps are synthetic (10 ms per point, 50 ms gap between strokes).
  /// Returns null on empty canvas or recognition failure.
  Future<String?> recognize(
    List<DrawingStroke> strokes,
    Size canvasSize,
  ) async {
    try {
      _recognizer ??= DigitalInkRecognizer(languageCode: _modelTag);
      if (strokes.isEmpty) return null;

      final ink = Ink();
      int t = 0;
      for (final stroke in strokes) {
        if (stroke.points.isEmpty) continue;
        final s = Stroke();
        for (final point in stroke.points) {
          s.points.add(StrokePoint(x: point.dx, y: point.dy, t: t));
          t += 10;
        }
        ink.strokes.add(s);
        t += 50;
      }
      if (ink.strokes.isEmpty) return null;

      final ctx = DigitalInkRecognitionContext(
        writingArea: WritingArea(
          width: canvasSize.width,
          height: canvasSize.height,
        ),
      );
      final candidates = await _recognizer!.recognize(ink, context: ctx);
      return candidates.isEmpty ? null : candidates.first.text;
    } catch (e) {
      debugPrint('[InkMath] recognize error: $e');
      return null;
    }
  }

  /// Normalizes the recognized string and evaluates it as arithmetic (+, -, *, /).
  /// Handles ×→*, ÷→/, x/X (when between digits)→*, en/em dash→-, commas→dots.
  /// Returns the numeric result or null if not a valid expression.
  Future<double?> evaluate(String expression) async {
    try {
      var expr = expression
          .replaceAll('×', '*')
          .replaceAll('÷', '/')
          .replaceAll('–', '-')
          .replaceAll('—', '-')
          .replaceAll(',', '.')
          .replaceAll('=', '')
          .replaceAll(' ', '');
      // x/X between digits → multiplication
      expr = expr.replaceAllMapped(
        RegExp(r'(\d)[xX](\d)'),
        (m) => '${m[1]}*${m[2]}',
      );
      // Strip any unrecognised characters
      expr = expr.replaceAll(RegExp(r'[^\d.+\-*/]'), '');
      return _evalSimple(expr);
    } catch (_) {
      return null;
    }
  }

  /// Tokenises [expr] and evaluates it with correct operator precedence (* / before + -).
  /// Supports unary minus on the first operand. No parentheses.
  double? _evalSimple(String expr) {
    if (expr.isEmpty) return null;

    final nums = <double>[];
    final ops = <String>[];
    final sb = StringBuffer();
    bool expectNum = true;

    void flushNum() {
      if (sb.isEmpty) return;
      final n = double.tryParse(sb.toString());
      if (n != null) nums.add(n);
      sb.clear();
    }

    for (final c in expr.split('')) {
      if ('0123456789.'.contains(c)) {
        sb.write(c);
        expectNum = false;
      } else if (c == '-' && expectNum) {
        sb.write(c); // unary minus — part of the next number
      } else if ('+-*/'.contains(c)) {
        flushNum();
        if (nums.length != ops.length + 1) return null;
        ops.add(c);
        expectNum = true;
      } else {
        return null; // unexpected character
      }
    }
    flushNum();

    if (nums.length != ops.length + 1 || nums.isEmpty) return null;

    // Pass 1: * and / (left-to-right)
    int i = 0;
    while (i < ops.length) {
      if (ops[i] == '*' || ops[i] == '/') {
        final a = nums[i], b = nums[i + 1];
        if (ops[i] == '/' && b == 0) return null;
        nums[i] = ops[i] == '*' ? a * b : a / b;
        nums.removeAt(i + 1);
        ops.removeAt(i);
        // do NOT increment i — re-check same index
      } else {
        i++;
      }
    }

    // Pass 2: + and - (left-to-right)
    var result = nums[0];
    for (int j = 0; j < ops.length; j++) {
      result += ops[j] == '+' ? nums[j + 1] : -nums[j + 1];
    }
    return result;
  }

  void dispose() {
    _recognizer?.close();
    _recognizer = null;
  }
}
