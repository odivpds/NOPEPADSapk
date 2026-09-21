import 'package:flutter/material.dart';
import '../theme.dart';

class NeoButton extends StatefulWidget {
  final String text;
  final VoidCallback onPressed;
  final Color backgroundColor;
  final Color textColor;
  final Widget? icon;
  final double height;

  const NeoButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.backgroundColor = Colors.white,
    this.textColor = Colors.black,
    this.icon,
    this.height = 48.0,
  });

  @override
  State<NeoButton> createState() => _NeoButtonState();
}

class _NeoButtonState extends State<NeoButton> {
  bool _isPressed = false;
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDown = _isPressed || _isHovered;
    final offset = isDown ? const Offset(2, 2) : const Offset(6, 6);
    final transform = isDown ? Matrix4.translationValues(4, 4, 0) : Matrix4.identity();

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) {
          setState(() => _isPressed = false);
          widget.onPressed();
        },
        onTapCancel: () => setState(() => _isPressed = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          transform: transform,
          height: widget.height,
          decoration: BoxDecoration(
            color: widget.backgroundColor,
            border: Border.all(color: Colors.black, width: 4.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black,
                offset: offset,
              ),
            ],
          ),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.icon != null) ...[
                  widget.icon!,
                  const SizedBox(width: 8),
                ],
                Text(
                  widget.text.toUpperCase(),
                  style: NeoTheme.headingFont(
                    color: widget.textColor,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}