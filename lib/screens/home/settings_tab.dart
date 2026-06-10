import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../main.dart';

class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final currentLocale = NoteSpotApp.of(context).locale;

    return ListView(
      children: [
        _SectionHeader(title: l10n.language),
        ListTile(
          leading: const Icon(Icons.language),
          title: Text(l10n.language),
          subtitle: Text(
            currentLocale?.languageCode == 'en'
                ? l10n.languageEnglish
                : l10n.languageGreek,
          ),
          onTap: () => _showLanguageDialog(context, l10n, currentLocale),
        ),
        const Divider(),
        _SectionHeader(title: l10n.aiProvider),
        ListTile(
          leading: const Icon(Icons.psychology_outlined),
          title: Text(l10n.aiProvider),
          subtitle: Text(l10n.aiProviderSubtitle),
          enabled: false,
        ),
        const Divider(),
        _SectionHeader(title: l10n.about),
        ListTile(
          leading: const Icon(Icons.info_outline),
          title: Text(l10n.version),
          subtitle: const Text('1.0.0'),
        ),
      ],
    );
  }

  void _showLanguageDialog(
    BuildContext context,
    AppLocalizations l10n,
    Locale? currentLocale,
  ) {
    showDialog<void>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(l10n.chooseLanguage),
        children: [
          SimpleDialogOption(
            onPressed: () {
              NoteSpotApp.of(ctx).setLocale(const Locale('el'));
              Navigator.pop(ctx);
            },
            child: Row(
              children: [
                Icon(
                  Icons.check,
                  color: (currentLocale?.languageCode ?? 'el') == 'el'
                      ? Theme.of(ctx).colorScheme.primary
                      : Colors.transparent,
                ),
                const SizedBox(width: 8),
                Text(l10n.languageGreek),
              ],
            ),
          ),
          SimpleDialogOption(
            onPressed: () {
              NoteSpotApp.of(ctx).setLocale(const Locale('en'));
              Navigator.pop(ctx);
            },
            child: Row(
              children: [
                Icon(
                  Icons.check,
                  color: currentLocale?.languageCode == 'en'
                      ? Theme.of(ctx).colorScheme.primary
                      : Colors.transparent,
                ),
                const SizedBox(width: 8),
                Text(l10n.languageEnglish),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}