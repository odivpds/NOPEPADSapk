import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// A wrapper widget that provides silky smooth, momentum-damped mouse wheel
/// scrolling for desktop platforms (Windows/macOS/Linux/Web).
///
/// Prevents the harsh, stepped/teleporting mouse wheel jumps in Flutter
/// by intercepting pointer scroll events and animating the controller smoothly.
class SmoothMouseScroll extends StatefulWidget {
  final ScrollController controller;
  final Widget child;

  /// Multiplier to control scrolling speed. Defaults to 0.72 for comfortable,
  /// controlled browsing that doesn't scroll too fast.
  final double speedMultiplier;

  /// Duration of the smooth glide animation per scroll impulse.
  final Duration animationDuration;

  /// Easing curve. Defaults to [Curves.easeOutCubic] for instant responsiveness
  /// followed by buttery smooth deceleration.
  final Curve curve;

  const SmoothMouseScroll({
    super.key,
    required this.controller,
    required this.child,
    this.speedMultiplier = 0.72,
    this.animationDuration = const Duration(milliseconds: 260),
    this.curve = Curves.easeOutCubic,
  });

  @override
  State<SmoothMouseScroll> createState() => _SmoothMouseScrollState();
}

class _SmoothMouseScrollState extends State<SmoothMouseScroll>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  Animation<double>? _animation;
  double _targetOffset = 0.0;
  double _startOffset = 0.0;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
    )..addListener(_onAnimationTick);

    widget.controller.addListener(_onControllerScroll);
  }

  @override
  void dispose() {
    _animController.dispose();
    widget.controller.removeListener(_onControllerScroll);
    super.dispose();
  }

  void _onControllerScroll() {
    if (!_animController.isAnimating) {
      if (widget.controller.hasClients) {
        _targetOffset = widget.controller.offset;
      }
    }
  }

  void _onAnimationTick() {
    if (_animation != null && widget.controller.hasClients) {
      final value = _animation!.value;
      final max = widget.controller.position.maxScrollExtent;
      final min = widget.controller.position.minScrollExtent;
      final clamped = value.clamp(min, max);
      widget.controller.jumpTo(clamped);
    }
  }

  void _handlePointerScroll(PointerScrollEvent event) {
    if (!widget.controller.hasClients) return;

    final position = widget.controller.position;
    final maxScroll = position.maxScrollExtent;
    final minScroll = position.minScrollExtent;

    if (maxScroll <= minScroll) return;

    final currentOffset = widget.controller.offset;
    if (!_animController.isAnimating) {
      _targetOffset = currentOffset;
    }

    final double delta = event.scrollDelta.dy * widget.speedMultiplier;
    _targetOffset = (_targetOffset + delta).clamp(minScroll, maxScroll);
    _startOffset = currentOffset;

    _animController.stop();
    _animation = Tween<double>(
      begin: _startOffset,
      end: _targetOffset,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: widget.curve,
    ));

    _animController.duration = widget.animationDuration;
    _animController.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerSignal: (pointerSignal) {
        if (pointerSignal is PointerScrollEvent) {
          GestureBinding.instance.pointerSignalResolver.register(
            pointerSignal,
            (event) {
              _handlePointerScroll(event as PointerScrollEvent);
            },
          );
        }
      },
      child: widget.child,
    );
  }
}
