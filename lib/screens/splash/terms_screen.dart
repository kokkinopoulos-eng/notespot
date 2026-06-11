import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kTermsKey = 'terms_accepted_v1';

class TermsGate extends StatefulWidget {
  const TermsGate({super.key, required this.next});
  final Widget next;
  @override
  State<TermsGate> createState() => _TermsGateState();
}

class _TermsGateState extends State<TermsGate> {
  bool? _accepted;
  @override
  void initState() { super.initState(); _check(); }
  Future<void> _check() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _accepted = prefs.getBool(_kTermsKey) ?? false);
  }
  Future<void> _accept() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kTermsKey, true);
    if (!mounted) return;
    setState(() => _accepted = true);
  }
  @override
  Widget build(BuildContext context) {
    if (_accepted == null) return const Scaffold(
        backgroundColor: Color(0xFF0F152F), body: SizedBox.shrink());
    if (_accepted!) return widget.next;
    return _TermsScreen(onAccept: _accept);
  }
}

class _TermsScreen extends StatelessWidget {
  const _TermsScreen({required this.onAccept});
  final VoidCallback onAccept;

  static const _el = '''
\u038C\u03C1\u03BF\u03B9 \u03A7\u03C1\u03AE\u03C3\u03B7\u03C2 & \u0391\u03C0\u03CC\u03C1\u03C1\u03B7\u03C4\u03BF

\u2022 \u038C\u03BB\u03B5\u03C2 \u03BF\u03B9 \u03C3\u03B7\u03BC\u03B5\u03B9\u03CE\u03C3\u03B5\u03B9\u03C2 \u03B1\u03C0\u03BF\u03B8\u03B7\u03BA\u03B5\u03CD\u03BF\u03BD\u03C4\u03B1\u03B9 \u03BC\u03CC\u03BD\u03BF \u03C3\u03C4\u03B7 \u03C3\u03C5\u03C3\u03BA\u03B5\u03C5\u03AE \u03C3\u03B1\u03C2.

\u2022 \u0391\u03BD \u03B5\u03BD\u03B5\u03C1\u03B3\u03BF\u03C0\u03BF\u03B9\u03AE\u03C3\u03B5\u03C4\u03B5 \u03C4\u03B9\u03C2 \u03BB\u03B5\u03B9\u03C4\u03BF\u03C5\u03C1\u03B3\u03AF\u03B5\u03C2 AI \u03BC\u03B5 \u03B4\u03B9\u03BA\u03CC \u03C3\u03B1\u03C2 \u03BA\u03BB\u03B5\u03B9\u03B4\u03AF API, \u03C4\u03BF \u03C0\u03B5\u03C1\u03B9\u03B5\u03C7\u03CC\u03BC\u03B5\u03BD\u03BF \u03B1\u03C0\u03BF\u03C3\u03C4\u03AD\u03BB\u03BB\u03B5\u03C4\u03B1\u03B9 \u03B1\u03C0\u03B5\u03C5\u03B8\u03B5\u03AF\u03B1\u03C2 \u03C3\u03C4\u03BF\u03BD \u03C0\u03AC\u03C1\u03BF\u03C7\u03BF \u03C0\u03BF\u03C5 \u03B5\u03C0\u03B9\u03BB\u03AD\u03BE\u03B1\u03C4\u03B5.

\u2022 \u0397 \u03BA\u03BF\u03B9\u03BD\u03BF\u03C0\u03BF\u03AF\u03B7\u03C3\u03B7 \u03B3\u03AF\u03BD\u03B5\u03C4\u03B1\u03B9 \u03BC\u03CC\u03BD\u03BF \u03BC\u03B5 \u03B4\u03B9\u03BA\u03AE \u03C3\u03B1\u03C2 \u03B5\u03BD\u03AD\u03C1\u03B3\u03B5\u03B9\u03B1, \u03BC\u03AD\u03C3\u03C9 \u03C4\u03BF\u03C5 Android share.

\u2022 \u03A4\u03B1 \u03B1\u03BD\u03C4\u03AF\u03B3\u03C1\u03B1\u03C6\u03B1 \u03B1\u03C3\u03C6\u03B1\u03BB\u03B5\u03AF\u03B1\u03C2 \u03B1\u03C0\u03BF\u03B8\u03B7\u03BA\u03B5\u03CD\u03BF\u03BD\u03C4\u03B1\u03B9 \u03CC\u03C0\u03BF\u03C5 \u03B5\u03C0\u03B9\u03BB\u03AD\u03BE\u03B5\u03C4\u03B5 \u03B5\u03C3\u03B5\u03AF\u03C2.

\u2022 \u0397 \u03B5\u03C6\u03B1\u03C1\u03BC\u03BF\u03B3\u03AE \u03B4\u03B5\u03BD \u03C3\u03C5\u03BB\u03BB\u03AD\u03B3\u03B5\u03B9 analytics \u03BF\u03CD\u03C4\u03B5 \u03C0\u03C1\u03BF\u03C3\u03C9\u03C0\u03B9\u03BA\u03AC \u03B4\u03B5\u03B4\u03BF\u03BC\u03AD\u03BD\u03B1.

\u2022 \u03A4\u03BF NoteSpot Premium \u03B1\u03B3\u03BF\u03C1\u03AC\u03B6\u03B5\u03C4\u03B1\u03B9 \u03BC\u03AD\u03C3\u03C9 Google Play.

\u03A0\u03BB\u03AE\u03C1\u03B7\u03C2 \u03C0\u03BF\u03BB\u03B9\u03C4\u03B9\u03BA\u03AE:
''';

  static const _en = '''
Terms of Use & Privacy

\u2022 All your notes are stored only on your device.

\u2022 If you enable AI features with your own API key, note content is sent directly to the provider you chose.

\u2022 Notes are shared only by your own action, via the Android share sheet.

\u2022 Backup files you export are stored wherever you choose.

\u2022 The app collects no analytics and no personal data.

\u2022 NoteSpot Premium is purchased via Google Play.

Full policy:
''';

  static const _url = 'https://kokkinopoulos-eng.github.io/notespot-legal/';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F152F),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('NoteSpot', textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 26,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Scrollbar(
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(_el, style: TextStyle(
                              color: Colors.white70, fontSize: 13.5, height: 1.5)),
                          const SelectableText(_url, style: TextStyle(
                              color: Color(0xFF7FD4D8), fontSize: 13)),
                          const SizedBox(height: 20),
                          Container(height: 0.5, color: Colors.white24),
                          const SizedBox(height: 20),
                          const Text(_en, style: TextStyle(
                              color: Colors.white54, fontSize: 12.5, height: 1.5)),
                          const SelectableText(_url, style: TextStyle(
                              color: Color(0xFF7FD4D8), fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: onAccept,
                style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14)),
                child: const Text('\u0391\u03C0\u03BF\u03B4\u03BF\u03C7\u03AE / Accept'),
              ),
              TextButton(
                onPressed: () => SystemNavigator.pop(),
                child: const Text('\u0388\u03BE\u03BF\u03B4\u03BF\u03C2 / Exit',
                    style: TextStyle(color: Colors.white54)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}