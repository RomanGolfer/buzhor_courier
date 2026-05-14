import 'package:flutter/material.dart';

/// A reusable bubble-style widget for lightweight UI decoration.
class BubbleWidget extends StatelessWidget {
  const BubbleWidget({
    super.key,
    this.diameter = 72,
    this.color = const Color(0xFF3366FF),
    this.opacity = 0.18,
    this.child,
    this.shadowColor = const Color(0x1F000000),
  });

  final double diameter;
  final Color color;
  final double opacity;
  final Widget? child;
  final Color shadowColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withOpacity(opacity),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child == null
          ? null
          : Center(
              child: child,
            ),
    );
  }
}
