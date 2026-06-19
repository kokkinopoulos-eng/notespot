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
  String get chooseLanguage => 'Choose language';

  @override
  String get notesTab => 'Notes';

  @override
  String get searchTab => 'Search';

  @override
  String get settingsTab => 'Settings';

  @override
  String get noNotesYet => 'No notes yet';

  @override
  String get captureHint => 'Tap + for your first note';

  @override
  String get photoNote => 'Photo';

  @override
  String get voiceNote => 'Voice';

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

  @override
  String get listening => 'Listening...';

  @override
  String get tapToRecord => 'Tap the mic to start';

  @override
  String get speechUnavailable => 'Speech recognition unavailable';

  @override
  String get language => 'Language';

  @override
  String get languageGreek => 'Ελληνικά';

  @override
  String get languageEnglish => 'English';

  @override
  String get aiProvider => 'AI Provider';

  @override
  String get aiProviderSubtitle => 'Coming soon';

  @override
  String get about => 'About';

  @override
  String get version => 'Version';

  @override
  String get share => 'Share';

  @override
  String get delete => 'Delete';

  @override
  String get deleteConfirmTitle => 'Delete note?';

  @override
  String get deleteConfirmBody => 'This cannot be undone.';

  @override
  String get apiKey => 'API Key';

  @override
  String get apiKeySet => 'Key saved';

  @override
  String get apiKeyDeleted => 'Key deleted';

  @override
  String get noApiKey => 'No key set';

  @override
  String get catReceipts => 'Receipts';

  @override
  String get catWork => 'Work';

  @override
  String get catPersonal => 'Personal';

  @override
  String get catShopping => 'Shopping';

  @override
  String get catIdeas => 'Ideas';

  @override
  String get catFood => 'Food';

  @override
  String get catTravel => 'Travel';

  @override
  String get catOther => 'Other';

  @override
  String get allCategories => 'All';

  @override
  String get edit => 'Edit';

  @override
  String get drawNote => 'Draw / Write';

  @override
  String get stylusOnly => 'Stylus only';

  @override
  String get undo => 'Undo';

  @override
  String get clearAll => 'Clear';

  @override
  String get today => 'Today';

  @override
  String get yesterday => 'Yesterday';

  @override
  String get thisWeek => 'This week';

  @override
  String get earlier => 'Earlier';

  @override
  String get noteHint => 'Write something...';

  @override
  String get clearText => 'Clear text';

  @override
  String get dictation => 'Dictation';

  @override
  String get recordAudio => 'Record audio';

  @override
  String get premiumTitle => 'NoteSpot Premium';

  @override
  String get premiumDesc =>
      'Unlock AI auto-tagging, text extraction and audio transcription';

  @override
  String get buyPremium => 'Unlock';

  @override
  String get restorePurchases => 'Restore purchases';

  @override
  String get purchaseSuccess => 'Premium unlocked!';

  @override
  String get purchaseError => 'Purchase failed';

  @override
  String get backupData => 'Backup data';

  @override
  String get restoreData => 'Restore data';

  @override
  String get restoreConfirmTitle => 'Restore?';

  @override
  String get restoreConfirmBody =>
      'Notes from the backup will be merged with your existing notes - nothing is deleted. For duplicates the newer version wins.';

  @override
  String get restoreSuccess => 'Restore complete!';

  @override
  String get favorites => 'Favorites';

  @override
  String get noFavorites => 'No favorites yet';

  @override
  String get uploadPhoto => 'Upload photo from gallery';

  @override
  String get aiAssistantTitle => '✨ AI Assistant';

  @override
  String get aiActionGrammarFix => 'Fix spelling/grammar';

  @override
  String get aiActionGrammarFixDesc =>
      'Fixes errors without changing the meaning';

  @override
  String get aiActionSummarize => 'Summarize';

  @override
  String get aiActionSummarizeDesc => '1-2 sentences';

  @override
  String get aiActionExpand => 'Expand';

  @override
  String get aiActionExpandDesc => 'Add relevant details';

  @override
  String get aiActionShorten => 'Shorten';

  @override
  String get aiActionShortenDesc => 'About half the length';

  @override
  String get aiActionChangeTone => 'Change tone';

  @override
  String get aiActionChangeToneDesc =>
      'Formal, friendly, professional, humorous';

  @override
  String get aiActionParaphrase => 'Paraphrase';

  @override
  String get aiActionParaphraseDesc => 'In different words';

  @override
  String get aiChooseTone => 'Choose tone';

  @override
  String get aiProcessing => 'Processing...';

  @override
  String aiFailure(String error) {
    return 'AI error: $error';
  }

  @override
  String get aiUnknownError => 'Unknown error.';

  @override
  String get aiNoText => 'No text to edit.';

  @override
  String get toneFormal => 'Formal';

  @override
  String get toneFriendly => 'Friendly';

  @override
  String get toneProfessional => 'Professional';

  @override
  String get toneHumorous => 'Humorous';

  @override
  String get aiPreviewTitle => '✨ Result';

  @override
  String get aiRetry => 'Retry';

  @override
  String get aiAppend => 'Append';

  @override
  String get aiReplace => 'Replace';

  @override
  String get aiNoResult => 'Got no result. Try again.';

  @override
  String aiErrorDetail(String error) {
    return 'Error: $error';
  }

  @override
  String get evaResetTitle => 'Reset Eva?';

  @override
  String get evaResetBody =>
      'Eva will forget everything it has learned and start over. Your notes will NOT be affected. This action cannot be undone.';

  @override
  String get evaResetButton => 'Reset';

  @override
  String get evaResetDone => 'Eva has been reset.';

  @override
  String get evaRescanTitle => 'Rescan with Eva';

  @override
  String get evaRescanBody =>
      'Eva will re-analyse all notes you haven\'t manually locked. It applies its learning to older notes.';

  @override
  String get evaRescanButton => 'Rescan';

  @override
  String get evaRescanNone => 'No notes available to rescan.';

  @override
  String get evaRescanProgress => 'Rescanning...';

  @override
  String evaRescanDone(int count) {
    return 'Updated $count notes';
  }

  @override
  String get cloudAiToggleTitle => 'Use Cloud AI';

  @override
  String get cloudAiToggleSubtitle =>
      'Improves categorisation using your API key';

  @override
  String get archiveSection => 'Archive';

  @override
  String get archivedNotes => 'Archived notes';

  @override
  String get archivedNotesSubtitle => 'View and restore archived notes';

  @override
  String get evaRescanAllTitle => 'Rescan all with Eva';

  @override
  String get evaRescanAllSubtitle =>
      'Apply Eva\'s learning to notes without a manual category';

  @override
  String get evaResetListTitle => 'Reset Eva';

  @override
  String get evaResetListSubtitle =>
      'Delete what Eva has learned. Your notes are unaffected.';

  @override
  String get helpTitle => 'User guide';

  @override
  String get helpSecIntroTitle => 'What is NoteSpot?';

  @override
  String get helpSecIntroBody =>
      'NoteSpot captures text, drawings, photos, voice memos and checklists, and organises them automatically on your device — fully offline. Tap + to create your first note and choose a type.';

  @override
  String get helpSecEditorTitle => 'Text & Draw editor';

  @override
  String get helpSecEditorBody =>
      'The editor has two panes: text at the top, drawing canvas at the bottom. Drag the divider bar to resize them, or tap the expand buttons to go full-screen. Supports finger and S Pen (automatically switches to stylus-only when S Pen is detected).';

  @override
  String get helpSecHandwritingTitle => 'Handwriting recognition';

  @override
  String get helpSecHandwritingBody =>
      'In the drawing pane, tap the text icon to convert your handwriting to typed text. For maths, write an expression (e.g. 7 + 5) and tap the ∫ button — the result is inserted as handwritten text. Supported operators: + − × ÷';

  @override
  String get helpSecEvaTitle => 'Eva — smart categorisation';

  @override
  String get helpSecEvaBody =>
      'Eva is NoteSpot\'s on-device AI that suggests a category for each note. It learns from your corrections: when you change a category, Eva remembers and applies that pattern to future notes. Settings → Rescan to apply Eva\'s learning to older notes.';

  @override
  String get helpSecFiltersTitle => 'Filters & organisation';

  @override
  String get helpSecFiltersBody =>
      'On the home screen: filter by category (chips), colour (dots), or favourites (star tab). Pin notes to keep them at the top. Archive a note to hide it from the main list (Settings → Archive to view). Set a lifetime to auto-delete a note after a chosen period.';

  @override
  String get helpSecProTitle => 'Pro features';

  @override
  String get helpSecProBody =>
      'AI Assistant (✨ button in the editor): fix grammar, summarise, expand, shorten, change tone or paraphrase using your cloud AI key.\nSmart Voice (mic icon on home): dictate a note and optionally have AI structure it into a proper note with title, body and tags.';

  @override
  String get helpSecBackupTitle => 'Backup, share & OCR';

  @override
  String get helpSecBackupBody =>
      'Settings → Backup data exports all notes to a file you can restore later. Share any note to other apps from the detail screen. Photo notes support OCR: text inside the image is indexed and searchable.';

  @override
  String get termsTitle => 'Terms of use';

  @override
  String get termsBody =>
      'Your notes are stored locally on your device. You are responsible for backups. The app is provided \"as is\". Full terms: kokkinopoulos-eng.github.io/notespot-legal';

  @override
  String get privacyTitle => 'Privacy Policy';

  @override
  String get privacySubtitlePro => 'Local + Cloud AI';

  @override
  String get privacySubtitleFree => '100% offline';

  @override
  String get inkNoStrokes => 'No ink on this page';

  @override
  String get inkModelGreekDownloading =>
      'Downloading Greek model... (one time only)';

  @override
  String get inkTextNotRecognized =>
      'Text not recognized — try clearer handwriting';

  @override
  String get inkChooseText => 'Choose text';

  @override
  String get inkMathModelDownloading =>
      'Downloading recognition model... (one time only)';

  @override
  String get inkMathNotRecognized =>
      'Math not recognized — try clearer writing';

  @override
  String inkMathNoExpression(String expr) {
    return 'Recognized: \"$expr\" — no math found';
  }

  @override
  String get inkInsertInText => 'Insert in text';

  @override
  String get inkRecognize => 'Recognize';

  @override
  String get inkMathAction => 'Recognize math';

  @override
  String get inkTextAction => 'Convert to text';

  @override
  String get restoreSplit => 'Restore split';

  @override
  String get maximizeText => 'Maximize text';

  @override
  String get maximizeInk => 'Maximize ink';

  @override
  String get noteTypeTextDraw => 'Text / Draw';

  @override
  String get noteTypeFromGallery => 'From gallery';

  @override
  String get noteTypeVoice => 'Voice';

  @override
  String get noteTypeChecklist => 'Checklist';

  @override
  String get archivedNotesEmpty => 'No archived notes';
}
