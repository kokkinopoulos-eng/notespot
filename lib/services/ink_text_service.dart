import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Size;
import 'package:google_mlkit_digital_ink_recognition/google_mlkit_digital_ink_recognition.dart';
import '../widgets/drawing_canvas.dart';

/// Converts handwritten ink strokes into typed text.
///
/// Uses a per-language ML Kit Digital Ink model. Defaults to Greek ('el'),
/// with English ('en') as an alternate. Because handwriting recognition is
/// inherently ambiguous, [recognizeCandidates] returns several options so the
/// UI can let the user pick the right one.
class InkTextService {
  static final InkTextService instance = InkTextService._();
  InkTextService._();

  final _modelManager = DigitalInkRecognizerModelManager();
  final _recognizers = <String, DigitalInkRecognizer>{};

  /// True when the model for [lang] is already on-device.
  Future<bool> isModelReady(String lang) async {
    try {
      return await _modelManager.isModelDownloaded(lang);
    } catch (_) {
      return false;
    }
  }

  /// Downloads the model for [lang] if missing. Returns null on success,
  /// or an error string on failure.
  Future<String?> ensureModel(String lang) async {
    try {
      final already = await _modelManager.isModelDownloaded(lang);
      if (!already) {
        final ok = await _modelManager.downloadModel(lang, isWifiRequired: false);
        if (!ok) return 'Αποτυχία λήψης μοντέλου ($lang) — ελέγξτε τη σύνδεση';
      }
      _recognizers[lang] ??= DigitalInkRecognizer(languageCode: lang);
      return null;
    } catch (e) {
      return 'Σφάλμα μοντέλου: $e';
    }
  }

  /// Recognizes the strokes and returns up to [maxCandidates] text options,
  /// ordered by the recognizer's confidence (best first).
  Future<List<String>> recognizeCandidates(
    List<DrawingStroke> strokes,
    Size canvasSize, {
    String lang = 'el',
    int maxCandidates = 5,
  }) async {
    try {
      if (strokes.isEmpty) return const [];
      final rec = _recognizers[lang] ??= DigitalInkRecognizer(languageCode: lang);

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
      if (ink.strokes.isEmpty) return const [];

      final ctx = DigitalInkRecognitionContext(
        writingArea: WritingArea(
          width: canvasSize.width,
          height: canvasSize.height,
        ),
      );
      final candidates = await rec.recognize(ink, context: ctx);
      final out = <String>[];
      for (final c in candidates) {
        final txt = c.text.trim();
        if (txt.isNotEmpty && !out.contains(txt)) out.add(txt);
        if (out.length >= maxCandidates) break;
      }
      return out;
    } catch (e) {
      debugPrint('[InkText] recognize error: $e');
      return const [];
    }
  }
}
