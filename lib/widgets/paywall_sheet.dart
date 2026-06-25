import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/ai_provider.dart';
import '../services/ai_settings_service.dart';
import '../services/premium_service.dart';

Future<void> showPaywall(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => const _PaywallSheet(),
  );
}

// ─── shared chrome ────────────────────────────────────────────────────────────

Widget _dragHandle(BuildContext context) => Container(
      width: 40,
      height: 4,
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.outlineVariant,
        borderRadius: BorderRadius.circular(2),
      ),
    );

Widget _freeButton(BuildContext context) => TextButton(
      onPressed: () => Navigator.pop(context),
      child: const Text('Συνέχεια με Free'),
    );

// ─── sheet root ───────────────────────────────────────────────────────────────

class _PaywallSheet extends StatefulWidget {
  const _PaywallSheet();

  @override
  State<_PaywallSheet> createState() => _PaywallSheetState();
}

enum _Step { intro, keyEntry }

class _PaywallSheetState extends State<_PaywallSheet> {
  _Step _step = _Step.intro;

  // key-entry state
  AiProvider _provider = AiProvider.claude;
  final _keyCtrl = TextEditingController();
  bool _obscure = true;
  bool _validating = false;
  bool? _keyValid; // null = not tested yet
  bool _buying = false;

  @override
  void dispose() {
    _keyCtrl.dispose();
    super.dispose();
  }

  void _goToKeyEntry() => setState(() {
        _step = _Step.keyEntry;
        _keyValid = null;
      });

  Future<void> _validate() async {
    final key = _keyCtrl.text.trim();
    if (key.isEmpty) return;
    setState(() {
      _validating = true;
      _keyValid = null;
    });
    final ok =
        await AiSettingsService.instance.testApiKey(_provider, key);
    if (!mounted) return;
    setState(() {
      _validating = false;
      _keyValid = ok;
    });
  }

  Future<void> _buy() async {
    setState(() => _buying = true);
    final ok = await PremiumService.instance.buy();
    if (!mounted) return;
    setState(() => _buying = false);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(PremiumService.instance.lastError ?? 'Σφάλμα αγοράς'),
      ));
      return;
    }
    // Save validated key + provider
    final key = _keyCtrl.text.trim();
    await AiSettingsService.instance.setApiKey(_provider, key);
    await AiSettingsService.instance.setSelectedProvider(_provider);
    if (!mounted) return;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Όροι χρήσης AI'),
        content: const SingleChildScrollView(
          child: Text(
            'Χρησιμοποιώντας το AI, αποδέχεσαι ότι τα κείμενα που αποστέλλεις '
            'επεξεργάζονται από τον πάροχο AI που επιλέγεις (Claude, Gemini, GPT). '
            'Μην στέλνεις προσωπικές ή ευαίσθητες πληροφορίες μέσω του AI. '
            'Ο προγραμματιστής δεν φέρει ευθύνη για την επεξεργασία δεδομένων '
            'από τρίτους παρόχους.',
            style: TextStyle(height: 1.6),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Άκυρο'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Αποδοχή'),
          ),
        ],
      ),
    );
    if (accepted == true && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            16,
            24,
            MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: _step == _Step.intro
              ? _IntroStep(onHaveKey: _goToKeyEntry)
              : _KeyEntryStep(
                  provider: _provider,
                  keyCtrl: _keyCtrl,
                  obscure: _obscure,
                  validating: _validating,
                  keyValid: _keyValid,
                  buying: _buying,
                  onProviderChanged: (p) =>
                      setState(() {
                        _provider = p;
                        _keyValid = null;
                      }),
                  onToggleObscure: () =>
                      setState(() => _obscure = !_obscure),
                  onValidate: _validate,
                  onBuy: _buy,
                ),
        ),
      ),
    );
  }
}

// ─── Step A: intro ────────────────────────────────────────────────────────────

class _IntroStep extends StatelessWidget {
  const _IntroStep({required this.onHaveKey});
  final VoidCallback onHaveKey;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _dragHandle(context),
        const Icon(Icons.auto_awesome, size: 48, color: Color(0xFF7C4DFF)),
        const SizedBox(height: 12),
        Text(
          '✨ SpotNote AI Pro',
          textAlign: TextAlign.center,
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Text(
          'Το SpotNote AI Pro χρησιμοποιεί το δικό σου AI API key (BYOK). '
          'Χρειάζεσαι λογαριασμό σε έναν από τους παρακάτω παρόχους.',
          textAlign: TextAlign.center,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 24),
        _ProviderCard(
          icon: Icons.generating_tokens,
          iconColor: const Color(0xFF7C4DFF),
          name: 'Anthropic Claude',
          description: 'Ισχυρό, φιλικό AI για κείμενο',
          consoleUrl: 'https://console.anthropic.com/',
        ),
        const SizedBox(height: 8),
        _ProviderCard(
          icon: Icons.auto_awesome_mosaic,
          iconColor: const Color(0xFF1A73E8),
          name: 'Google Gemini',
          description: 'Γρήγορο AI από την Google',
          consoleUrl: 'https://aistudio.google.com/apikey',
        ),
        const SizedBox(height: 8),
        _ProviderCard(
          icon: Icons.psychology_outlined,
          iconColor: const Color(0xFF10A37F),
          name: 'OpenAI',
          description: 'GPT — το πιο δημοφιλές AI',
          consoleUrl: 'https://platform.openai.com/api-keys',
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: onHaveKey,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF7C4DFF),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          child: const Text(
            'Έχω ήδη key →',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 4),
        Center(child: _freeButton(context)),
      ],
    );
  }
}

class _ProviderCard extends StatelessWidget {
  const _ProviderCard({
    required this.icon,
    required this.iconColor,
    required this.name,
    required this.description,
    required this.consoleUrl,
  });

  final IconData icon;
  final Color iconColor;
  final String name;
  final String description;
  final String consoleUrl;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: iconColor.withAlpha(30),
          child: Icon(icon, color: iconColor),
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(description,
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
        trailing: TextButton(
          onPressed: () => launchUrl(
            Uri.parse(consoleUrl),
            mode: LaunchMode.externalApplication,
          ),
          child: const Text('Δημιούργησε key →',
              style: TextStyle(fontSize: 12)),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),
    );
  }
}

// ─── Step B: key entry ────────────────────────────────────────────────────────

class _KeyEntryStep extends StatelessWidget {
  const _KeyEntryStep({
    required this.provider,
    required this.keyCtrl,
    required this.obscure,
    required this.validating,
    required this.keyValid,
    required this.buying,
    required this.onProviderChanged,
    required this.onToggleObscure,
    required this.onValidate,
    required this.onBuy,
  });

  final AiProvider provider;
  final TextEditingController keyCtrl;
  final bool obscure;
  final bool validating;
  final bool? keyValid;
  final bool buying;
  final ValueChanged<AiProvider> onProviderChanged;
  final VoidCallback onToggleObscure;
  final VoidCallback onValidate;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final price = PremiumService.instance.priceText;
    final busy = validating || buying;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _dragHandle(context),
        Text(
          'Πάροχος & API Key',
          textAlign: TextAlign.center,
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),

        // Provider picker
        SegmentedButton<AiProvider>(
          segments: const [
            ButtonSegment(
              value: AiProvider.claude,
              label: Text('Claude', style: TextStyle(fontSize: 12)),
              icon: Icon(Icons.generating_tokens, size: 16),
            ),
            ButtonSegment(
              value: AiProvider.gemini,
              label: Text('Gemini', style: TextStyle(fontSize: 12)),
              icon: Icon(Icons.auto_awesome_mosaic, size: 16),
            ),
            ButtonSegment(
              value: AiProvider.openai,
              label: Text('OpenAI', style: TextStyle(fontSize: 12)),
              icon: Icon(Icons.psychology_outlined, size: 16),
            ),
          ],
          selected: {provider},
          onSelectionChanged: busy
              ? null
              : (s) => onProviderChanged(s.first),
        ),
        const SizedBox(height: 20),

        // Key field
        TextField(
          controller: keyCtrl,
          obscureText: obscure,
          enabled: !busy,
          decoration: InputDecoration(
            labelText: 'API Key',
            hintText: provider.keyHint,
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
              onPressed: busy ? null : onToggleObscure,
            ),
          ),
          onChanged: (_) {},
        ),
        const SizedBox(height: 12),

        // Validate button
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: busy ? null : onValidate,
            child: validating
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child:
                        CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Επαλήθευση key'),
          ),
        ),

        // Validation result
        if (keyValid != null) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                keyValid! ? Icons.check_circle : Icons.cancel,
                color: keyValid! ? Colors.green : cs.error,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                keyValid!
                    ? 'Το key είναι έγκυρο!'
                    : 'Μη έγκυρο key. Δοκίμασε ξανά.',
                style: TextStyle(
                  color: keyValid! ? Colors.green : cs.error,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],

        // Buy button — only after successful validation
        if (keyValid == true) ...[
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: busy ? null : onBuy,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF7C4DFF),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: buying
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      'Ξεκλείδωσε Pro — $price',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ],

        const SizedBox(height: 8),
        Center(
          child: TextButton(
            onPressed:
                busy ? null : PremiumService.instance.restore,
            child: const Text('Επαναφορά αγοράς'),
          ),
        ),
        Center(child: _freeButton(context)),
      ],
    );
  }
}
