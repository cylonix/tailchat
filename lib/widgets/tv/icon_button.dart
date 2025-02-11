// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'package:flutter/material.dart';
import '../../api/config.dart';
import '../../utils/utils.dart';
import '../common_widgets.dart';

/// Focus-aware icon button.
class IconButtonWidget extends StatefulWidget {
  final Alignment? alignment;
  final String? debugLabel;
  final FocusNode? focusNode;
  final double? focusZoom;
  final Widget icon;
  final void Function() onPressed;
  final EdgeInsetsGeometry? padding;
  final double? size;
  final String? tooltip;
  const IconButtonWidget({
    super.key,
    this.alignment,
    this.debugLabel,
    this.focusNode,
    this.focusZoom,
    required this.icon,
    required this.onPressed,
    this.padding,
    this.size,
    this.tooltip,
  });

  @override
  State<IconButtonWidget> createState() => _IconButtonWidgetState();
}

class _IconButtonWidgetState extends State<IconButtonWidget> {
  FocusNode? _focus;

  @override
  void initState() {
    super.initState();
    _focus = widget.focusNode ??
        (Pst.enableTV ?? false
            ? FocusNode(debugLabel: widget.debugLabel)
            : null);
    _focus?.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    if (widget.focusNode == null) {
      _focus?.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      padding: widget.padding,
      alignment: widget.alignment,
      focusNode: _focus,
      focusColor: focusColor(context),
      iconSize: focusAwareSize(
        context,
        _focus,
        widget.size ?? (Pst.enableTV ?? false ? 32 : 24),
      ),
      icon: widget.icon,
      onPressed: widget.onPressed,
      tooltip: widget.tooltip,
    );
  }
}
