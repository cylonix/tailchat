// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Child can't be shrink-wrapped or within another scrolling parent.
class ScrollControllerWithArrowKeys extends StatefulWidget {
  final ScrollController controller;
  final Widget child;
  const ScrollControllerWithArrowKeys({
    super.key,
    required this.controller,
    required this.child,
  });

  @override
  State<ScrollControllerWithArrowKeys> createState() =>
      _ScrollControllerWithArrowKeysState();
}

class _ScrollControllerWithArrowKeysState
    extends State<ScrollControllerWithArrowKeys> {
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  double get _scrollRange {
    return MediaQuery.of(context).size.height / 4;
  }

  void _scrollUp() {
    var offset = widget.controller.offset - _scrollRange;
    if (offset < 0) {
      offset = 0;
    }
    widget.controller.jumpTo(offset);
  }

  void _scrollDown() {
    var offset = widget.controller.offset + _scrollRange;
    if (offset > widget.controller.position.maxScrollExtent) {
      offset = widget.controller.position.maxScrollExtent;
    }
    widget.controller.jumpTo(offset);
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      onKeyEvent: (node, event) {
        if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
          _scrollUp();
          return KeyEventResult.handled;
        } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
          _scrollDown();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: widget.child,
    );
  }
}
