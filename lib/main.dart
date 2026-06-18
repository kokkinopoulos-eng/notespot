import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/app_theme.dart';
import 'services/db_service.dart';
import 'services/notification_service.dart';
import 'l10n/app_localizations.dart';
import 'screens/home/home_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/splash/splash_screen.dart';
import 'screens/splash/terms_screen.dart';
import 'services/premium_service.dart';

final rootMessengerKey = GlobalKey<ScaffoldMessengerState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PremiumService.instance.init();
  await NotificationService.instance.init();
  await DbService.instance.purgeExpired();
  final prefs = await SharedPreferences.getInstance();
  runApp(NoteSpotApp(initialLocale: prefs.getString('locale')));
}

class NoteSpotApp extends StatefulWidget {
  const NoteSpotApp({super.key, this.initialLocale});
  final String? initialLocale;

  static NoteSpotAppState of(BuildContext context) =>
      context.findAncestorStateOfType<NoteSpotAppState>()!;

  @override
  State<NoteSpotApp> createState() => NoteSpotAppState();
}

class NoteSpotAppState extends State<NoteSpotApp> {
  Locale? _locale;
  Locale? get locale => _locale;
  bool _onboardingDone = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialLocale != null) {
      _locale = Locale(widget.initialLocale!);
      _onboardingDone = true;
    } else {
      _locale = const Locale('en');
    }
  }

  Future<void> setLocale(Locale locale) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('locale', locale.languageCode);
    setState(() {
      _locale = locale;
      _onboardingDone = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      scaffoldMessengerKey: rootMessengerKey,
      title: 'NoteSpot',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      locale: _locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: SplashScreen(
        next: TermsGate(
          next: _onboardingDone
              ? const HomeScreen()
              : const OnboardingScreen(),
        ),
      ),
    );
  }
}