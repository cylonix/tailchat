// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'package:flutter/material.dart';

/// LeftSide widget for TV shows a navigation or information pane of the TV
/// screen. This can be used for functional buttons or simply showing the
/// description of the actions of the right side of the screen.
class LeftSide extends StatelessWidget {
  final List<Widget> children;
  final MainAxisAlignment mainAxisAlignment;
  final Color? color;
  final double? width;
  final EdgeInsetsGeometry? padding;
  const LeftSide({
    super.key,
    this.color,
    this.padding,
    this.width,
    this.mainAxisAlignment = MainAxisAlignment.spaceEvenly,
    required this.children,
  });

  Widget get _body {
    return Column(
      mainAxisAlignment: mainAxisAlignment,
      children: children,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(16),
      alignment: Alignment.center,
      color: color ?? Theme.of(context).cardColor,
      width: width,
      child: _body,
    );
  }
}
