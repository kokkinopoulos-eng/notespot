import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/feature_flags.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.next});
  final Widget next;
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _done = false;
  @override
  void initState() {
    super.initState();
    Timer(const Duration(milliseconds: 4000), () {
      if (mounted) setState(() => _done = true);
    });
  }
  Widget _body() => Scaffold(
    key: const ValueKey('splash'),
    backgroundColor: const Color(0xFF000000),
    body: SafeArea(
      child: SizedBox.expand(
        child: Column(children: [
          const Spacer(flex: 3),
          Image.asset(kCloudAiEnabled ? 'assets/icon/icon_pro_512.png' : 'assets/icon/icon_free_512.png', width: 180,
              errorBuilder: (_, __, ___) =>
                  const Icon(Icons.menu_book, size: 120, color: Colors.white)),
          const SizedBox(height: 20),
          RichText(
            textAlign: TextAlign.center,
            text: const TextSpan(children: [
              TextSpan(text: 'Spot', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
              TextSpan(text: 'Note', style: TextStyle(color: Color(0xFFFFD600), fontSize: 28, fontWeight: FontWeight.bold)),
              TextSpan(text: ' AI', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
            ]),
          ),
          const SizedBox(height: 12),
          const Text('Capture anything. Find everything.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 16,
                  fontStyle: FontStyle.italic, letterSpacing: 0.4)),
          const Spacer(flex: 4),
          const Padding(
            padding: EdgeInsets.only(bottom: 24),
            child: Text('By Kokkinopoulos Babis',
                style: TextStyle(color: Colors.white38, fontSize: 12.5,
                    letterSpacing: 0.6)),
          ),
        ]),
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () { if (!_done && mounted) setState(() => _done = true); },
    behavior: HitTestBehavior.opaque,
    child: AnimatedSwitcher(
    duration: const Duration(milliseconds: 400),
    child: _done
        ? KeyedSubtree(key: const ValueKey('app'), child: widget.next)
        : _body(),
    ),
  );
}