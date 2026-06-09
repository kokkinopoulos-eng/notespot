import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../main.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.lightbulb_outline,
                  size: 96, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 16),
              Text('NoteSpot',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineLarge),
              const SizedBox(height: 8),
              Text(l10n.tagline,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: 48),
              Text(l10n.chooseLanguage, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () =>
                    NoteSpotApp.of(context).setLocale(const Locale('el')),
                child: const Text(
                    '\u0395\u03bb\u03bb\u03b7\u03bd\u03b9\u03ba\u03ac'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () =>
                    NoteSpotApp.of(context).setLocale(const Locale('en')),
                child: const Text('English'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}