// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'package:flutter/material.dart';
import 'dart:math';

class ShakeWidget extends StatefulWidget {
  final Widget child;
  final double shakeOffset;
  final int shakeCount;

  const ShakeWidget({
    super.key,
    required this.child,
    this.shakeOffset = 10,
    this.shakeCount = 2,
  });

  @override
  State<ShakeWidget> createState() => ShakeWidgetState();
}

class ShakeWidgetState extends State<ShakeWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: Duration(milliseconds: 500),
      vsync: this,
    );

    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0, 1, curve: Curves.easeOut),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void shake() {
    _controller.reset();
    _controller.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(
            (cos(_animation.value * widget.shakeCount * pi) *
                    widget.shakeOffset *
                    _animation.value)
                .toDouble(),
            0,
          ),
          child: widget.child,
        );
      },
    );
  }
}
