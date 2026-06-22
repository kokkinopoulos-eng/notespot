import 'package:flutter/material.dart';

class LockedWrapper extends StatelessWidget {
  const LockedWrapper({
    super.key,
    required this.child,
    required this.locked,
    required this.onLockedTap,
  });

  final Widget child;
  final bool locked;
  final VoidCallback onLockedTap;

  @override
  Widget build(BuildContext context) {
    if (!locked) return child;
    return GestureDetector(
      onTap: onLockedTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          IgnorePointer(
            child: Opacity(opacity: 0.45, child: child),
          ),
          Positioned(
            top: -4,
            right: -4,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lock, size: 12, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
