import 'package:flutter/material.dart';
import '../theme.dart';

class NeoTextField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final bool obscureText;
  final TextInputType keyboardType;

  const NeoTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
  });

  @override
  State<NeoTextField> createState() => _NeoTextFieldState();
}

class _NeoTextFieldState extends State<NeoTextField> {
  final FocusNode _focusNode = FocusNode();
  bool _isFocused = false;
  late bool _obscure;

  @override
  void initState() {
    super.initState();
    _obscure = widget.obscureText;
    _focusNode.addListener(() {
      setState(() {
        _isFocused = _focusNode.hasFocus;
      });
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final offset = _isFocused ? const Offset(1, 1) : const Offset(6, 6);
    final transform = _isFocused ? Matrix4.translationValues(5, 5, 0) : Matrix4.identity();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              widget.label.toUpperCase(),
              style: NeoTheme.headingFont(
                fontWeight: FontWeight.w900,
                fontSize: 14,
                letterSpacing: 1.0,
                color: Colors.black,
              ),
            ),
            if (widget.hint != null) ...[
              const SizedBox(width: 8),
              Text(
                widget.hint!,
                style: NeoTheme.sansFont(
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                  color: Colors.black54,
                ),
              ),
            ]
          ],
        ),
        const SizedBox(height: 4),
        AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          transform: transform,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.black, width: 4.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black,
                offset: offset,
              ),
            ],
          ),
          child: TextField(
            controller: widget.controller,
            focusNode: _focusNode,
            obscureText: _obscure,
            keyboardType: widget.keyboardType,
            style: NeoTheme.sansFont(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Colors.black,
            ),
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: InputBorder.none,
              suffixIcon: widget.obscureText
                  ? IconButton(
                      icon: Icon(
                        _obscure ? Icons.visibility_off : Icons.visibility,
                        color: Colors.black,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscure = !_obscure;
                        });
                      },
                    )
                  : null,
            ),
          ),
        ),
        if (_isFocused) const SizedBox(height: 5),
      ],
    );
  }
}