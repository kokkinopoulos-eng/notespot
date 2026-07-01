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

class _PaywallSheet extends StatefulWidget {
  const _PaywallSheet();
  @override
  State<_PaywallSheet> createState() => _PaywallSheetState();
}

class _PaywallSheetState extends State<_PaywallSheet> {
  // 0 = intro, 1 = key entry
  int _step = 0;
  AiProvider _provider = AiProvider.claude;
  final _keyCtrl = TextEditingController();
  bool _keyVisible = false;
  bool _testing = false;
  bool _keyValid = false;
  String? _keyError;
  bool _buying = false;

  @override
  void dispose() {
    _keyCtrl.dispose();
    super.dispose();
  }

  Future<void> _testKey() async {
    final key = _keyCtrl.text.trim();
    if (key.isEmpty) {
      setState(() => _keyError = '\u0395\u03b9\u03c3\u03ac\u03b3\u03b1\u03b3\u03b5 \u03c4\u03bf API key');
      return;
    }
    setState(() { _testing = true; _keyError = null; _keyValid = false; });
    final ok = await AiSettingsService.instance.testApiKey(_provider, key);
    if (!mounted) return;
    setState(() {
      _testing = false;
      _keyValid = ok;
      _keyError = ok ? null : '\u039c\u03b7 \u03ad\u03b3\u03ba\u03c5\u03c1\u03bf key. \u0394\u03bf\u03ba\u03af\u03bc\u03b1\u03c3\u03b5 \u03be\u03b1\u03bd\u03ac.';
    });
  }

  Future<void> _onBuy() async {
    setState(() => _buying = true);
    await AiSettingsService.instance.setApiKey(_provider, _keyCtrl.text.trim());
    await AiSettingsService.instance.setSelectedProvider(_provider);
    final ok = await PremiumService.instance.buy();
    if (!mounted) return;
    setState(() => _buying = false);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(PremiumService.instance.lastError ?? '\u03a3\u03c6\u03ac\u03bb\u03bc\u03b1 \u03b1\u03b3\u03bf\u03c1\u03ac\u03c2'),
      ));
      return;
    }
    final accepted = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('\u038c\u03c1\u03bf\u03b9 \u03c7\u03c1\u03ae\u03c3\u03b7\u03c2 AI'),
        content: const SingleChildScrollView(
          child: Text(
            '\u03a7\u03c1\u03b7\u03c3\u03b9\u03bc\u03bf\u03c0\u03bf\u03b9\u03ce\u03bd\u03c4\u03b1\u03c2 \u03c4\u03bf AI, \u03b1\u03c0\u03bf\u03b4\u03ad\u03c7\u03b5\u03c3\u03b1\u03b9 \u03cc\u03c4\u03b9 \u03c4\u03b1 \u03ba\u03b5\u03af\u03bc\u03b5\u03bd\u03b1 \u03c0\u03bf\u03c5 \u03b1\u03c0\u03bf\u03c3\u03c4\u03ad\u03bb\u03bb\u03b5\u03b9\u03c2 \u03b5\u03c0\u03b5\u03be\u03b5\u03c1\u03b3\u03ac\u03b6\u03bf\u03bd\u03c4\u03b1\u03b9 \u03b1\u03c0\u03cc \u03c4\u03bf\u03bd \u03c0\u03ac\u03c1\u03bf\u03c7\u03bf AI \u03c0\u03bf\u03c5 \u03b5\u03c0\u03b9\u03bb\u03ad\u03b3\u03b5\u03b9\u03c2. \u039c\u03b7\u03bd \u03c3\u03c4\u03ad\u03bb\u03bd\u03b5\u03b9\u03c2 \u03c0\u03c1\u03bf\u03c3\u03c9\u03c0\u03b9\u03ba\u03ad\u03c2 \u03ae \u03b5\u03c5\u03b1\u03af\u03c3\u03b8\u03b7\u03c4\u03b5\u03c2 \u03c0\u03bb\u03b7\u03c1\u03bf\u03c6\u03bf\u03c1\u03af\u03b5\u03c2 \u03bc\u03ad\u03c3\u03c9 \u03c4\u03bf\u03c5 AI.',
            style: TextStyle(height: 1.6),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('\u0386\u03ba\u03c5\u03c1\u03bf')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('\u0391\u03c0\u03bf\u03b4\u03bf\u03c7\u03ae')),
        ],
      ),
    );
    if (accepted == true && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: 24, right: 24, top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: _step == 0 ? _buildIntro(context) : _buildKeyEntry(context),
          ),
        ),
      ),
    );
  }

  Widget _buildIntro(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _dragHandle(cs),
        const Icon(Icons.auto_awesome, size: 48, color: Color(0xFF7C4DFF)),
        const SizedBox(height: 12),
        Text('\u2728 SpotNote AI Pro',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Text(
          '\u03a4\u03bf SpotNote AI Pro \u03c7\u03c1\u03b7\u03c3\u03b9\u03bc\u03bf\u03c0\u03bf\u03b9\u03b5\u03af \u03c4\u03bf \u03b4\u03b9\u03ba\u03cc \u03c3\u03bf\u03c5 AI API key (BYOK). \u03a7\u03c1\u03b5\u03b9\u03ac\u03b6\u03b5\u03c3\u03b1\u03b9 \u03bb\u03bf\u03b3\u03b1\u03c1\u03b9\u03b1\u03c3\u03bc\u03cc \u03c3\u03b5 \u03ad\u03bd\u03b1\u03bd \u03b1\u03c0\u03cc \u03c4\u03bf\u03c5\u03c2 \u03c0\u03b1\u03c1\u03b1\u03ba\u03ac\u03c4\u03c9 \u03c0\u03b1\u03c1\u03cc\u03c7\u03bf\u03c5\u03c2.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, height: 1.5),
        ),
        const SizedBox(height: 20),
        _providerCard(context, '\u{1F7E3} Anthropic Claude', 'https://console.anthropic.com/', cs),
        _providerCard(context, '\u{1F535} Google Gemini', 'https://aistudio.google.com/apikey', cs),
        _providerCard(context, '\u{1F7E2} OpenAI GPT', 'https://platform.openai.com/api-keys', cs),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => setState(() => _step = 1),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF7C4DFF),
                padding: const EdgeInsets.symmetric(vertical: 14)),
            child: const Text('\u0388\u03c7\u03c9 \u03ae\u03b4\u03b7 key \u2192'),
          ),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('\u03a3\u03c5\u03bd\u03ad\u03c7\u03b5\u03b9\u03b1 \u03bc\u03b5 Free'),
        ),
      ],
    );
  }

  Widget _buildKeyEntry(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final price = PremiumService.instance.priceText;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _dragHandle(cs),
        Row(children: [
          IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => setState(() { _step = 0; _keyValid = false; _keyError = null; })),
          Text('\u0395\u03b9\u03c3\u03b1\u03b3\u03c9\u03b3\u03ae API Key',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 16),
        SegmentedButton<AiProvider>(
          segments: const [
            ButtonSegment(value: AiProvider.claude, label: Text('Claude')),
            ButtonSegment(value: AiProvider.gemini, label: Text('Gemini')),
            ButtonSegment(value: AiProvider.openai, label: Text('OpenAI')),
          ],
          selected: {_provider},
          onSelectionChanged: (s) => setState(() { _provider = s.first; _keyValid = false; _keyError = null; }),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _keyCtrl,
          obscureText: !_keyVisible,
          decoration: InputDecoration(
            labelText: 'API Key',
            border: const OutlineInputBorder(),
            errorText: _keyError,
            suffixIcon: IconButton(
              icon: Icon(_keyVisible ? Icons.visibility_off : Icons.visibility),
              onPressed: () => setState(() => _keyVisible = !_keyVisible),
            ),
          ),
          onChanged: (_) => setState(() { _keyValid = false; _keyError = null; }),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: _testing ? null : _testKey,
            child: _testing
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('\u0395\u03c0\u03b1\u03bb\u03ae\u03b8\u03b5\u03c5\u03c3\u03b7 key'),
          ),
        ),
        if (_keyValid) ...[
          const SizedBox(height: 8),
          Row(children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 18),
            const SizedBox(width: 6),
            Text('\u03a4\u03bf key \u03b5\u03af\u03bd\u03b1\u03b9 \u03ad\u03b3\u03ba\u03c5\u03c1\u03bf!',
                style: const TextStyle(color: Colors.green)),
          ]),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _buying ? null : _onBuy,
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF7C4DFF),
                  padding: const EdgeInsets.symmetric(vertical: 14)),
              child: _buying
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text('\u039e\u03b5\u03ba\u03bb\u03b5\u03af\u03b4\u03c9\u03c3\u03b5 Pro \u2014 $price',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _buying ? null : PremiumService.instance.restore,
            child: const Text('\u0395\u03c0\u03b1\u03bd\u03b1\u03c6\u03bf\u03c1\u03ac \u03b1\u03b3\u03bf\u03c1\u03ac\u03c2'),
          ),
        ],
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('\u03a3\u03c5\u03bd\u03ad\u03c7\u03b5\u03b9\u03b1 \u03bc\u03b5 Free'),
        ),
      ],
    );
  }

  Widget _dragHandle(ColorScheme cs) => Container(
        width: 40, height: 4,
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(color: cs.outlineVariant, borderRadius: BorderRadius.circular(2)),
      );

  Widget _providerCard(BuildContext context, String name, String url, ColorScheme cs) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
                  child: const Text('\u0394\u03b7\u03bc\u03b9\u03bf\u03cd\u03c1\u03b3\u03b7\u03c3\u03b5 key \u2192'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({required this.icon, required this.text});
  final String icon;
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Text(icon, style: const TextStyle(fontSize: 20)),
        const SizedBox(width: 12),
        Expanded(child: Text(text)),
      ]),
    );
  }
}