import '../l10n/app_localizations.dart';

String localizedCategory(AppLocalizations l10n, String canonical) {
  return switch (canonical.toLowerCase().trim()) {
    'receipts' => l10n.catReceipts,
    'work' => l10n.catWork,
    'personal' => l10n.catPersonal,
    'shopping' => l10n.catShopping,
    'ideas' => l10n.catIdeas,
    'food' => l10n.catFood,
    'travel' => l10n.catTravel,
    'other' => l10n.catOther,
    _ => canonical,
  };
}