import 'package:flutter/material.dart';
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
  bool _loading = false;

  Future<void> _onBuy() async {
    setState(() => _loading = true);
    final ok = await PremiumService.instance.buy();
    if (!mounted) return;
    setState(() => _loading = false);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(PremiumService.instance.lastError ?? 'Σφάλμα αγοράς'),
      ));
      return;
    }
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
    if (accepted == true && mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final price = PremiumService.instance.priceText;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: cs.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Icon(Icons.auto_awesome, size: 48, color: Color(0xFF7C4DFF)),
            const SizedBox(height: 12),
            Text(
              'Ξεκλείδωσε το AI',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            const _FeatureRow(
              icon: '💬',
              text: 'Ρώτησε τον AI (Claude/Gemini/GPT)',
            ),
            const _FeatureRow(
              icon: '🪄',
              text: 'AI Εργαλεία: σύνοψη, βελτίωση, ορθογραφικό',
            ),
            const _FeatureRow(icon: '🧠', text: 'Έξυπνη κατηγοριοποίηση'),
            const _FeatureRow(icon: '🎙️', text: 'Δομή φωνητικών με AI'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 18, color: cs.onSurfaceVariant),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Χρειάζεσαι δικό σου API key (BYOK). Οι σημειώσεις που '
                      'στέλνεις στο AI επεξεργάζονται από τον πάροχο που επιλέγεις.',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _loading ? null : _onBuy,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF7C4DFF),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        'Ξεκλείδωσε — $price',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _loading ? null : PremiumService.instance.restore,
              child: const Text('Επαναφορά αγοράς'),
            ),
          ],
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
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
