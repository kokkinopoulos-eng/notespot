import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class LocalAnalysisResult {
  const LocalAnalysisResult(
      {required this.ocrText, required this.category, required this.tags});
  final String ocrText;
  final String category;
  final List<String> tags;
}

/// Base rule prediction with a score, so Eva can combine it with the
/// learned Naive Bayes model.
class BasePrediction {
  const BasePrediction(this.category, this.score, this.tags);
  final String category;
  final int score;
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

  /// Canonical category keys. Keep 'other' last as the fallback.
  static const List<String> kCategories = <String>[
    'passwords',
    'contacts',
    'shopping',
    'receipts',
    'finance',
    'work',
    'health',
    'travel',
    'ideas',
    'addresses',
    'pets',
    'food',
    'education',
    'tech',
    'vehicle',
    'home',
    'appointments',
    'bills',
    'personal',
    'other',
  ];

  static const _kRules = <_Rule>[
    _Rule('passwords', [
      'κωδικος', 'κωδικο', 'συνθηματικο', 'password', 'passwd', 'pass ',
      'pin', 'otp', 'anydesk', 'teamviewer', 'wifi', 'ssid', 'login',
      'χρηστης', 'username', 'σειριακος', 'serial', 'license', 'κλειδι',
      'api key', 'apikey', 'token', 'κωδικους',
    ]),
    _Rule('contacts', [
      'τηλεφωνο', 'τηλ ', 'τηλ.', 'κινητο', 'κιν ', 'phone', 'mobile',
      'email', 'mail', 'επικοινωνια', 'contact', 'επαφη', 'επαφες',
      'whatsapp', 'viber',
    ]),
    _Rule('shopping', [
      'λιστα', 'αγορες', 'αγορα', 'ψωνια', 'σουπερ μαρκετ', 'supermarket',
      'grocery', 'ψωμι', 'γαλα', 'αυγα', 'καφες', 'list', 'buy', 'shopping',
      'market', 'φρουτα', 'λαχανικα', 'κρεας', 'απορρυπαντικο',
    ]),
    _Rule('receipts', [
      'αποδειξη', 'αποδειξεις', 'τιμολογιο', 'receipt', 'invoice', 'αφμ',
      'φπα', 'vat', 'total', 'συνολο', 'υποσυνολο', 'subtotal', 'πληρωμη',
      'ταμειακη', 'λιανικη',
    ]),
    _Rule('finance', [
      'τραπεζα', 'bank', 'iban', 'λογαριασμος', 'καταθεση', 'αναληψη',
      'μετρητα', 'cash', 'ευρω', 'euro', 'επενδυση', 'μετοχη', 'μετοχες',
      'crypto', 'bitcoin', 'δανειο', 'loan', 'καρτα', 'visa', 'mastercard',
    ]),
    _Rule('work', [
      'συσκεψη', 'meeting', 'project', 'εργο', 'deadline', 'προθεσμια',
      'task', 'εργασια', 'δουλεια', 'πελατης', 'client', 'agenda',
      'παρουσιαση', 'presentation', 'report', 'αναφορα', 'γραφειο', 'office',
    ]),
    _Rule('health', [
      'γιατρος', 'doctor', 'φαρμακο', 'φαρμακα', 'medicine', 'ραντεβου',
      'νοσοκομειο', 'hospital', 'εξετασεις', 'εξεταση', 'συνταγη γιατρου',
      'κλινικη', 'clinic', 'παθολογος', 'οδοντιατρος', 'αιματολογικες',
      'πιεση', 'χαπι', 'χαπια',
    ]),
    _Rule('travel', [
      'πτηση', 'flight', 'ξενοδοχειο', 'hotel', 'booking', 'εισιτηριο',
      'ticket', 'διαβατηριο', 'passport', 'αεροδρομιο', 'airport', 'airline',
      'boarding', 'ταξιδι', 'trip', 'εκδρομη', 'βαλιτσα', 'airbnb',
    ]),
    _Rule('ideas', [
      'ιδεα', 'idea', 'θυμηθω', 'θυμιση', 'σκεψη', 'todo', 'to do',
      'brainstorm', 'concept', 'project idea', 'σχεδιο',
    ]),
    _Rule('addresses', [
      'οδος', 'οδ.', 'διευθυνση', 'address', 'street', 'λεωφορος', 'λεωφ',
      'avenue', 'blvd', 'ταχυδρομικος', 'postal', ' τκ ', 'τ.κ', 'αριθμος',
      'πλατεια',
    ]),
    _Rule('pets', [
      'σκυλος', 'σκυλο', 'γατα', 'γατο', 'dog', 'cat', 'pet', 'κατοικιδιο',
      'κτηνιατρος', 'vet', 'ζωο', 'τροφη σκυλου', 'εμβολιο ζωου',
    ]),
    _Rule('food', [
      'φαγητο', 'food', 'συνταγη', 'recipe', 'εστιατοριο', 'restaurant',
      'πιτσα', 'pizza', 'μενου', 'menu', 'υλικα', 'μαγειρικη', 'cooking',
      'ταβερνα', 'delivery', 'σουβλακι', 'burger', 'κουζινα',
    ]),
    _Rule('education', [
      'μαθημα', 'lesson', 'σχολειο', 'school', 'πανεπιστημιο', 'university',
      'εξεταση', 'exam', 'σημειωσεις', 'study', 'διαβασμα', 'φροντιστηριο',
      'καθηγητης', 'teacher', 'τεστ', 'πτυχιο', 'σπουδες',
    ]),
    _Rule('tech', [
      'υπολογιστης', 'computer', 'λογισμικο', 'software', 'εφαρμογη', 'app',
      'κωδικας', 'code', 'server', 'ρυθμισεις', 'settings', 'bug', 'error',
      'σφαλμα', 'δικτυο', 'network', 'router', 'linux', 'windows', 'database',
    ]),
    _Rule('vehicle', [
      'αυτοκινητο', 'car', 'οχημα', 'πινακιδα', 'plate', 'καυσιμο', 'fuel',
      'βενζινη', 'πετρελαιο', 'σερβις', 'service', 'ασφαλεια αυτοκινητου',
      'κτεο', 'μηχανη', 'λαστιχα', 'συνεργειο', 'τελη κυκλοφοριας',
    ]),
    _Rule('home', [
      'σπιτι', 'home', 'ενοικιο', 'rent', 'ρευμα', 'διυ', 'repair',
      'επισκευη', 'καθαρισμα', 'υδραυλικος', 'ηλεκτρολογος', 'κηπος',
      'επιπλα', 'ικεα', 'ikea', 'μετακομιση',
    ]),
    _Rule('appointments', [
      'ραντεβου', 'appointment', 'συναντηση', 'ωρα ', 'ημερομηνια', 'date',
      'calendar', 'ημερολογιο', 'υπενθυμιση', 'meeting at', 'στις ',
    ]),
    _Rule('bills', [
      'λογαριασμος', 'bill', 'ρευμα', 'electricity', 'δεη', 'νερο', 'water',
      'τηλεφωνο', 'internet', 'πληρωμη', 'payment', 'οφειλη', 'qr', 'rf',
      'κωδικος πληρωμης', 'δοση', 'φυσικο αεριο',
    ]),
    _Rule('personal', [
      'προσωπικο', 'personal', 'οικογενεια', 'family', 'φιλοι', 'friends',
      'γενεθλια', 'birthday', 'επετειος', 'ημερολογιο',
    ]),
  ];

  static final _rePhone = RegExp(r'(?<!\d)(69\d{8}|2\d{9})(?!\d)');
  static final _reEmail = RegExp(r'[\w.+\-]+@[\w.\-]+\.\w{2,}');
  static final _reEuro = RegExp(r'€\s*\d|\d+[,\.]\d+\s*€');
  static final _rePostal = RegExp(r'(?<!\d)\d{5}(?!\d)');
  static final _reAfm = RegExp(r'(?<!\d)\d{9}(?!\d)');
  static final _reIban = RegExp(r'\bGR\d{2}[\s]?[\d\s]{20,}\b', caseSensitive: false);
  static final _reDate = RegExp(r'\b\d{1,2}[/.\-]\d{1,2}[/.\-]\d{2,4}\b');
  static final _reTime = RegExp(r'\b([01]?\d|2[0-3]):[0-5]\d\b');

  Future<LocalAnalysisResult> analyzeImage(String imagePath) async {
    final raw = await _runOcr(imagePath);
    final searchable =
        raw.trim().isNotEmpty ? raw : await _runLabeling(imagePath);
    return _classify(searchable);
  }

  LocalAnalysisResult classifyText(String text) => _classify(text);

  /// Computes the base rule prediction (category + score + tags) WITHOUT Eva.
  /// Eva calls this, then blends with its learned model.
  BasePrediction basePredict(String text) {
    final norm = _normalize(text);
    return _matchCategory(norm);
  }

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
    final base = _matchCategory(norm);
    return LocalAnalysisResult(
        ocrText: text.trim(), category: base.category, tags: base.tags);
  }

  /// Returns the best base category, a score (higher = more confident),
  /// and tags. Regex signals add weight to specific categories.
  BasePrediction _matchCategory(String norm) {
    // Tally keyword hits per category.
    final scores = <String, int>{};
    final hitKeywords = <String, List<String>>{};
    for (final rule in _kRules) {
      for (final kw in rule.keywords) {
        if (norm.contains(kw)) {
          scores[rule.category] = (scores[rule.category] ?? 0) + 1;
          (hitKeywords[rule.category] ??= []).add(kw.trim());
        }
      }
    }

    // Regex signals (each adds weight to a category).
    void bump(String cat, int by) => scores[cat] = (scores[cat] ?? 0) + by;
    if (_reIban.hasMatch(norm)) bump('finance', 3);
    if (_reAfm.hasMatch(norm) && !_rePostal.hasMatch(norm)) {
      // a standalone 9-digit number is more likely AFM (receipts/finance)
      bump('receipts', 2);
    }
    if (_reEuro.hasMatch(norm)) bump('receipts', 2);
    if (_rePhone.hasMatch(norm)) bump('contacts', 2);
    if (_reEmail.hasMatch(norm)) bump('contacts', 2);
    if (_reDate.hasMatch(norm)) bump('appointments', 1);
    if (_reTime.hasMatch(norm)) bump('appointments', 1);
    if (_rePostal.hasMatch(norm)) bump('addresses', 1);

    if (scores.isEmpty) {
      return const BasePrediction('other', 0, ['other']);
    }

    // Pick the highest-scoring category.
    String best = 'other';
    int bestScore = 0;
    scores.forEach((cat, sc) {
      if (sc > bestScore) {
        bestScore = sc;
        best = cat;
      }
    });

    final tags = (hitKeywords[best] ?? const <String>[]).take(4).toList();
    return BasePrediction(best, bestScore, tags.isEmpty ? [best] : tags);
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
