import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class LocalAnalysisResult {
  const LocalAnalysisResult(
      {required this.ocrText, required this.category, required this.tags});
  final String ocrText;
  final String category;
  final List<String> tags;
}

class _Rule {
  const _Rule(this.category, this.keywords);
  final String category;
  final List<String> keywords;
}

class LocalAnalysisService {
  LocalAnalysisService._();
  static final instance = LocalAnalysisService._();

  static const _kRules = <_Rule>[
    _Rule('personal', [
      'anydesk', 'teamviewer', 'password', 'κωδικος', 'pin', 'otp',
      'serial', 'license', 'wifi', ' ip ',
    ]),
    _Rule('personal', [
      'τηλ ', 'κιν ', 'phone', 'mobile', 'email',
    ]),
    _Rule('shopping', [
      'λιστα', 'αγορα', 'σουπερ μαρκετ', 'ψωμι', 'γαλα',
      'grocery', 'shopping', 'market',
    ]),
    _Rule('receipts', [
      'αποδειξη', 'τιμολογιο', 'αφμ', 'φπα', 'total',
      'receipt', 'invoice', 'subtotal',
    ]),
    _Rule('work', [
      'meeting', 'συσκεψη', 'project', 'deadline', 'task',
      'εργασια', 'πελατης', 'agenda',
    ]),
    _Rule('personal', [
      'γιατρος', 'φαρμακο', 'ραντεβου', 'συνταγη',
      'doctor', 'clinic', 'hospital', 'εξετασεις',
    ]),
    _Rule('travel', [
      'πτηση', 'ξενοδοχειο', 'booking', 'flight', 'hotel',
      'εισιτηριο', 'boarding', 'passport', 'airline',
    ]),
    _Rule('ideas', ['ιδεα', 'θυμηθω', 'todo', 'reminder', 'idea']),
    _Rule('personal', [
      'οδος', 'λεωφ', 'address', 'street', 'avenue', 'blvd',
    ]),
    _Rule('food', [
      'food', 'meal', 'πιατο', 'φαγητο', 'dish',
      'restaurant', 'pizza', 'burger', 'coffee', 'menu',
    ]),
  ];

  static final _rePhone = RegExp(r'(?<!\d)(69\d{8}|2\d{9})(?!\d)');
  static final _reEmail = RegExp(r'[\w.+\-]+@[\w.\-]+\.\w{2,}');
  static final _reEuro = RegExp(r'€\s*\d|\d+[,\.]\d+\s*€');
  static final _rePostal = RegExp(r'(?<!\d)\d{5}(?!\d)');

  Future<LocalAnalysisResult> analyzeImage(String imagePath) async {
    final raw = await _runOcr(imagePath);
    final searchable =
        raw.trim().isNotEmpty ? raw : await _runLabeling(imagePath);
    return _classify(searchable);
  }

  LocalAnalysisResult classifyText(String text) => _classify(text);

  Future<String> _runOcr(String imagePath) async {
    try {
      final input = InputImage.fromFilePath(imagePath);
      final recognizer = TextRecognizer();
      final result = await recognizer.processImage(input);
      await recognizer.close();
      return result.text;
    } catch (_) {
      return '';
    }
  }

  Future<String> _runLabeling(String imagePath) async {
    try {
      final input = InputImage.fromFilePath(imagePath);
      final labeler = ImageLabeler(
          options: ImageLabelerOptions(confidenceThreshold: 0.7));
      final labels = await labeler.processImage(input);
      await labeler.close();
      return labels.map((l) => l.label).join(' ');
    } catch (_) {
      return '';
    }
  }

  LocalAnalysisResult _classify(String text) {
    final norm = _normalize(text);
    final cat = _matchCategory(norm);
    return LocalAnalysisResult(
        ocrText: text.trim(), category: cat, tags: _makeTags(norm, cat));
  }

  String _matchCategory(String norm) {
    if (_rePhone.hasMatch(norm)) return 'personal';
    if (_reEmail.hasMatch(norm)) return 'personal';
    if (_reEuro.hasMatch(norm)) return 'receipts';
    if (_rePostal.hasMatch(norm)) return 'personal';
    for (final rule in _kRules) {
      if (rule.keywords.any((kw) => norm.contains(kw))) return rule.category;
    }
    return 'other';
  }

  List<String> _makeTags(String norm, String category) {
    final found = <String>[];
    for (final rule in _kRules) {
      if (rule.category != category) continue;
      for (final kw in rule.keywords) {
        if (found.length >= 4) break;
        if (norm.contains(kw)) found.add(kw.trim());
      }
      if (found.isNotEmpty) break;
    }
    return found.isEmpty ? [category] : found;
  }

  String _normalize(String text) {
    const accents = {
      'ά': 'α', 'έ': 'ε', 'ή': 'η', 'ί': 'ι', 'ό': 'ο', 'ύ': 'υ', 'ώ': 'ω',
      'ϊ': 'ι', 'ϋ': 'υ', 'ΐ': 'ι', 'ΰ': 'υ', 'ς': 'σ',
    };
    var out = text.toLowerCase();
    accents.forEach((k, v) => out = out.replaceAll(k, v));
    return out;
  }
}
