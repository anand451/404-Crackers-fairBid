import 'package:flutter/material.dart';

class AnimatedActionButton extends StatefulWidget {
  const AnimatedActionButton({
    super.key,
    required this.child,
    this.onTap,
    this.scaleDown = 0.97,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double scaleDown;

  @override
  State<AnimatedActionButton> createState() => _AnimatedActionButtonState();
}

class _AnimatedActionButtonState extends State<AnimatedActionButton> {
  double _scale = 1;

  void _reset() {
    if (!mounted) {
      return;
    }
    setState(() {
      _scale = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _scale,
      duration: const Duration(milliseconds: 130),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTapDown: widget.onTap == null
            ? null
            : (_) {
                setState(() {
                  _scale = widget.scaleDown;
                });
              },
        onTapCancel: widget.onTap == null ? null : _reset,
        onTapUp: widget.onTap == null
            ? null
            : (_) {
                _reset();
                widget.onTap?.call();
              },
        child: widget.child,
      ),
    );
  }
}
