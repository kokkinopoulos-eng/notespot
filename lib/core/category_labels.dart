import 'package:flutter/widgets.dart';
import '../l10n/app_localizations.dart';

/// Display name for a category key, based on the current app locale.
/// Self-contained EL/EN labels for all 20 categories (no ARB needed).
String localizedCategory(AppLocalizations l10n, String canonical) {
  // We read the locale from the l10n delegate's localeName when available;
  // fall back to Greek labels otherwise.
  final key = canonical.toLowerCase().trim();
  final isEl = l10n.localeName.toLowerCase().startsWith('el');
  final map = isEl ? _el : _en;
  return map[key] ?? canonical;
}

/// Locale-independent helper (pass true for Greek).
String categoryLabel(String canonical, {required bool greek}) {
  final key = canonical.toLowerCase().trim();
  final map = greek ? _el : _en;
  return map[key] ?? canonical;
}

/// Convenience for widgets that have a BuildContext.
String categoryLabelOf(BuildContext context, String canonical) {
  final isEl = Localizations.localeOf(context).languageCode == 'el';
  return categoryLabel(canonical, greek: isEl);
}

const Map<String, String> _el = {
  'passwords': 'Κωδικοί',
  'contacts': 'Επαφές',
  'shopping': 'Ψώνια',
  'receipts': 'Αποδείξεις',
  'finance': 'Οικονομικά',
  'work': 'Δουλειά',
  'health': 'Υγεία',
  'travel': 'Ταξίδια',
  'ideas': 'Ιδέες',
  'addresses': 'Διευθύνσεις',
  'pets': 'Κατοικίδια',
  'food': 'Φαγητό',
  'education': 'Εκπαίδευση',
  'tech': 'Τεχνολογία',
  'vehicle': 'Όχημα',
  'home': 'Σπίτι',
  'appointments': 'Ραντεβού',
  'bills': 'Λογαριασμοί',
  'personal': 'Προσωπικά',
  'other': 'Γενικά',
};

const Map<String, String> _en = {
  'passwords': 'Passwords',
  'contacts': 'Contacts',
  'shopping': 'Shopping',
  'receipts': 'Receipts',
  'finance': 'Finance',
  'work': 'Work',
  'health': 'Health',
  'travel': 'Travel',
  'ideas': 'Ideas',
  'addresses': 'Addresses',
  'pets': 'Pets',
  'food': 'Food',
  'education': 'Education',
  'tech': 'Tech',
  'vehicle': 'Vehicle',
  'home': 'Home',
  'appointments': 'Appointments',
  'bills': 'Bills',
  'personal': 'Personal',
  'other': 'General',
};
