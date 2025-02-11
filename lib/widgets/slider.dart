// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'package:flutter/material.dart';

class SliderWidget extends StatefulWidget {
  final double width;
  final int flexScale;
  final int initialFlex;
  final Color? color;
  final void Function(int flex)? onFlexChanged;
  const SliderWidget({
    super.key,
    required this.width,
    required this.initialFlex,
    required this.flexScale,
    this.color,
    this.onFlexChanged,
  });

  @override
  State<SliderWidget> createState() => _SliderWidgetState();
}

class _SliderWidgetState extends State<SliderWidget> {
  bool _isDividerActive = false;
  late int _currentFlex;

  @override
  void initState() {
    super.initState();
    _currentFlex = widget.initialFlex;
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).canvasColor;
    final initialX = widget.width * widget.initialFlex / widget.flexScale;

    return GestureDetector(
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeLeftRight,
        child: Container(
          color: widget.color ?? color,
          margin: const EdgeInsets.all(0),
          child: VerticalDivider(
              width: _isDividerActive ? 6 : 4,
              thickness: _isDividerActive ? 6 : 1,
              color: _isDividerActive ? Colors.blue : widget.color),
        ),
      ),
      onHorizontalDragUpdate: (details) {
        final offset = details.localPosition;
        final flex =
            ((initialX + offset.dx) * widget.flexScale / widget.width).floor();
        if (flex != _currentFlex) {
          _currentFlex = flex;
          widget.onFlexChanged?.call(flex);
        }
      },
      onHorizontalDragEnd: (details) {
        setState(() {
          _isDividerActive = false;
        });
      },
      onTapDown: (_) {
        setState(() {
          _isDividerActive = true;
        });
      },
      onTapUp: (_) {
        setState(() {
          _isDividerActive = false;
        });
      },
    );
  }
}
