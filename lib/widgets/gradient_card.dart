// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'package:flutter/material.dart';

class GradientCard extends StatelessWidget {
  const GradientCard({
    super.key,
    required this.gradient,
    this.shape,
    this.margin = const EdgeInsets.all(4),
    this.clipBehavior = Clip.none,
    this.child,
    this.elevation,
    this.shadowColor,
    this.semanticContainer = true,
  });

  final ShapeBorder? shape;
  final Clip clipBehavior;
  final EdgeInsetsGeometry margin;
  final bool semanticContainer;
  final Widget? child;
  final LinearGradient gradient;
  final double? elevation;
  final Color? shadowColor;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: semanticContainer,
      explicitChildNodes: !semanticContainer,
      child: Material(
        type: MaterialType.card,
        color: Colors.transparent,
        shadowColor: shadowColor ?? Colors.transparent,
        elevation: elevation ?? 0,
        shape: shape ??
            const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(4)),
            ),
        clipBehavior: clipBehavior,
        child: Container(
          margin: margin,
          decoration: ShapeDecoration(
            shape: shape ??
                const RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(4)),
                ),
            gradient: gradient,
          ),
          child: child,
        ),
      ),
    );
  }
}
