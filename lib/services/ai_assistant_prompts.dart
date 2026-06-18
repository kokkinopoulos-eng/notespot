// lib/services/ai_assistant_prompts.dart
//
// Greek-tuned prompts για AI Assistant features (NoteSpot Pro v1.1).
//
// Όλα τα prompts επιστρέφουν ΜΟΝΟ το επεξεργασμένο κείμενο, χωρίς προοίμιο
// ή εξηγήσεις. Designed για Claude Haiku 4.5 / Sonnet 4.6, OpenAI GPT-4o,
// Google Gemini 2.x. Default model: Haiku 4.5 (cost-optimal για editing).

class AiPrompts {
  AiPrompts._();

  // ───────────────────────────────────────────────────────────────
  // System rule — prepended σε όλα τα editing prompts
  // ───────────────────────────────────────────────────────────────

  static const String _systemRule =
      'Είσαι βοηθός επεξεργασίας κειμένου για ελληνική memo εφαρμογή. '
      'Επιστρέφεις ΠΑΝΤΑ μόνο το επεξεργασμένο κείμενο, χωρίς εισαγωγή, '
      'χωρίς εξηγήσεις, χωρίς markdown formatting εκτός αν υπάρχει στο '
      'αρχικό. Διατηρείς πάντα ελληνική γλώσσα.';

  // ───────────────────────────────────────────────────────────────
  // AI Assistant Button — text editing operations
  // ───────────────────────────────────────────────────────────────

  static String grammarFix(String text) => '''
$_systemRule

Διόρθωσε ορθογραφικά, γραμματικά και συντακτικά λάθη στο παρακάτω κείμενο.
Μη αλλάξεις το νόημα ή τον τόνο. Αν δεν υπάρχουν λάθη, επέστρεψε το κείμενο
αυτούσιο.

ΚΕΙΜΕΝΟ:
$text''';

  static String summarize(String text) => '''
$_systemRule

Σύνοψε το παρακάτω κείμενο σε 1-2 προτάσεις. Κράτησε τα ουσιαστικά σημεία.

ΚΕΙΜΕΝΟ:
$text''';

  static String expand(String text) => '''
$_systemRule

Επέκτεινε το παρακάτω σύντομο κείμενο, προσθέτοντας σχετικές λεπτομέρειες
και εξηγήσεις. Διατήρησε τον τόνο και το ύφος του αρχικού.

ΚΕΙΜΕΝΟ:
$text''';

  static String shorten(String text) => '''
$_systemRule

Συντόμευσε το παρακάτω κείμενο στο μισό περίπου μήκος. Κράτησε τα
σημαντικότερα σημεία.

ΚΕΙΜΕΝΟ:
$text''';

  static String changeTone(String text, ToneStyle tone) => '''
$_systemRule

Ξαναγράψε το παρακάτω κείμενο σε ${tone.label} τόνο. Διατήρησε όλες τις
πληροφορίες, άλλαξε μόνο το ύφος.

ΚΕΙΜΕΝΟ:
$text''';

  static String paraphrase(String text) => '''
$_systemRule

Ξαναγράψε το παρακάτω κείμενο με διαφορετικά λόγια. Διατήρησε το νόημα
και τον αρχικό τόνο.

ΚΕΙΜΕΝΟ:
$text''';

  // ───────────────────────────────────────────────────────────────
  // Voice → Structured Note
  // ───────────────────────────────────────────────────────────────

  static String structureVoiceInput(String transcript, DateTime now) {
    final nowIso = now.toIso8601String();
    return '''
Ο χρήστης μίλησε φωνητικά σε εφαρμογή σημειώσεων και θέλει αυτόματη δομή.
Αναγνώρισε τον τύπο και επέστρεψε ΑΥΣΤΗΡΑ JSON (χωρίς markdown code fences,
χωρίς εξηγήσεις, χωρίς προοίμιο):

{
  "type": "checklist" | "text" | "reminder",
  "title": "σύντομος περιγραφικός τίτλος (max 5 λέξεις)",
  "items": [{"text": "...", "completed": false}],
  "content": "...",
  "reminder_at": "ISO8601 datetime με timezone"
}

Πεδία ανά τύπο:
- checklist: items (array), title
- text: content (string), title
- reminder: title, reminder_at (ISO8601), προαιρετικά content

ΚΑΝΟΝΕΣ ΑΝΑΓΝΩΡΙΣΗΣ:
- "ψώνια", "λίστα", "να πάρω", "αγορές", "να κάνω" → type=checklist
- "θύμισέ μου", "ραντεβού", "συνάντηση", "μην ξεχάσω" + ημερομηνία/ώρα → type=reminder
- Διαφορετικά → type=text

ΚΑΝΟΝΕΣ ΠΕΡΙΕΧΟΜΕΝΟΥ:
- Για checklist: σπάσε σε λογικά items, αφαίρεσε γεμίσματα ("να", "και", "ε")
- Για reminder: μετάτρεψε σχετικές ημερομηνίες ("αύριο", "Τρίτη", "σε 3 μέρες")
  σε απόλυτο ISO8601 datetime με timezone +03:00 (Ελλάδα).
  Αν δεν δίνεται ώρα, χρησιμοποίησε 09:00.
- Τίτλος πάντα στα ελληνικά, ουσιαστικός (όχι "Σημείωση 1")

ΤΩΡΙΝΗ ΗΜΕΡΟΜΗΝΙΑ ΑΝΑΦΟΡΑΣ: $nowIso

ΦΩΝΗΤΙΚΗ ΕΙΣΟΔΟΣ:
$transcript

JSON:''';
  }
}

// ─────────────────────────────────────────────────────────────────────
// Tone styles για το changeTone()
// ─────────────────────────────────────────────────────────────────────

enum ToneStyle {
  formal('επίσημο'),
  friendly('φιλικό'),
  professional('επαγγελματικό'),
  humorous('χιουμοριστικό');

  const ToneStyle(this.label);
  final String label;
}