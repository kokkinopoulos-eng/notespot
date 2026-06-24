import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_el.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('el'),
    Locale('en'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'SpotNote AI'**
  String get appTitle;

  /// No description provided for @tagline.
  ///
  /// In en, this message translates to:
  /// **'Capture anything. Find everything.'**
  String get tagline;

  /// No description provided for @chooseLanguage.
  ///
  /// In en, this message translates to:
  /// **'Choose language'**
  String get chooseLanguage;

  /// No description provided for @notesTab.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get notesTab;

  /// No description provided for @searchTab.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get searchTab;

  /// No description provided for @settingsTab.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTab;

  /// No description provided for @noNotesYet.
  ///
  /// In en, this message translates to:
  /// **'No notes yet'**
  String get noNotesYet;

  /// No description provided for @captureHint.
  ///
  /// In en, this message translates to:
  /// **'Tap + for your first note'**
  String get captureHint;

  /// No description provided for @photoNote.
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get photoNote;

  /// No description provided for @voiceNote.
  ///
  /// In en, this message translates to:
  /// **'Voice'**
  String get voiceNote;

  /// No description provided for @handwritingNote.
  ///
  /// In en, this message translates to:
  /// **'Handwriting'**
  String get handwritingNote;

  /// No description provided for @textNote.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get textNote;

  /// No description provided for @newNote.
  ///
  /// In en, this message translates to:
  /// **'New note'**
  String get newNote;

  /// No description provided for @titleLabel.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get titleLabel;

  /// No description provided for @contentLabel.
  ///
  /// In en, this message translates to:
  /// **'Content'**
  String get contentLabel;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @comingSoon.
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get comingSoon;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search your notes...'**
  String get searchHint;

  /// No description provided for @noResults.
  ///
  /// In en, this message translates to:
  /// **'No results'**
  String get noResults;

  /// No description provided for @listening.
  ///
  /// In en, this message translates to:
  /// **'Listening...'**
  String get listening;

  /// No description provided for @tapToRecord.
  ///
  /// In en, this message translates to:
  /// **'Tap the mic to start'**
  String get tapToRecord;

  /// No description provided for @speechUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Speech recognition unavailable'**
  String get speechUnavailable;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languageGreek.
  ///
  /// In en, this message translates to:
  /// **'Ελληνικά'**
  String get languageGreek;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @aiProvider.
  ///
  /// In en, this message translates to:
  /// **'AI Provider'**
  String get aiProvider;

  /// No description provided for @aiProviderSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get aiProviderSubtitle;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @version.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get version;

  /// No description provided for @share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @deleteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete note?'**
  String get deleteConfirmTitle;

  /// No description provided for @deleteConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'This cannot be undone.'**
  String get deleteConfirmBody;

  /// No description provided for @apiKey.
  ///
  /// In en, this message translates to:
  /// **'API Key'**
  String get apiKey;

  /// No description provided for @apiKeySet.
  ///
  /// In en, this message translates to:
  /// **'Key saved'**
  String get apiKeySet;

  /// No description provided for @apiKeyDeleted.
  ///
  /// In en, this message translates to:
  /// **'Key deleted'**
  String get apiKeyDeleted;

  /// No description provided for @noApiKey.
  ///
  /// In en, this message translates to:
  /// **'No key set'**
  String get noApiKey;

  /// No description provided for @catReceipts.
  ///
  /// In en, this message translates to:
  /// **'Receipts'**
  String get catReceipts;

  /// No description provided for @catWork.
  ///
  /// In en, this message translates to:
  /// **'Work'**
  String get catWork;

  /// No description provided for @catPersonal.
  ///
  /// In en, this message translates to:
  /// **'Personal'**
  String get catPersonal;

  /// No description provided for @catShopping.
  ///
  /// In en, this message translates to:
  /// **'Shopping'**
  String get catShopping;

  /// No description provided for @catIdeas.
  ///
  /// In en, this message translates to:
  /// **'Ideas'**
  String get catIdeas;

  /// No description provided for @catFood.
  ///
  /// In en, this message translates to:
  /// **'Food'**
  String get catFood;

  /// No description provided for @catTravel.
  ///
  /// In en, this message translates to:
  /// **'Travel'**
  String get catTravel;

  /// No description provided for @catOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get catOther;

  /// No description provided for @allCategories.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get allCategories;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @drawNote.
  ///
  /// In en, this message translates to:
  /// **'Draw / Write'**
  String get drawNote;

  /// No description provided for @stylusOnly.
  ///
  /// In en, this message translates to:
  /// **'Stylus only'**
  String get stylusOnly;

  /// No description provided for @undo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undo;

  /// No description provided for @clearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clearAll;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @yesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get yesterday;

  /// No description provided for @thisWeek.
  ///
  /// In en, this message translates to:
  /// **'This week'**
  String get thisWeek;

  /// No description provided for @earlier.
  ///
  /// In en, this message translates to:
  /// **'Earlier'**
  String get earlier;

  /// No description provided for @noteHint.
  ///
  /// In en, this message translates to:
  /// **'Write something...'**
  String get noteHint;

  /// No description provided for @clearText.
  ///
  /// In en, this message translates to:
  /// **'Clear text'**
  String get clearText;

  /// No description provided for @dictation.
  ///
  /// In en, this message translates to:
  /// **'Dictation'**
  String get dictation;

  /// No description provided for @recordAudio.
  ///
  /// In en, this message translates to:
  /// **'Record audio'**
  String get recordAudio;

  /// No description provided for @premiumTitle.
  ///
  /// In en, this message translates to:
  /// **'SpotNote AI Pro'**
  String get premiumTitle;

  /// No description provided for @premiumDesc.
  ///
  /// In en, this message translates to:
  /// **'Unlock AI auto-tagging, text extraction and audio transcription'**
  String get premiumDesc;

  /// No description provided for @buyPremium.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get buyPremium;

  /// No description provided for @restorePurchases.
  ///
  /// In en, this message translates to:
  /// **'Restore purchases'**
  String get restorePurchases;

  /// No description provided for @purchaseSuccess.
  ///
  /// In en, this message translates to:
  /// **'Premium unlocked!'**
  String get purchaseSuccess;

  /// No description provided for @purchaseError.
  ///
  /// In en, this message translates to:
  /// **'Purchase failed'**
  String get purchaseError;

  /// No description provided for @backupData.
  ///
  /// In en, this message translates to:
  /// **'Backup data'**
  String get backupData;

  /// No description provided for @restoreData.
  ///
  /// In en, this message translates to:
  /// **'Restore data'**
  String get restoreData;

  /// No description provided for @restoreConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Restore?'**
  String get restoreConfirmTitle;

  /// No description provided for @restoreConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Notes from the backup will be merged with your existing notes - nothing is deleted. For duplicates the newer version wins.'**
  String get restoreConfirmBody;

  /// No description provided for @restoreSuccess.
  ///
  /// In en, this message translates to:
  /// **'Restore complete!'**
  String get restoreSuccess;

  /// No description provided for @favorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get favorites;

  /// No description provided for @noFavorites.
  ///
  /// In en, this message translates to:
  /// **'No favorites yet'**
  String get noFavorites;

  /// No description provided for @uploadPhoto.
  ///
  /// In en, this message translates to:
  /// **'Upload photo from gallery'**
  String get uploadPhoto;

  /// No description provided for @aiAssistantTitle.
  ///
  /// In en, this message translates to:
  /// **'✨ AI Assistant'**
  String get aiAssistantTitle;

  /// No description provided for @aiActionGrammarFix.
  ///
  /// In en, this message translates to:
  /// **'Fix spelling/grammar'**
  String get aiActionGrammarFix;

  /// No description provided for @aiActionGrammarFixDesc.
  ///
  /// In en, this message translates to:
  /// **'Fixes errors without changing the meaning'**
  String get aiActionGrammarFixDesc;

  /// No description provided for @aiActionSummarize.
  ///
  /// In en, this message translates to:
  /// **'Summarize'**
  String get aiActionSummarize;

  /// No description provided for @aiActionSummarizeDesc.
  ///
  /// In en, this message translates to:
  /// **'1-2 sentences'**
  String get aiActionSummarizeDesc;

  /// No description provided for @aiActionExpand.
  ///
  /// In en, this message translates to:
  /// **'Expand'**
  String get aiActionExpand;

  /// No description provided for @aiActionExpandDesc.
  ///
  /// In en, this message translates to:
  /// **'Add relevant details'**
  String get aiActionExpandDesc;

  /// No description provided for @aiActionShorten.
  ///
  /// In en, this message translates to:
  /// **'Shorten'**
  String get aiActionShorten;

  /// No description provided for @aiActionShortenDesc.
  ///
  /// In en, this message translates to:
  /// **'About half the length'**
  String get aiActionShortenDesc;

  /// No description provided for @aiActionChangeTone.
  ///
  /// In en, this message translates to:
  /// **'Change tone'**
  String get aiActionChangeTone;

  /// No description provided for @aiActionChangeToneDesc.
  ///
  /// In en, this message translates to:
  /// **'Formal, friendly, professional, humorous'**
  String get aiActionChangeToneDesc;

  /// No description provided for @aiActionParaphrase.
  ///
  /// In en, this message translates to:
  /// **'Paraphrase'**
  String get aiActionParaphrase;

  /// No description provided for @aiActionParaphraseDesc.
  ///
  /// In en, this message translates to:
  /// **'In different words'**
  String get aiActionParaphraseDesc;

  /// No description provided for @aiChooseTone.
  ///
  /// In en, this message translates to:
  /// **'Choose tone'**
  String get aiChooseTone;

  /// No description provided for @aiProcessing.
  ///
  /// In en, this message translates to:
  /// **'Processing...'**
  String get aiProcessing;

  /// No description provided for @aiFailure.
  ///
  /// In en, this message translates to:
  /// **'AI error: {error}'**
  String aiFailure(String error);

  /// No description provided for @aiUnknownError.
  ///
  /// In en, this message translates to:
  /// **'Unknown error.'**
  String get aiUnknownError;

  /// No description provided for @aiNoText.
  ///
  /// In en, this message translates to:
  /// **'No text to edit.'**
  String get aiNoText;

  /// No description provided for @toneFormal.
  ///
  /// In en, this message translates to:
  /// **'Formal'**
  String get toneFormal;

  /// No description provided for @toneFriendly.
  ///
  /// In en, this message translates to:
  /// **'Friendly'**
  String get toneFriendly;

  /// No description provided for @toneProfessional.
  ///
  /// In en, this message translates to:
  /// **'Professional'**
  String get toneProfessional;

  /// No description provided for @toneHumorous.
  ///
  /// In en, this message translates to:
  /// **'Humorous'**
  String get toneHumorous;

  /// No description provided for @aiPreviewTitle.
  ///
  /// In en, this message translates to:
  /// **'✨ Result'**
  String get aiPreviewTitle;

  /// No description provided for @aiRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get aiRetry;

  /// No description provided for @aiAppend.
  ///
  /// In en, this message translates to:
  /// **'Append'**
  String get aiAppend;

  /// No description provided for @aiReplace.
  ///
  /// In en, this message translates to:
  /// **'Replace'**
  String get aiReplace;

  /// No description provided for @aiNoResult.
  ///
  /// In en, this message translates to:
  /// **'Got no result. Try again.'**
  String get aiNoResult;

  /// No description provided for @aiErrorDetail.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String aiErrorDetail(String error);

  /// No description provided for @evaResetTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset Eva?'**
  String get evaResetTitle;

  /// No description provided for @evaResetBody.
  ///
  /// In en, this message translates to:
  /// **'Eva will forget everything it has learned and start over. Your notes will NOT be affected. This action cannot be undone.'**
  String get evaResetBody;

  /// No description provided for @evaResetButton.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get evaResetButton;

  /// No description provided for @evaResetDone.
  ///
  /// In en, this message translates to:
  /// **'Eva has been reset.'**
  String get evaResetDone;

  /// No description provided for @evaRescanTitle.
  ///
  /// In en, this message translates to:
  /// **'Rescan with Eva'**
  String get evaRescanTitle;

  /// No description provided for @evaRescanBody.
  ///
  /// In en, this message translates to:
  /// **'Eva will re-analyse all notes you haven\'t manually locked. It applies its learning to older notes.'**
  String get evaRescanBody;

  /// No description provided for @evaRescanButton.
  ///
  /// In en, this message translates to:
  /// **'Rescan'**
  String get evaRescanButton;

  /// No description provided for @evaRescanNone.
  ///
  /// In en, this message translates to:
  /// **'No notes available to rescan.'**
  String get evaRescanNone;

  /// No description provided for @evaRescanProgress.
  ///
  /// In en, this message translates to:
  /// **'Rescanning...'**
  String get evaRescanProgress;

  /// No description provided for @evaRescanDone.
  ///
  /// In en, this message translates to:
  /// **'Updated {count} notes'**
  String evaRescanDone(int count);

  /// No description provided for @cloudAiToggleTitle.
  ///
  /// In en, this message translates to:
  /// **'Use Cloud AI'**
  String get cloudAiToggleTitle;

  /// No description provided for @cloudAiToggleSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Improves categorisation using your API key'**
  String get cloudAiToggleSubtitle;

  /// No description provided for @archiveSection.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get archiveSection;

  /// No description provided for @archivedNotes.
  ///
  /// In en, this message translates to:
  /// **'Archived notes'**
  String get archivedNotes;

  /// No description provided for @archivedNotesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'View and restore archived notes'**
  String get archivedNotesSubtitle;

  /// No description provided for @evaRescanAllTitle.
  ///
  /// In en, this message translates to:
  /// **'Rescan all with Eva'**
  String get evaRescanAllTitle;

  /// No description provided for @evaRescanAllSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Apply Eva\'s learning to notes without a manual category'**
  String get evaRescanAllSubtitle;

  /// No description provided for @evaResetListTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset Eva'**
  String get evaResetListTitle;

  /// No description provided for @evaResetListSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Delete what Eva has learned. Your notes are unaffected.'**
  String get evaResetListSubtitle;

  /// No description provided for @helpTitle.
  ///
  /// In en, this message translates to:
  /// **'User guide'**
  String get helpTitle;

  /// No description provided for @helpSecIntroTitle.
  ///
  /// In en, this message translates to:
  /// **'What is SpotNote AI?'**
  String get helpSecIntroTitle;

  /// No description provided for @helpSecIntroBody.
  ///
  /// In en, this message translates to:
  /// **'SpotNote AI captures text, drawings, photos, voice memos and checklists, and organises them automatically on your device — fully offline. Tap + to create your first note and choose a type.'**
  String get helpSecIntroBody;

  /// No description provided for @helpSecEditorTitle.
  ///
  /// In en, this message translates to:
  /// **'Text & Draw editor'**
  String get helpSecEditorTitle;

  /// No description provided for @helpSecEditorBody.
  ///
  /// In en, this message translates to:
  /// **'The editor has two panes: text at the top, drawing canvas at the bottom. Drag the divider bar to resize them, or tap the expand buttons to go full-screen. Supports finger and S Pen (automatically switches to stylus-only when S Pen is detected).'**
  String get helpSecEditorBody;

  /// No description provided for @helpSecHandwritingTitle.
  ///
  /// In en, this message translates to:
  /// **'Handwriting recognition'**
  String get helpSecHandwritingTitle;

  /// No description provided for @helpSecHandwritingBody.
  ///
  /// In en, this message translates to:
  /// **'In the drawing pane, tap the text icon to convert your handwriting to typed text. For maths, write an expression (e.g. 7 + 5) and tap the ∫ button — the result is inserted as handwritten text. Supported operators: + − × ÷'**
  String get helpSecHandwritingBody;

  /// No description provided for @helpSecEvaTitle.
  ///
  /// In en, this message translates to:
  /// **'Eva — smart categorisation'**
  String get helpSecEvaTitle;

  /// No description provided for @helpSecEvaBody.
  ///
  /// In en, this message translates to:
  /// **'Eva is NoteSpot\'s on-device AI that suggests a category for each note. Tap her purple avatar on the note screen to show a speech bubble with a short intro.\n\nShe learns from your corrections: when you change a category, Eva remembers the pattern. Settings → Rescan Eva to apply her knowledge to existing notes.'**
  String get helpSecEvaBody;

  /// No description provided for @helpSecFiltersTitle.
  ///
  /// In en, this message translates to:
  /// **'Filters & organisation'**
  String get helpSecFiltersTitle;

  /// No description provided for @helpSecFiltersBody.
  ///
  /// In en, this message translates to:
  /// **'On the home screen: filter by category (chips), colour (dots), or favourites (star tab).\n\nGestures: swipe a note RIGHT to delete (with confirmation), swipe LEFT to archive (with undo SnackBar). In Archive: swipe right for permanent delete.\n\nPin notes to keep them at the top. Archiving hides a note from the main list (Settings → Archive). Set a lifetime to auto-delete after a chosen period.'**
  String get helpSecFiltersBody;

  /// No description provided for @helpSecProTitle.
  ///
  /// In en, this message translates to:
  /// **'Pro features'**
  String get helpSecProTitle;

  /// No description provided for @helpSecProBody.
  ///
  /// In en, this message translates to:
  /// **'AI Assistant (✨ button in the editor): 6 actions — fix grammar, summarize, expand, shorten, change tone, paraphrase. Preview before applying.\n\nSmart Voice (mic icon in the + menu): dictate and the cloud AI auto-structures the note as plain text, a checklist or a reminder.\n\nBYOK: all Pro features use your own cloud AI key (Anthropic / OpenAI / Google) from Settings → AI.'**
  String get helpSecProBody;

  /// No description provided for @helpSecBackupTitle.
  ///
  /// In en, this message translates to:
  /// **'Backup, share & OCR'**
  String get helpSecBackupTitle;

  /// No description provided for @helpSecBackupBody.
  ///
  /// In en, this message translates to:
  /// **'Settings → Backup data exports all notes to a file you can restore later. Share any note to other apps from the detail screen. Photo notes support OCR: text inside the image is indexed and searchable.'**
  String get helpSecBackupBody;

  /// No description provided for @termsTitle.
  ///
  /// In en, this message translates to:
  /// **'Terms of use'**
  String get termsTitle;

  /// No description provided for @termsBody.
  ///
  /// In en, this message translates to:
  /// **'Your notes are stored locally on your device. You are responsible for backups. The app is provided \"as is\". Full terms: kokkinopoulos-eng.github.io/notespot-legal'**
  String get termsBody;

  /// No description provided for @privacyTitle.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyTitle;

  /// No description provided for @privacySubtitlePro.
  ///
  /// In en, this message translates to:
  /// **'Local + Cloud AI'**
  String get privacySubtitlePro;

  /// No description provided for @privacySubtitleFree.
  ///
  /// In en, this message translates to:
  /// **'100% offline'**
  String get privacySubtitleFree;

  /// No description provided for @inkNoStrokes.
  ///
  /// In en, this message translates to:
  /// **'No ink on this page'**
  String get inkNoStrokes;

  /// No description provided for @inkModelGreekDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading Greek model... (one time only)'**
  String get inkModelGreekDownloading;

  /// No description provided for @inkTextNotRecognized.
  ///
  /// In en, this message translates to:
  /// **'Text not recognized — try clearer handwriting'**
  String get inkTextNotRecognized;

  /// No description provided for @inkChooseText.
  ///
  /// In en, this message translates to:
  /// **'Choose text'**
  String get inkChooseText;

  /// No description provided for @inkMathModelDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading recognition model... (one time only)'**
  String get inkMathModelDownloading;

  /// No description provided for @inkMathNotRecognized.
  ///
  /// In en, this message translates to:
  /// **'Math not recognized — try clearer writing'**
  String get inkMathNotRecognized;

  /// No description provided for @inkMathNoExpression.
  ///
  /// In en, this message translates to:
  /// **'Recognized: \"{expr}\" — no math found'**
  String inkMathNoExpression(String expr);

  /// No description provided for @inkInsertInText.
  ///
  /// In en, this message translates to:
  /// **'Insert in text'**
  String get inkInsertInText;

  /// No description provided for @inkRecognize.
  ///
  /// In en, this message translates to:
  /// **'Recognize'**
  String get inkRecognize;

  /// No description provided for @inkMathAction.
  ///
  /// In en, this message translates to:
  /// **'Recognize math'**
  String get inkMathAction;

  /// No description provided for @inkTextAction.
  ///
  /// In en, this message translates to:
  /// **'Convert to text'**
  String get inkTextAction;

  /// No description provided for @restoreSplit.
  ///
  /// In en, this message translates to:
  /// **'Restore split'**
  String get restoreSplit;

  /// No description provided for @maximizeText.
  ///
  /// In en, this message translates to:
  /// **'Maximize text'**
  String get maximizeText;

  /// No description provided for @maximizeInk.
  ///
  /// In en, this message translates to:
  /// **'Maximize ink'**
  String get maximizeInk;

  /// No description provided for @smartVoiceTitle.
  ///
  /// In en, this message translates to:
  /// **'Smart Voice'**
  String get smartVoiceTitle;

  /// No description provided for @noteTypeTextDraw.
  ///
  /// In en, this message translates to:
  /// **'Text / Draw'**
  String get noteTypeTextDraw;

  /// No description provided for @noteTypeFromGallery.
  ///
  /// In en, this message translates to:
  /// **'From gallery'**
  String get noteTypeFromGallery;

  /// No description provided for @noteTypeVoice.
  ///
  /// In en, this message translates to:
  /// **'Voice'**
  String get noteTypeVoice;

  /// No description provided for @noteTypeChecklist.
  ///
  /// In en, this message translates to:
  /// **'Checklist'**
  String get noteTypeChecklist;

  /// No description provided for @archivedNotesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No archived notes'**
  String get archivedNotesEmpty;

  /// No description provided for @noteTypeTextDrawSub.
  ///
  /// In en, this message translates to:
  /// **'Tap for text and drawing'**
  String get noteTypeTextDrawSub;

  /// No description provided for @smartVoiceSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Voice → AI structured note'**
  String get smartVoiceSubtitle;

  /// No description provided for @photoSpotTitle.
  ///
  /// In en, this message translates to:
  /// **'Photo + AI'**
  String get photoSpotTitle;

  /// No description provided for @photoSpotSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Auto AI description'**
  String get photoSpotSubtitle;

  /// No description provided for @trashTitle.
  ///
  /// In en, this message translates to:
  /// **'Recycle Bin'**
  String get trashTitle;

  /// No description provided for @trashSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Deleted notes — removed after 30 days'**
  String get trashSubtitle;

  /// No description provided for @trashRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get trashRestore;

  /// No description provided for @trashDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get trashDelete;

  /// No description provided for @trashExpiry.
  ///
  /// In en, this message translates to:
  /// **'Notes are permanently deleted after 30 days.'**
  String get trashExpiry;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['el', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'el':
      return AppLocalizationsEl();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
