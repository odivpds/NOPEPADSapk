import 'package:flutter/material.dart';

class NeoInteractive extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  const NeoInteractive({super.key, required this.child, this.onTap});

  @override
  State<NeoInteractive> createState() => _NeoInteractiveState();
}

class _NeoInteractiveState extends State<NeoInteractive> {
  bool _isPressed = false;
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDown = _isPressed || _isHovered;
    final transform = isDown ? Matrix4.translationValues(4, 4, 0) : Matrix4.identity();

    return MouseRegion(
      cursor: widget.onTap != null ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) {
          setState(() => _isPressed = false);
          widget.onTap?.call();
        },
        onTapCancel: () => setState(() => _isPressed = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          transform: transform,
          child: widget.child,
        ),
      ),
    );
  }
}
