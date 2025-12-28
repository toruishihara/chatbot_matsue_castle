import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../view_model/chat_view_model.dart';

class ShakeIcon extends StatefulWidget {
  final bool shake;
  final VoidCallback onPressed;

  const ShakeIcon({
    super.key,
    required this.shake,
    required this.onPressed,
  });

  @override
  State<ShakeIcon> createState() => _ShakeIconState();
}

class _ShakeIconState extends State<ShakeIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _offset;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _offset = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: -6), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -6, end: 6), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 6, end: 0), weight: 1),
    ]).animate(_controller);
  }

  @override
  void didUpdateWidget(covariant ShakeIcon oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.shake) {
      _controller.repeat();
    } else {
      _controller.stop();
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _offset,
      builder: (_, child) {
        return Transform.translate(
          offset: Offset(_offset.value, 0),
          child: child,
        );
      },
      child: IconButton(
        icon: const Icon(Icons.mic),
        onPressed: widget.onPressed,
      ),
    );
  }
}