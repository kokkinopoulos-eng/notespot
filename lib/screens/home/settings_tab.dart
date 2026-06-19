import 'package:flutter/material.dart';
import '../../core/feature_flags.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../l10n/app_localizations.dart';
import '../../main.dart';
import '../../models/ai_provider.dart';
import '../../services/eva_service.dart';
import '../../services/ai_settings_service.dart';
import '../../services/backup_service.dart';
import '../../services/db_service.dart';
import '../../services/local_analysis_service.dart';
import 'archived_notes_screen.dart';
import '../help_screen.dart';

// --- Dialog result types ---
enum _ApiKeyAction { save, delete, cancel }

class _ApiKeyDialogResult {
  const _ApiKeyDialogResult(this.action, [this.key]);
  final _ApiKeyAction action;
  final String? key;
}

// --- Provider picker dialog ---
class _ProviderPickerDialog extends StatelessWidget {
  const _ProviderPickerDialog({required this.current});
  final AiProvider current;

  @override
  Widget build(BuildContext context) {
    return SimpleDialog(
      title: Text(AppLocalizations.of(context).aiProvider),
      children: AiProvider.values
          .map((p) => RadioListTile<AiProvider>(
                value: p,
                groupValue: current,
                title: Text(p.displayName),
                onChanged: (v) => Navigator.pop(context, v),
              ))
          .toList(),
    );
  }
}

// --- API Key dialog ---
class _ApiKeyDialog extends StatefulWidget {
  const _ApiKeyDialog({
    required this.providerName,
    required this.providerHint,
    required this.hasExistingKey,
  });
  final String providerName;
  final String providerHint;
  final bool hasExistingKey;

  @override
  State<_ApiKeyDialog> createState() => _ApiKeyDialogState();
}

class _ApiKeyDialogState extends State<_ApiKeyDialog> {
  final _ctrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.apiKey),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.providerName,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  )),
          Text(widget.providerHint,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  )),
          const SizedBox(height: 12),
          TextField(
            controller: _ctrl,
            obscureText: _obscure,
            autofocus: true,
            decoration: InputDecoration(
              labelText: l10n.apiKey,
              helperText: widget.hasExistingKey ? l10n.apiKeySet : null,
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
        ],
      ),
      actions: [
        if (widget.hasExistingKey)
          TextButton(
            style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(
                context, const _ApiKeyDialogResult(_ApiKeyAction.delete)),
            child: Text(l10n.delete),
          ),
        TextButton(
          onPressed: () => Navigator.pop(
              context, const _ApiKeyDialogResult(_ApiKeyAction.cancel)),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () {
            final val = _ctrl.text.trim();
            if (val.isEmpty) return;
            Navigator.pop(
                context, _ApiKeyDialogResult(_ApiKeyAction.save, val));
          },
          child: Text(l10n.save),
        ),
      ],
    );
  }
}

// --- SettingsTab ---
class SettingsTab extends StatefulWidget {
  final VoidCallback? onBackToHome;

  const SettingsTab({super.key, this.onBackToHome});

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  AiProvider _selectedProvider = AiProvider.gemini;
  String? _maskedKey;
  bool _hasKey = false;
  bool _aiEnabled = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final svc = AiSettingsService.instance;
    final provider = await svc.getSelectedProvider();
    final key = await svc.getApiKey(provider);
    final hasKey = key != null && key.trim().isNotEmpty;
    final masked = hasKey && key.length >= 4
        ? '****${key.substring(key.length - 4)}'
        : null;
    final enabled = await svc.aiEnabled;
    if (!mounted) return;
    setState(() {
      _selectedProvider = provider;
      _hasKey = hasKey;
      _maskedKey = masked;
      _aiEnabled = enabled;
    });
  }

  Future<void> _openProviderDialog() async {
    final picked = await showDialog<AiProvider>(
      context: context,
      builder: (_) => _ProviderPickerDialog(current: _selectedProvider),
    );
    if (picked == null || !mounted) return;
    await AiSettingsService.instance.setSelectedProvider(picked);
    if (!mounted) return;
    await _reload();
  }

  Future<void> _openApiKeyDialog() async {
    final svc = AiSettingsService.instance;
    final provider = _selectedProvider;
    final existing = await svc.getApiKey(provider);
    if (!mounted) return;
    final result = await showDialog<_ApiKeyDialogResult>(
      context: context,
      builder: (_) => _ApiKeyDialog(
        providerName: provider.displayName,
        providerHint: provider.keyHint,
        hasExistingKey: existing != null && existing.trim().isNotEmpty,
      ),
    );
    if (result == null || !mounted) return;
    final l10n = AppLocalizations.of(context);
    if (result.action == _ApiKeyAction.save && result.key != null) {
      await svc.setApiKey(provider, result.key!);
      if (!mounted) return;
      await _reload();
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.apiKeySet)));
    } else if (result.action == _ApiKeyAction.delete) {
      await svc.deleteApiKey(provider);
      if (!mounted) return;
      await _reload();
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.apiKeyDeleted)));
    }
  }

  Future<void> _resetEva() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded,
            color: Color(0xFFC62828), size: 36),
        title: Text(l10n.evaResetTitle),
        content: Text(l10n.evaResetBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFC62828)),
            child: Text(l10n.evaResetButton),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await EvaService.instance.reset();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.evaResetDone)),
    );
  }
  
  Future<void> _rescanAll() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.evaRescanTitle),
        content: Text(l10n.evaRescanBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.evaRescanButton),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final notes = await DbService.instance.getRescannable();
    final total = notes.length;

    if (total == 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.evaRescanNone)),
      );
      return;
    }

    final progressNotifier = ValueNotifier<int>(0);
    if (!mounted) return;

    // Non-dismissable progress dialog.
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.evaRescanProgress),
        content: ValueListenableBuilder<int>(
          valueListenable: progressNotifier,
          builder: (_, done, child) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LinearProgressIndicator(
                  value: total > 0 ? done / total : 0),
              const SizedBox(height: 12),
              Text('$done / $total'),
            ],
          ),
        ),
      ),
    );

    int updated = 0;
    for (final note in notes) {
      final searchText = '${note.content} ${note.ocrText}'.trim();
      final result =
          await LocalAnalysisService.instance.classifyText(searchText);
      if (result.category.isNotEmpty &&
          result.category != note.category) {
        await DbService.instance.update(note.copyWith(
          category: result.category,
          tags: result.tags,
          updatedAt: DateTime.now(),
        ));
        updated++;
      }
      progressNotifier.value++;
    }

    if (!mounted) return;
    Navigator.of(context).pop(); // close progress dialog
    progressNotifier.dispose();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.evaRescanDone(updated))),
    );
  }

  void _openLanguageDialog() {
    final currentLocale = NoteSpotApp.of(context).locale;
    final l10n = AppLocalizations.of(context);
    showDialog<void>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(l10n.chooseLanguage),
        children: [
          SimpleDialogOption(
            onPressed: () {
              NoteSpotApp.of(context).setLocale(const Locale('el'));
              Navigator.pop(ctx);
            },
            child: Row(children: [
              Icon(Icons.check,
                  color: (currentLocale?.languageCode ?? 'el') == 'el'
                      ? Theme.of(ctx).colorScheme.primary
                      : Colors.transparent),
              const SizedBox(width: 8),
              Text(l10n.languageGreek),
            ]),
          ),
          SimpleDialogOption(
            onPressed: () {
              NoteSpotApp.of(context).setLocale(const Locale('en'));
              Navigator.pop(ctx);
            },
            child: Row(children: [
              Icon(Icons.check,
                  color: currentLocale?.languageCode == 'en'
                      ? Theme.of(ctx).colorScheme.primary
                      : Colors.transparent),
              const SizedBox(width: 8),
              Text(l10n.languageEnglish),
            ]),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final currentLocale = NoteSpotApp.of(context).locale;

    return ListView(
      children: [
        if (widget.onBackToHome != null)
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 4),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: widget.onBackToHome,
                ),
                Text(
                  l10n.settingsTab,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
          ),
        // Language section
        _SectionHeader(title: l10n.language),
        ListTile(
          leading: const Icon(Icons.language),
          title: Text(l10n.language),
          subtitle: Text(
            currentLocale?.languageCode == 'en'
                ? l10n.languageEnglish
                : l10n.languageGreek,
          ),
          onTap: _openLanguageDialog,
        ),
        const Divider(),

        // AI section — only visible in pro builds (kCloudAiEnabled = true)
        if (kCloudAiEnabled) ...[
          _SectionHeader(title: l10n.aiProvider),
          SwitchListTile(
            secondary: const Icon(Icons.cloud_outlined),
            title: Text(l10n.cloudAiToggleTitle),
            subtitle: Text(l10n.cloudAiToggleSubtitle),
            value: _aiEnabled,
            onChanged: (v) async {
              await AiSettingsService.instance.setAiEnabled(v);
              await _reload();
            },
          ),
          ListTile(
            leading: const Icon(Icons.psychology_outlined),
            title: Text(l10n.aiProvider),
            subtitle: Text(_selectedProvider.displayName),
            trailing: Icon(
              _hasKey ? Icons.check_circle : Icons.key_off,
              color: _hasKey
                  ? Colors.green
                  : Theme.of(context).colorScheme.outline,
            ),
            onTap: _openProviderDialog,
          ),
          ListTile(
            leading: const Icon(Icons.key_outlined),
            title: Text(l10n.apiKey),
            subtitle: Text(_maskedKey ?? l10n.noApiKey),
            onTap: _openApiKeyDialog,
          ),
          const Divider(),
        ],

        // Archive section
        const Divider(),
        _SectionHeader(title: l10n.archiveSection),
        ListTile(
          leading: const Icon(Icons.inventory_2_outlined),
          title: Text(l10n.archivedNotes),
          subtitle: Text(l10n.archivedNotesSubtitle),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ArchivedNotesScreen()),
          ),
        ),

        // Eva section
        const Divider(),
        const _SectionHeader(title: 'Eva'),
        ListTile(
          leading: const Icon(Icons.auto_awesome),
          title: Text(l10n.evaRescanAllTitle),
          subtitle: Text(l10n.evaRescanAllSubtitle),
          onTap: _rescanAll,
        ),
        ListTile(
          leading: const Icon(Icons.restart_alt, color: Color(0xFFC62828)),
          title: Text(l10n.evaResetListTitle),
          subtitle: Text(l10n.evaResetListSubtitle),
          onTap: _resetEva,
        ),

        // Backup section
        const Divider(),
        _SectionHeader(title: l10n.backupData),
        ListTile(
          leading: const Icon(Icons.backup_outlined),
          title: Text(l10n.backupData),
          subtitle: const Text('Drive, Dropbox, OneDrive...'),
          onTap: () => BackupService.instance.backup(context),
        ),
        ListTile(
          leading: const Icon(Icons.restore_outlined),
          title: Text(l10n.restoreData),
          onTap: () async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: Text(l10n.restoreConfirmTitle),
                content: Text(l10n.restoreConfirmBody),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: Text(l10n.cancel),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: FilledButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.error,
                    ),
                    child: Text(l10n.restoreData),
                  ),
                ],
              ),
            );
            if (confirmed != true || !context.mounted) return;
            final ok = await BackupService.instance.restore(context);
            if (ok && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.restoreSuccess)),
              );
            }
          },
        ),

        // About section
        _SectionHeader(title: l10n.about),
        ListTile(
          leading: const Icon(Icons.help_outline),
          title: Text(l10n.helpTitle),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const HelpScreen()),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.description_outlined),
          title: Text(l10n.termsTitle),
          onTap: () => showDialog<void>(
            context: context,
            builder: (ctx) {
              final dl = AppLocalizations.of(ctx);
              return AlertDialog(
                title: Text(dl.termsTitle),
                content: SingleChildScrollView(
                  child: Text(
                    dl.termsBody,
                    style: const TextStyle(height: 1.6),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('OK'),
                  ),
                ],
              );
            },
          ),
        ),
        ListTile(
          leading: const Icon(Icons.privacy_tip_outlined),
          title: Text(l10n.privacyTitle),
          subtitle: Text(
              kCloudAiEnabled ? l10n.privacySubtitlePro : l10n.privacySubtitleFree),
          onTap: () async {
            final page = kCloudAiEnabled ? 'privacy-pro-el.html' : 'privacy-free-el.html';
            final uri = Uri.parse('https://kokkinopoulos-eng.github.io/notespot-legal/' + page);
            try {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            } catch (_) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('kokkinopoulos-eng.github.io/notespot-legal')));
              }
            }
          },
        ),
        ListTile(
          leading: const Icon(Icons.info_outline),
          title: Text(l10n.version),
          subtitle: Text('NoteSpot ' + kEditionName + ' · 1.0.0'),
        ),
      ],
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