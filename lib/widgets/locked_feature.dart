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
            child: Opacity(opacity: 0.5, child: child),
          ),
          Positioned(
            top: 2,
            right: 8,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFFF9800),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock, size: 13, color: Colors.white),
                  SizedBox(width: 3),
                  Text(
                    'PRO',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}