import 'package:http/http.dart' as http;

enum AiProvider { openai, anthropic, gemini }

class ValidationResult {
  final bool isSuccess;
  final String message;
  ValidationResult(this.isSuccess, this.message);
}

Future<ValidationResult> testApiKey(AiProvider provider, String key) async {
  try {
    // Παράδειγμα κλήσης (προσάρμοσε το URL ανάλογα με τον provider σου)
    final response = await http.get(
      Uri.parse('https://api.example.com/check'), // Εδώ βάζεις το endpoint σου
      headers: {'Authorization': 'Bearer $key'},
    );

    if (response.statusCode == 200) {
      return ValidationResult(true, "✅ Το κλειδί είναι έγκυρο!");
    } else if (response.statusCode == 401 || response.statusCode == 403) {
      return ValidationResult(false, "Το κλειδί φαίνεται λάθος. Έλεγξέ το.");
    } else {
      return ValidationResult(false, "Κάτι δεν πήγε καλά με τον server.");
    }
  } catch (e) {
    return ValidationResult(false, "Πρόβλημα σύνδεσης. Δες το ίντερνετ σου.");
  }
}