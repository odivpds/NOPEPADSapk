import 'package:flutter/material.dart';
import '../theme.dart';

class TourStep {
  final String content;
  final GlobalKey? targetKey;
  final String placement; // 'center', 'bottom', 'left'

  const TourStep({
    required this.content,
    this.targetKey,
    this.placement = 'center',
  });
}

class OnboardingTourOverlay extends StatefulWidget {
  final int currentStep;
  final List<TourStep> steps;
  final VoidCallback onNext;
  final VoidCallback onBack;
  final VoidCallback onSkip;
  final VoidCallback onClose;

  const OnboardingTourOverlay({
    super.key,
    required this.currentStep,
    required this.steps,
    required this.onNext,
    required this.onBack,
    required this.onSkip,
    required this.onClose,
  });

  @override
  State<OnboardingTourOverlay> createState() => _OnboardingTourOverlayState();
}

class _OnboardingTourOverlayState extends State<OnboardingTourOverlay> {
  Rect? _targetRect;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateTargetRect());
  }

  @override
  void didUpdateWidget(covariant OnboardingTourOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentStep != widget.currentStep) {
      _updateTargetRect();
      WidgetsBinding.instance.addPostFrameCallback((_) => _updateTargetRect());
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateTargetRect());
  }

  void _updateTargetRect() {
    if (!mounted) return;
    if (widget.currentStep >= widget.steps.length) return;
    final key = widget.steps[widget.currentStep].targetKey;
    if (key == null) {
      if (_targetRect != null) setState(() => _targetRect = null);
      return;
    }
    final targetContext = key.currentContext;
    if (targetContext == null) {
      if (_targetRect != null) setState(() => _targetRect = null);
      return;
    }
    final targetRenderBox = targetContext.findRenderObject() as RenderBox?;
    if (targetRenderBox == null || !targetRenderBox.hasSize) {
      if (_targetRect != null) setState(() => _targetRect = null);
      return;
    }

    // Convert target offset to the local coordinate system of this overlay
    final overlayRenderBox = context.findRenderObject() as RenderBox?;
    final targetGlobal = targetRenderBox.localToGlobal(Offset.zero);
    final Offset targetLocal;
    if (overlayRenderBox != null && overlayRenderBox.hasSize) {
      targetLocal = overlayRenderBox.globalToLocal(targetGlobal);
    } else {
      targetLocal = targetGlobal;
    }

    final newRect = targetLocal & targetRenderBox.size;
    if (_targetRect != newRect) {
      setState(() {
        _targetRect = newRect;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final step = widget.steps[widget.currentStep];
    final isLastStep = widget.currentStep == widget.steps.length - 1;

    final tooltipWidth = (screenSize.width - 32).clamp(320.0, 360.0);

    // Calculate position
    double posX = (screenSize.width - tooltipWidth) / 2;
    double posY = (screenSize.height - 220) / 2;

    if (_targetRect != null) {
      if (step.placement == 'bottom') {
        posX = _targetRect!.left.clamp(16.0, screenSize.width - tooltipWidth - 16.0);
        posY = _targetRect!.bottom + 16;
      } else if (step.placement == 'left') {
        posX = (_targetRect!.left - tooltipWidth - 16).clamp(16.0, screenSize.width - tooltipWidth - 16.0);
        posY = _targetRect!.top.clamp(16.0, screenSize.height - 240);
        if (_targetRect!.left - tooltipWidth < 20) {
          // If not enough room on the left, show below
          posX = (_targetRect!.right - tooltipWidth).clamp(16.0, screenSize.width - tooltipWidth - 16.0);
          posY = _targetRect!.bottom + 16;
        }
      }
    }

    // Ensure within screen
    posX = posX.clamp(16.0, screenSize.width - tooltipWidth - 16.0);
    posY = posY.clamp(16.0, screenSize.height - 260.0);

    return Stack(
      children: [
        // Spotlight Background with Animated Cutout Transition
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {}, // Block taps outside tooltip during tour
            child: _targetRect == null
                ? CustomPaint(
                    painter: _TourSpotlightPainter(
                      targetRect: null,
                      overlayColor: Colors.black.withValues(alpha: 0.65),
                      borderColor: const Color(0xFFE6B905),
                    ),
                  )
                : TweenAnimationBuilder<Rect?>(
                    key: const ValueKey('tour_spotlight_anim'),
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutCubic,
                    tween: RectTween(begin: _targetRect, end: _targetRect),
                    builder: (context, animatedRect, _) {
                      return CustomPaint(
                        painter: _TourSpotlightPainter(
                          targetRect: animatedRect ?? _targetRect,
                          overlayColor: Colors.black.withValues(alpha: 0.65),
                          borderColor: const Color(0xFFE6B905),
                        ),
                      );
                    },
                  ),
          ),
        ),

        // Tooltip Card (Image 2)
        AnimatedPositioned(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          left: posX,
          top: posY,
          width: tooltipWidth,
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(24.0),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF27272A) : Colors.white,
                border: Border.all(color: Colors.black, width: 4),
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(color: Colors.black, offset: Offset(8, 8)),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Step Header & Close Button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'STEP ${widget.currentStep + 1}',
                        style: NeoTheme.headingFont(
                          color: const Color(0xFFE6B905),
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          letterSpacing: 1.5,
                          shadows: const [
                            Shadow(color: Colors.black, offset: Offset(1, 1)),
                          ],
                        ),
                      ),
                      MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: widget.onClose,
                          child: Icon(
                            Icons.close,
                            size: 20,
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 2,
                    color: isDark ? Colors.white12 : Colors.black12,
                    margin: const EdgeInsets.only(bottom: 16),
                  ),

                  // Step Content
                  Text(
                    step.content,
                    style: NeoTheme.sansFont(
                      color: isDark ? Colors.white : Colors.black,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Actions (Skip on left, Back/Next on right)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: widget.onSkip,
                          child: Text(
                            'SKIP',
                            style: NeoTheme.headingFont(
                              color: isDark ? Colors.white54 : Colors.black45,
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (widget.currentStep > 0) ...[
                            _TourButton(
                              text: 'BACK',
                              backgroundColor: isDark ? const Color(0xFF3F3F46) : const Color(0xFFE5E7EB),
                              textColor: isDark ? Colors.white : Colors.black,
                              onTap: widget.onBack,
                            ),
                            const SizedBox(width: 8),
                          ],
                          _TourButton(
                            text: isLastStep ? 'FINISH' : 'NEXT',
                            backgroundColor: const Color(0xFFE6B905),
                            textColor: Colors.black,
                            onTap: widget.onNext,
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TourButton extends StatefulWidget {
  final String text;
  final Color backgroundColor;
  final Color textColor;
  final VoidCallback onTap;

  const _TourButton({
    required this.text,
    required this.backgroundColor,
    required this.textColor,
    required this.onTap,
  });

  @override
  State<_TourButton> createState() => _TourButtonState();
}

class _TourButtonState extends State<_TourButton> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isDown = _isHovered || _isPressed;
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
          transform: isDown ? Matrix4.translationValues(1, 1, 0) : Matrix4.identity(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: widget.backgroundColor,
            border: Border.all(color: Colors.black, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black,
                offset: isDown ? const Offset(1, 1) : const Offset(2, 2),
              ),
            ],
          ),
          child: Text(
            widget.text.toUpperCase(),
            style: NeoTheme.headingFont(
              color: widget.textColor,
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}

class _TourSpotlightPainter extends CustomPainter {
  final Rect? targetRect;
  final Color overlayColor;
  final Color borderColor;

  _TourSpotlightPainter({
    required this.targetRect,
    required this.overlayColor,
    required this.borderColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPath = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    if (targetRect == null) {
      canvas.drawPath(backgroundPath, Paint()..color = overlayColor);
      return;
    }

    final cutoutRect = RRect.fromRectAndRadius(
      targetRect!.inflate(6),
      const Radius.circular(8),
    );
    final cutoutPath = Path()..addRRect(cutoutRect);

    final finalPath = Path.combine(PathOperation.difference, backgroundPath, cutoutPath);
    canvas.drawPath(finalPath, Paint()..color = overlayColor);

    // Draw neobrutalist border
    canvas.drawRRect(
      cutoutRect,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(covariant _TourSpotlightPainter oldDelegate) =>
      oldDelegate.targetRect != targetRect ||
      oldDelegate.overlayColor != overlayColor ||
      oldDelegate.borderColor != borderColor;
}

// Decision Modal for Returning Users (Image 3)
class WelcomeBackDecisionDialog extends StatelessWidget {
  final String userName;
  final VoidCallback onStartTour;
  final VoidCallback onDismiss;

  const WelcomeBackDecisionDialog({
    super.key,
    required this.userName,
    required this.onStartTour,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final displayName = userName.trim().isEmpty ? 'EXPLORER' : userName.toUpperCase();

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        width: 440,
        padding: const EdgeInsets.all(32.0),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF27272A) : Colors.white,
          border: Border.all(color: Colors.black, width: 4),
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(color: Colors.black, offset: Offset(12, 12)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Title
            Text(
              'WELCOME BACK!',
              style: NeoTheme.headingFont(
                color: const Color(0xFFE6B905),
                fontWeight: FontWeight.w900,
                fontSize: 26,
                letterSpacing: 2.0,
                shadows: const [
                  Shadow(color: Colors.black, offset: Offset(2, 2)),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Description text
            Text(
              'Welcome back to NOPEPADS, $displayName! Do you still remember how to use the features here?',
              style: NeoTheme.sansFont(
                color: isDark ? Colors.white : Colors.black,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),

            // Buttons: Yep, I got this! / Remind me!
            Row(
              children: [
                Expanded(
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: onDismiss,
                      child: Text(
                        'YEP, I GOT THIS!',
                        textAlign: TextAlign.center,
                        style: NeoTheme.headingFont(
                          color: isDark ? Colors.white70 : Colors.black54,
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _DecisionButton(
                    text: 'REMIND ME!',
                    onTap: onStartTour,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DecisionButton extends StatefulWidget {
  final String text;
  final VoidCallback onTap;

  const _DecisionButton({required this.text, required this.onTap});

  @override
  State<_DecisionButton> createState() => _DecisionButtonState();
}

class _DecisionButtonState extends State<_DecisionButton> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isDown = _isHovered || _isPressed;
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
          transform: isDown ? Matrix4.translationValues(2, 2, 0) : Matrix4.identity(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFE6B905),
            border: Border.all(color: Colors.black, width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.black,
                offset: isDown ? const Offset(2, 2) : const Offset(4, 4),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            widget.text,
            style: NeoTheme.headingFont(
              color: Colors.black,
              fontWeight: FontWeight.w900,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}