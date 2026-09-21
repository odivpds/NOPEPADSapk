import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import '../theme.dart';
import '../services/multi_window_service.dart';

/// A custom neobrutalist desktop window frame that replaces the default OS titlebar.
/// Features a branded header, draggable area, double-click maximize, resize handles,
/// and custom Minimize, Maximize/Restore, and Close buttons.
class NeoDesktopWindowFrame extends ConsumerStatefulWidget {
  final Widget child;
  final String title;

  const NeoDesktopWindowFrame({
    super.key,
    required this.child,
    this.title = 'NOPEPADS',
  });

  @override
  ConsumerState<NeoDesktopWindowFrame> createState() => _NeoDesktopWindowFrameState();
}

class _NeoDesktopWindowFrameState extends ConsumerState<NeoDesktopWindowFrame> with WindowListener {
  bool _isMaximized = false;

  bool get _isDesktop =>
      !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

  @override
  void initState() {
    super.initState();
    if (_isDesktop) {
      windowManager.addListener(this);
      _initWindowState();
    }
  }

  Future<void> _initWindowState() async {
    try {
      await windowManager.setTitleBarStyle(TitleBarStyle.hidden, windowButtonVisibility: false);
      final isMax = await windowManager.isMaximized();
      if (mounted) setState(() => _isMaximized = isMax);
    } catch (_) {}
  }

  @override
  void onWindowMaximize() {
    if (mounted) setState(() => _isMaximized = true);
  }

  @override
  void onWindowUnmaximize() {
    if (mounted) setState(() => _isMaximized = false);
  }

  @override
  void onWindowClose() async {
    await _close();
  }

  @override
  void dispose() {
    if (_isDesktop) {
      windowManager.removeListener(this);
    }
    super.dispose();
  }

  Future<void> _toggleMaximize() async {
    try {
      if (_isMaximized) {
        await windowManager.unmaximize();
      } else {
        await windowManager.maximize();
      }
    } catch (_) {}
  }

  Future<void> _minimize() async {
    try {
      await windowManager.minimize();
    } catch (_) {}
  }

  Future<void> _close() async {
    final multiWin = MultiWindowService();
    final hasActive = await multiWin.checkHasOpenStickyNotes();
    if (hasActive) {
      multiWin.isMainWindowHidden = true;
      try {
        await windowManager.hide();
      } catch (_) {}
    } else {
      exit(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb || (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS)) {
      return widget.child;
    }

    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark ||
        (themeMode == ThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.dark);

    // Dark slate in dark mode (#1E1E28), warm cream in light mode (#FFF4E0)
    final barBg = isDark ? const Color(0xFF1E1E28) : const Color(0xFFFFF4E0);
    final textMuted = isDark ? Colors.white.withValues(alpha: 0.85) : Colors.black87;
    final captionIconColor = isDark ? Colors.white.withValues(alpha: 0.9) : Colors.black87;
    final captionHoverBg = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.black.withValues(alpha: 0.08);

    return Container(
      decoration: BoxDecoration(
        border: _isMaximized ? null : Border.all(color: Colors.black, width: 2.5),
      ),
      child: DragToResizeArea(
        resizeEdgeSize: _isMaximized ? 0 : 6,
        child: Material(
          color: Colors.transparent,
          child: Column(
            children: [
              // Custom Neobrutalist Titlebar (36px)
              Container(
                height: 36,
                decoration: BoxDecoration(
                  color: barBg,
                  border: const Border(
                    bottom: BorderSide(color: Colors.black, width: 2.2),
                  ),
                ),
                child: Row(
                  children: [
                    // Left: App Logo Badge & Name (Draggable)
                    DragToMoveArea(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE6B905),
                              border: Border.all(color: Colors.black, width: 1.6),
                              borderRadius: BorderRadius.circular(4),
                              boxShadow: const [
                                BoxShadow(color: Colors.black, offset: Offset(1.2, 1.2)),
                              ],
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.edit_note_rounded, size: 13, color: Colors.black),
                                SizedBox(width: 2),
                                Text(
                                  'NP',
                                  style: TextStyle(
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.w900,
                                    fontSize: 9,
                                    color: Colors.black,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            widget.title,
                            style: NeoTheme.headingFont(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5,
                              color: textMuted,
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                      ),
                    ),

                    // Center: Draggable Spacer with Double-Tap to Maximize/Restore
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onDoubleTap: _toggleMaximize,
                        child: const DragToMoveArea(
                          child: SizedBox(
                            height: 36,
                          ),
                        ),
                      ),
                    ),

                    // Right: Caption Window Controls (Minimize, Maximize/Restore, Close)
                    _WindowCaptionButton(
                      icon: Icons.remove_rounded,
                      iconSize: 16,
                      iconColor: captionIconColor,
                      hoverBg: captionHoverBg,
                      onTap: _minimize,
                    ),
                    _WindowCaptionButton(
                      icon: _isMaximized ? Icons.filter_none_rounded : Icons.crop_square_rounded,
                      iconSize: _isMaximized ? 12 : 14,
                      iconColor: captionIconColor,
                      hoverBg: captionHoverBg,
                      onTap: _toggleMaximize,
                    ),
                    _WindowCaptionButton(
                      icon: Icons.close_rounded,
                      iconSize: 16,
                      iconColor: captionIconColor,
                      hoverColor: const Color(0xFFEF4444),
                      hoverIconColor: Colors.white,
                      onTap: _close,
                    ),
                  ],
                ),
              ),

              // Rest of App Content
              Expanded(
                child: widget.child,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WindowCaptionButton extends StatefulWidget {
  final IconData icon;
  final double iconSize;
  final VoidCallback onTap;
  final Color iconColor;
  final Color? hoverColor;
  final Color? hoverIconColor;
  final Color? hoverBg;

  const _WindowCaptionButton({
    required this.icon,
    this.iconSize = 15,
    required this.onTap,
    required this.iconColor,
    this.hoverColor,
    this.hoverIconColor,
    this.hoverBg,
  });

  @override
  State<_WindowCaptionButton> createState() => _WindowCaptionButtonState();
}

class _WindowCaptionButtonState extends State<_WindowCaptionButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final effectiveHoverBg = widget.hoverColor ?? widget.hoverBg ?? Colors.transparent;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 46,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _isHovered ? effectiveHoverBg : Colors.transparent,
          ),
          child: Icon(
            widget.icon,
            size: widget.iconSize,
            color: _isHovered ? (widget.hoverIconColor ?? widget.iconColor) : widget.iconColor,
          ),
        ),
      ),
    );
  }
}
