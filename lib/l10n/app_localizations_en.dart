// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'NoteSpot';

  @override
  String get tagline => 'Capture anything. Find everything.';

  @override
  String get chooseLanguage => 'Choose your language';

  @override
  String get notesTab => 'Notes';

  @override
  String get searchTab => 'Search';

  @override
  String get settingsTab => 'Settings';

  @override
  String get noNotesYet => 'No notes yet';

  @override
  String get captureHint => 'Tap + to capture your first note';

  @override
  String get photoNote => 'Photo';

  @override
  String get voiceNote => 'Voice memo';

  @override
  String get handwritingNote => 'Handwriting';

  @override
  String get textNote => 'Text';

  @override
  String get newNote => 'New note';

  @override
  String get titleLabel => 'Title';

  @override
  String get contentLabel => 'Content';

  @override
  String get save => 'Save';

  @override
  String get cancel => 'Cancel';

  @override
  String get comingSoon => 'Coming soon';

  @override
  String get searchHint => 'Search your notes...';

  @override
  String get noResults => 'No results';
}
