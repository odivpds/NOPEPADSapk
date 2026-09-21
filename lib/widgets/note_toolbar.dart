import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;

/// Centralized actions for formatting tools, shared between toolbar buttons and keyboard shortcuts.
class NoteToolbarActions {
  static bool isAttributeSet(quill.QuillController controller, quill.Attribute attr) {
    final style = controller.getSelectionStyle();
    final a = style.attributes[attr.key];
    if (a == null) return false;
    return a.value == attr.value;
  }

  static bool isHighlight(quill.QuillController controller) {
    final style = controller.getSelectionStyle();
    return style.attributes.containsKey(quill.Attribute.background.key);
  }

  static bool isCheck(quill.QuillController controller) {
    return isAttributeSet(controller, quill.Attribute.unchecked) ||
        isAttributeSet(controller, quill.Attribute.checked);
  }

  static void toggleAttribute(quill.QuillController controller, quill.Attribute attribute) {
    final set = isAttributeSet(controller, attribute);
    controller.skipRequestKeyboard = !attribute.isInline;
    if (set) {
      controller.formatSelection(quill.Attribute.clone(attribute, null));
    } else {
      controller.formatSelection(attribute);
    }
  }

  static void toggleHighlight(quill.QuillController controller) {
    if (isHighlight(controller)) {
      controller.formatSelection(const quill.BackgroundAttribute(null));
    } else {
      controller.formatSelection(const quill.BackgroundAttribute('#FDE047'));
    }
  }

  static void toggleCheck(quill.QuillController controller) {
    if (isCheck(controller)) {
      controller.formatSelection(quill.Attribute.clone(quill.Attribute.unchecked, null));
    } else {
      controller.formatSelection(quill.Attribute.unchecked);
    }
  }

  static void undo(quill.QuillController controller) {
    try {
      if (controller.hasUndo) {
        controller.undo();
      }
    } catch (_) {}
  }

  static void redo(quill.QuillController controller) {
    try {
      if (controller.hasRedo) {
        controller.redo();
      }
    } catch (_) {}
  }

  static void clearFormatting(quill.QuillController controller) {
    try {
      for (final attr in [
        quill.Attribute.bold,
        quill.Attribute.italic,
        quill.Attribute.underline,
        quill.Attribute.strikeThrough,
        quill.Attribute.inlineCode,
        quill.Attribute.h1,
        quill.Attribute.h2,
        quill.Attribute.h3,
        quill.Attribute.blockQuote,
        quill.Attribute.codeBlock,
        quill.Attribute.background,
      ]) {
        controller.formatSelection(quill.Attribute.clone(attr, null));
      }
    } catch (_) {}
  }
}

/// Interactive Floating Collapsible Toolbar (matching MyNotes & Gambar 2/3)
class FloatingNoteToolbar extends StatefulWidget {
  final quill.QuillController controller;

  const FloatingNoteToolbar({super.key, required this.controller});

  @override
  State<FloatingNoteToolbar> createState() => _FloatingNoteToolbarState();
}

class _FloatingNoteToolbarState extends State<FloatingNoteToolbar>
    with SingleTickerProviderStateMixin {
  bool _isOpen = false;
  late final AnimationController _animController;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeInCubic,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _isOpen = !_isOpen;
      if (_isOpen) {
        _animController.forward();
      } else {
        _animController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final bool isBold = NoteToolbarActions.isAttributeSet(widget.controller, quill.Attribute.bold);
        final bool isItalic = NoteToolbarActions.isAttributeSet(widget.controller, quill.Attribute.italic);
        final bool isStrike = NoteToolbarActions.isAttributeSet(widget.controller, quill.Attribute.strikeThrough);
        final bool isUnderline = NoteToolbarActions.isAttributeSet(widget.controller, quill.Attribute.underline);
        final bool isInlineCode = NoteToolbarActions.isAttributeSet(widget.controller, quill.Attribute.inlineCode);
        final bool isHighlight = NoteToolbarActions.isHighlight(widget.controller);

        final bool isH1 = NoteToolbarActions.isAttributeSet(widget.controller, quill.Attribute.h1);
        final bool isH2 = NoteToolbarActions.isAttributeSet(widget.controller, quill.Attribute.h2);
        final bool isH3 = NoteToolbarActions.isAttributeSet(widget.controller, quill.Attribute.h3);

        final bool isUl = NoteToolbarActions.isAttributeSet(widget.controller, quill.Attribute.ul);
        final bool isOl = NoteToolbarActions.isAttributeSet(widget.controller, quill.Attribute.ol);
        final bool isCheck = NoteToolbarActions.isCheck(widget.controller);
        final bool isQuote = NoteToolbarActions.isAttributeSet(widget.controller, quill.Attribute.blockQuote);
        final bool isCodeBlock = NoteToolbarActions.isAttributeSet(widget.controller, quill.Attribute.codeBlock);

        final bool canUndo = widget.controller.hasUndo;
        final bool canRedo = widget.controller.hasRedo;

        void toggleAttribute(quill.Attribute attribute) =>
            NoteToolbarActions.toggleAttribute(widget.controller, attribute);

        void toggleHighlight() =>
            NoteToolbarActions.toggleHighlight(widget.controller);

        void toggleCheck() =>
            NoteToolbarActions.toggleCheck(widget.controller);

        void doUndo() =>
            NoteToolbarActions.undo(widget.controller);

        void doRedo() =>
            NoteToolbarActions.redo(widget.controller);

        void clearFormatting() =>
            NoteToolbarActions.clearFormatting(widget.controller);

        final isDark = Theme.of(context).brightness == Brightness.dark;
        final defaultItemColor = isDark ? Colors.white : const Color(0xFF18181B);
        final panelBg = isDark ? const Color(0xFF1E1E24) : const Color(0xFFFFF4E0);
        final maxBarWidth = MediaQuery.of(context).size.width - 98;

        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Circular Floating Toggle Button (Gambar 2 & 3)
            _CircularToggleButton(
              isOpen: _isOpen,
              onTap: _toggle,
            ),

            // Floating Horizontal Tools Panel (disamping kanan toggle)
            if (_isOpen || _animController.value > 0.0)
              IgnorePointer(
                ignoring: !_isOpen,
                child: SizeTransition(
                sizeFactor: _scaleAnimation,
                axis: Axis.horizontal,
                // ignore: deprecated_member_use
                axisAlignment: -1.0,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    alignment: Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(left: 10),
                      constraints: BoxConstraints(
                        maxWidth: maxBarWidth > 120 ? maxBarWidth : 120,
                        maxHeight: 50,
                      ),
                      decoration: BoxDecoration(
                        color: panelBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.black, width: 3.0),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black,
                            offset: Offset(3, 3),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: ScrollConfiguration(
                          behavior: ScrollConfiguration.of(context).copyWith(
                            scrollbars: false,
                          ),
                          child: RawScrollbar(
                            controller: _scrollController,
                            thumbColor: Colors.black,
                            radius: const Radius.circular(4),
                            thickness: 3,
                            child: Listener(
                              onPointerSignal: (pointerSignal) {
                                if (pointerSignal is PointerScrollEvent) {
                                  final delta = pointerSignal.scrollDelta.dy != 0
                                      ? pointerSignal.scrollDelta.dy
                                      : pointerSignal.scrollDelta.dx;
                                  if (_scrollController.hasClients) {
                                    final newOffset = (_scrollController.offset + delta).clamp(
                                      0.0,
                                      _scrollController.position.maxScrollExtent,
                                    );
                                    _scrollController.jumpTo(newOffset);
                                  }
                                }
                              },
                              child: SingleChildScrollView(
                                controller: _scrollController,
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // 1. History Group: Undo & Redo
                                    _NeoToolbarBtn(
                                      tooltip: 'Undo (Ctrl+Z)',
                                      isActive: false,
                                      isEnabled: canUndo,
                                      onTap: doUndo,
                                      child: Icon(
                                        Icons.undo,
                                        size: 16,
                                        color: defaultItemColor,
                                      ),
                                    ),
                                    const SizedBox(width: 5),

                                    _NeoToolbarBtn(
                                      tooltip: 'Redo (Ctrl+Y)',
                                      isActive: false,
                                      isEnabled: canRedo,
                                      onTap: doRedo,
                                      child: Icon(
                                        Icons.redo,
                                        size: 16,
                                        color: defaultItemColor,
                                      ),
                                    ),
                                    const _ToolbarDivider(),

                                    // 2. Headings Group: H1, H2, H3
                                    _NeoToolbarBtn(
                                      tooltip: 'Heading 1 (Ctrl+1)',
                                      isActive: isH1,
                                      onTap: () => toggleAttribute(quill.Attribute.h1),
                                      child: Text(
                                        'H1',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 13,
                                          color: isH1 ? Colors.black : defaultItemColor,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 5),

                                    _NeoToolbarBtn(
                                      tooltip: 'Heading 2 (Ctrl+2)',
                                      isActive: isH2,
                                      onTap: () => toggleAttribute(quill.Attribute.h2),
                                      child: Text(
                                        'H2',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 13,
                                          color: isH2 ? Colors.black : defaultItemColor,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 5),

                                    _NeoToolbarBtn(
                                      tooltip: 'Heading 3 (Ctrl+3)',
                                      isActive: isH3,
                                      onTap: () => toggleAttribute(quill.Attribute.h3),
                                      child: Text(
                                        'H3',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 13,
                                          color: isH3 ? Colors.black : defaultItemColor,
                                        ),
                                      ),
                                    ),
                                    const _ToolbarDivider(),

                                    // 3. Inline Styles: Bold, Italic, Underline, Strikethrough, Highlight, Inline Code
                                    _NeoToolbarBtn(
                                      tooltip: 'Bold (Ctrl+B)',
                                      isActive: isBold,
                                      onTap: () => toggleAttribute(quill.Attribute.bold),
                                      child: Text(
                                        'B',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 15,
                                          color: isBold ? Colors.black : defaultItemColor,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 5),

                                    _NeoToolbarBtn(
                                      tooltip: 'Italic (Ctrl+I)',
                                      isActive: isItalic,
                                      onTap: () => toggleAttribute(quill.Attribute.italic),
                                      child: Text(
                                        'I',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontStyle: FontStyle.italic,
                                          fontFamily: 'serif',
                                          fontSize: 15,
                                          color: isItalic ? Colors.black : defaultItemColor,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 5),

                                    _NeoToolbarBtn(
                                      tooltip: 'Underline (Ctrl+U)',
                                      isActive: isUnderline,
                                      onTap: () => toggleAttribute(quill.Attribute.underline),
                                      child: Icon(
                                        Icons.format_underlined,
                                        size: 17,
                                        color: isUnderline ? Colors.black : defaultItemColor,
                                      ),
                                    ),
                                    const SizedBox(width: 5),

                                    _NeoToolbarBtn(
                                      tooltip: 'Strikethrough (Ctrl+Shift+S)',
                                      isActive: isStrike,
                                      onTap: () => toggleAttribute(quill.Attribute.strikeThrough),
                                      child: Text(
                                        'S',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          decoration: TextDecoration.lineThrough,
                                          decorationThickness: 2.5,
                                          fontSize: 14,
                                          color: isStrike ? Colors.black : defaultItemColor,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 5),

                                    _NeoToolbarBtn(
                                      tooltip: 'Highlight (Ctrl+Shift+H)',
                                      isActive: isHighlight,
                                      onTap: toggleHighlight,
                                      child: Icon(
                                        Icons.border_color_rounded,
                                        size: 15,
                                        color: isHighlight ? Colors.black : const Color(0xFFFDE047),
                                      ),
                                    ),
                                    const SizedBox(width: 5),

                                    _NeoToolbarBtn(
                                      tooltip: 'Inline Code (Ctrl+E)',
                                      isActive: isInlineCode,
                                      onTap: () => toggleAttribute(quill.Attribute.inlineCode),
                                      child: Icon(
                                        Icons.data_object_rounded,
                                        size: 17,
                                        color: isInlineCode ? Colors.black : defaultItemColor,
                                      ),
                                    ),
                                    const _ToolbarDivider(),

                                    // 4. Lists: Bullet, Numbered, Checklist
                                    _NeoToolbarBtn(
                                      tooltip: 'Bullet List (Ctrl+Shift+8)',
                                      isActive: isUl,
                                      onTap: () => toggleAttribute(quill.Attribute.ul),
                                      child: Icon(
                                        Icons.format_list_bulleted,
                                        size: 17,
                                        color: isUl ? Colors.black : defaultItemColor,
                                      ),
                                    ),
                                    const SizedBox(width: 5),

                                    _NeoToolbarBtn(
                                      tooltip: 'Numbered List (Ctrl+Shift+7)',
                                      isActive: isOl,
                                      onTap: () => toggleAttribute(quill.Attribute.ol),
                                      child: Icon(
                                        Icons.format_list_numbered,
                                        size: 17,
                                        color: isOl ? Colors.black : defaultItemColor,
                                      ),
                                    ),
                                    const SizedBox(width: 5),

                                    _NeoToolbarBtn(
                                      tooltip: 'Checklist (Ctrl+Shift+C)',
                                      isActive: isCheck,
                                      onTap: toggleCheck,
                                      child: Icon(
                                        Icons.check_box_outlined,
                                        size: 17,
                                        color: isCheck ? Colors.black : defaultItemColor,
                                      ),
                                    ),
                                    const _ToolbarDivider(),

                                    // 5. Blocks: Quote, Code Block
                                    _NeoToolbarBtn(
                                      tooltip: 'Quote (Ctrl+Shift+Q)',
                                      isActive: isQuote,
                                      onTap: () => toggleAttribute(quill.Attribute.blockQuote),
                                      child: Icon(
                                        Icons.format_quote_rounded,
                                        size: 20,
                                        color: isQuote ? Colors.black : defaultItemColor,
                                      ),
                                    ),
                                    const SizedBox(width: 5),

                                    _NeoToolbarBtn(
                                      tooltip: 'Code Block (Ctrl+Alt+C)',
                                      isActive: isCodeBlock,
                                      onTap: () => toggleAttribute(quill.Attribute.codeBlock),
                                      child: Icon(
                                        Icons.code,
                                        size: 17,
                                        color: isCodeBlock ? Colors.black : defaultItemColor,
                                      ),
                                    ),
                                    const _ToolbarDivider(),

                                    // 6. Formatting Actions: Clear Formatting
                                    _NeoToolbarBtn(
                                      tooltip: 'Clear Formatting (Ctrl+\\)',
                                      isActive: false,
                                      onTap: clearFormatting,
                                      child: Icon(
                                        Icons.format_clear_rounded,
                                        size: 16,
                                        color: defaultItemColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Circular Toggle Button (Gambar 2 when closed, Gambar 3 when open)
class _CircularToggleButton extends StatefulWidget {
  final bool isOpen;
  final VoidCallback onTap;

  const _CircularToggleButton({
    required this.isOpen,
    required this.onTap,
  });

  @override
  State<_CircularToggleButton> createState() => _CircularToggleButtonState();
}

class _CircularToggleButtonState extends State<_CircularToggleButton> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isDown = _isPressed || _isHovered;
    final transform = isDown ? Matrix4.translationValues(2, 2, 0) : Matrix4.identity();
    final shadowOffset = isDown ? const Offset(1, 1) : const Offset(3, 3);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final circleBg = isDark ? const Color(0xFF1E1E24) : const Color(0xFFFFF4E0);
    final iconColor = isDark ? Colors.white : Colors.black;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) {
          setState(() => _isPressed = false);
          widget.onTap();
        },
        onTapCancel: () => setState(() => _isPressed = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          transform: transform,
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: circleBg,
            border: Border.all(color: Colors.black, width: 3.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black,
                offset: shadowOffset,
              ),
            ],
          ),
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 150),
              transitionBuilder: (child, anim) => RotationTransition(
                turns: child.key == const ValueKey('close')
                    ? Tween<double>(begin: -0.25, end: 0.0).animate(anim)
                    : Tween<double>(begin: 0.25, end: 0.0).animate(anim),
                child: FadeTransition(opacity: anim, child: child),
              ),
              child: widget.isOpen
                  ? Icon(
                      Icons.close,
                      key: const ValueKey('close'),
                      color: iconColor,
                      size: 22,
                    )
                  : CustomPaint(
                      key: const ValueKey('pen'),
                      size: const Size(20, 20),
                      painter: _PenToolPainter(color: iconColor),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Neobrutalist Toolbar Square Button (Gambar 3)
class _NeoToolbarBtn extends StatefulWidget {
  final Widget child;
  final bool isActive;
  final bool isEnabled;
  final VoidCallback? onTap;
  final String? tooltip;

  const _NeoToolbarBtn({
    required this.child,
    required this.isActive,
    this.isEnabled = true,
    required this.onTap,
    this.tooltip,
  });

  @override
  State<_NeoToolbarBtn> createState() => _NeoToolbarBtnState();
}

class _NeoToolbarBtnState extends State<_NeoToolbarBtn> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (!widget.isEnabled) {
      return Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF202026) : const Color(0xFFEADBCE),
          border: Border.all(color: Colors.black45, width: 1.5),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Center(
          child: Opacity(
            opacity: 0.35,
            child: widget.child,
          ),
        ),
      );
    }

    final isDown = _isPressed;
    final transform = isDown ? Matrix4.translationValues(1, 1, 0) : Matrix4.identity();
    final shadowOffset = isDown ? const Offset(0, 0) : const Offset(2, 2);

    Color bgColor;
    if (widget.isActive) {
      bgColor = const Color(0xFFE6B905); // Active bright yellow
    } else if (_isHovered) {
      bgColor = isDark ? const Color(0xFF383842) : const Color(0xFFEADBCE);
    } else {
      bgColor = isDark ? const Color(0xFF27272F) : const Color(0xFFF7EEDD);
    }

    final btn = MouseRegion(
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
          duration: const Duration(milliseconds: 80),
          transform: transform,
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: bgColor,
            border: Border.all(color: Colors.black, width: 2),
            borderRadius: BorderRadius.circular(6),
            boxShadow: [
              BoxShadow(
                color: Colors.black,
                offset: shadowOffset,
              ),
            ],
          ),
          child: Center(child: widget.child),
        ),
      ),
    );

    if (widget.tooltip != null) {
      return Tooltip(
        message: widget.tooltip!,
        waitDuration: const Duration(milliseconds: 500),
        child: btn,
      );
    }
    return btn;
  }
}

/// Subtle vertical divider separating toolbar tool groups
class _ToolbarDivider extends StatelessWidget {
  const _ToolbarDivider();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 1.5,
      height: 18,
      margin: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.18)
            : Colors.black.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(1),
      ),
    );
  }
}

/// Custom Vector Painter for Lucide PenTool (Gambar 2)
class _PenToolPainter extends CustomPainter {
  final Color color;

  _PenToolPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final scaleX = size.width / 24.0;
    final scaleY = size.height / 24.0;

    canvas.save();
    canvas.scale(scaleX, scaleY);

    // Lucide pen-tool path 1: handle collar
    final path1 = Path()
      ..moveTo(12, 19)
      ..lineTo(19, 12)
      ..lineTo(22, 15)
      ..lineTo(15, 22)
      ..close();
    canvas.drawPath(path1, paint);

    // Lucide pen-tool path 2: nib body
    final path2 = Path()
      ..moveTo(18, 13)
      ..lineTo(16.5, 5.5)
      ..lineTo(2, 2)
      ..lineTo(5.5, 16.5)
      ..lineTo(13, 18)
      ..lineTo(18, 13)
      ..close();
    canvas.drawPath(path2, paint);

    // Center slit from tip to breather hole
    canvas.drawLine(const Offset(2, 2), const Offset(9.5, 9.5), paint);

    // Breather hole
    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(11, 11), 1.6, dotPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _PenToolPainter oldDelegate) => oldDelegate.color != color;
}
