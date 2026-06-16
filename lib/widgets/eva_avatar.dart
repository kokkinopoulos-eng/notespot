import 'package:flutter/material.dart';

/// Eva's moods — extensible for future assistant roles.
enum EvaMood { idle, thinking, happy, tip }

/// Eva mascot. Can be used inline or as a floating, tappable assistant.
/// Designed to grow into more assistant roles later (just add moods / tips).
class EvaAvatar extends StatefulWidget {
  const EvaAvatar({
    super.key,
    this.size = 56,
    this.mood = EvaMood.idle,
    this.floating = false,
    this.onTap,
  });

  final double size;
  final EvaMood mood;

  /// When true, Eva gently bobs up and down (used for the floating helper).
  final bool floating;

  final VoidCallback? onTap;

  @override
  State<EvaAvatar> createState() => _EvaAvatarState();
}

class _EvaAvatarState extends State<EvaAvatar> with TickerProviderStateMixin {
  late final AnimationController _breath;
  late final AnimationController _bounce;
  late final AnimationController _float;

  @override
  void initState() {
    super.initState();
    _breath = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
    )..repeat(reverse: true);
    _float = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);
    _bounce = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );
    if (widget.mood == EvaMood.thinking || widget.mood == EvaMood.happy) {
      _playBounce();
    }
  }

  @override
  void didUpdateWidget(covariant EvaAvatar old) {
    super.didUpdateWidget(old);
    if (widget.mood != old.mood &&
        (widget.mood == EvaMood.thinking || widget.mood == EvaMood.happy)) {
      _playBounce();
    }
  }

  void _playBounce() => _bounce.forward(from: 0);

  @override
  void dispose() {
    _breath.dispose();
    _bounce.dispose();
    _float.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final img = AnimatedBuilder(
      animation: Listenable.merge([_breath, _bounce, _float]),
      builder: (context, child) {
        final breathe = 0.92 + (_breath.value * 0.12);
        final b = _bounce.value > 0
            ? Curves.elasticOut.transform(_bounce.value)
            : 0.0;
        final bounceScale = 1.0 + (b * 0.14);
        final sway = (_breath.value - 0.5) * 0.10;
        final floatDy = widget.floating ? (_float.value - 0.5) * 14.0 : 0.0;
        final bounceDy = -10.0 * (b * (1 - _bounce.value));
        return Transform.translate(
          offset: Offset(0, floatDy + bounceDy),
          child: Transform.rotate(
            angle: sway,
            child: Transform.scale(scale: breathe * bounceScale, child: child),
          ),
        );
      },
      child: Image.asset(
        'assets/images/eva.png',
        width: widget.size,
        height: widget.size * 280 / 240,
        fit: BoxFit.contain,
      ),
    );

    if (widget.onTap == null) return img;
    return GestureDetector(
      onTap: () {
        _playBounce();
        widget.onTap!.call();
      },
      child: img,
    );
  }
}
