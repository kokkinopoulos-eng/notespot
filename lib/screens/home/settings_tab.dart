import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../main.dart';
import '../../models/ai_provider.dart';
import '../../services/ai_settings_service.dart';
import '../../services/premium_service.dart';

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
                icon:
                    Icon(_obscure ? Icons.visibility_off : Icons.visibility),
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
  const SettingsTab({super.key});

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  AiProvider _selectedProvider = AiProvider.gemini;
  String? _maskedKey;
  bool _hasKey = false;

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
    if (!mounted) return;
    setState(() {
      _selectedProvider = provider;
      _hasKey = hasKey;
      _maskedKey = masked;
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

  Future<void> _handleBuy(AppLocalizations l10n) async {
    final ok = await PremiumService.instance.buy();
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(
            PremiumService.instance.lastError ?? l10n.purchaseError)),
      );
    }
  }

  Future<void> _handleRestore(AppLocalizations l10n) async {
    await PremiumService.instance.restore();
    if (!mounted) return;
    if (PremiumService.instance.lastError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.purchaseError)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final currentLocale = NoteSpotApp.of(context).locale;

    return ListenableBuilder(
      listenable: PremiumService.instance,
      builder: (context, _) {
        final isPremium = PremiumService.instance.isPremium;

        // Show success snack when premium just unlocked
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (isPremium && PremiumService.instance.lastError == null) {
            // only show once — handled by stream
          }
        });

        return ListView(
          children: [
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

            // Premium section
            if (!isPremium) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                child: Card(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Icon(Icons.star,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onPrimaryContainer),
                          const SizedBox(width: 8),
                          Expanded(child: Text(l10n.premiumTitle,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onPrimaryContainer,
                                    fontWeight: FontWeight.bold,
                                  ))),
                        ]),
                        const SizedBox(height: 8),
                        Text(l10n.premiumDesc,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onPrimaryContainer,
                                )),
                        const SizedBox(height: 12),
                        Wrap(spacing: 8, children: [
                          FilledButton(
                            onPressed: () => _handleBuy(l10n),
                            child: Text(l10n.buyPremium),
                          ),
                          TextButton(
                            onPressed: () => _handleRestore(l10n),
                            child: Text(l10n.restorePurchases),
                          ),
                        ]),
                      ],
                    ),
                  ),
                ),
              ),
              const Divider(),
            ] else ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Chip(
                  avatar: const Icon(Icons.star, size: 16),
                  label: Text('${l10n.premiumTitle} ✓'),
                  backgroundColor:
                      Theme.of(context).colorScheme.primaryContainer,
                ),
              ),
              const SizedBox(height: 4),
            ],

            // AI section
            _SectionHeader(title: l10n.aiProvider),
            ListTile(
              enabled: isPremium,
              leading: const Icon(Icons.psychology_outlined),
              title: Text(l10n.aiProvider),
              subtitle: Text(_selectedProvider.displayName),
              trailing: Icon(
                _hasKey ? Icons.check_circle : Icons.key_off,
                color: _hasKey
                    ? Colors.green
                    : Theme.of(context).colorScheme.outline,
              ),
              onTap: isPremium ? _openProviderDialog : null,
            ),
            ListTile(
              enabled: isPremium,
              leading: const Icon(Icons.key_outlined),
              title: Text(l10n.apiKey),
              subtitle: Text(_maskedKey ?? l10n.noApiKey),
              onTap: isPremium ? _openApiKeyDialog : null,
            ),
            const Divider(),

            // About section
            _SectionHeader(title: l10n.about),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: Text(l10n.version),
              subtitle: const Text('1.0.0'),
            ),
          ],
        );
      },
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