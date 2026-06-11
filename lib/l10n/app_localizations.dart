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
  /// **'NoteSpot'**
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
  /// **'NoteSpot Premium'**
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
  /// **'This will replace all your current notes. Are you sure?'**
  String get restoreConfirmBody;

  /// No description provided for @restoreSuccess.
  ///
  /// In en, this message translates to:
  /// **'Restore successful! Please restart the app.'**
  String get restoreSuccess;
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
