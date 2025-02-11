// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'package:flutter/material.dart';
import 'common_widgets.dart';
import 'constants.dart';
import 'gradient_card.dart';

class SessionFeatureButton extends StatefulWidget {
  final bool? enableFocusAwareSize;
  final Widget icon;
  final double? iconSize;
  final String label;
  final void Function()? onPressed;
  final String? subLabel;
  final double? textScaleFactor;
  final double? width;
  final bool? withGradient;
  final MainAxisAlignment mainAxisAlignment;
  const SessionFeatureButton({
    super.key,
    this.enableFocusAwareSize,
    required this.icon,
    this.iconSize,
    required this.label,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.onPressed,
    this.subLabel,
    this.textScaleFactor,
    this.width,
    this.withGradient,
  });

  @override
  State<SessionFeatureButton> createState() => _SessionFeatureButtonState();
}

class _SessionFeatureButtonState extends State<SessionFeatureButton> {
  FocusNode? _focus;

  @override
  void initState() {
    super.initState();
    if (widget.enableFocusAwareSize ?? false) {
      _focus = FocusNode(debugLabel: widget.label);
      _focus?.addListener(() {
        setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _focus?.dispose();
    super.dispose();
  }

  LinearGradient get _gradient {
    return const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0xff12c2e9),
        Color.fromARGB(255, 95, 236, 201),
      ],
    );
  }

  ShapeBorder get _shape {
    return RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8.0),
    );
  }

  double get _iconSize {
    var size = widget.iconSize ?? 48;
    if (widget.enableFocusAwareSize ?? false) {
      size = focusAwareSize(context, _focus, size, zoom: 1.5);
    }
    return size;
  }

  Widget get _child {
    return Container(
      alignment: Alignment.center,
      height: _iconSize,
      width: _iconSize,
      padding: const EdgeInsets.all(12),
      child: widget.icon,
    );
  }

  Widget get _card {
    return (widget.withGradient ?? true)
        ? GradientCard(
            margin: const EdgeInsets.symmetric(vertical: 8),
            gradient: _gradient,
            shadowColor: const Color(0xff12c2e9).withValues(alpha: 0.25),
            shape: _shape,
            elevation: 4,
            child: _child,
          )
        : _child;
  }

  @override
  Widget build(BuildContext context) {
    final button = Container(
      width: widget.width,
      constraints: BoxConstraints(
        maxWidth: widget.width ?? double.infinity,
        minWidth: widget.width ?? featureButtonMinWidth,
      ),
      child: Column(
        mainAxisAlignment: widget.mainAxisAlignment,
        children: [
          _card,
          const SizedBox(height: 8),
          Text(
            widget.label,
            textAlign: TextAlign.center,
            textScaler: widget.textScaleFactor != null
                ? TextScaler.linear(widget.textScaleFactor!)
                : null,
          ),
          if (widget.subLabel != null) const SizedBox(height: 4),
          if (widget.subLabel != null)
            Text(
              widget.subLabel!,
              textAlign: TextAlign.center,
              textScaler: (widget.textScaleFactor != null)
                  ? TextScaler.linear(widget.textScaleFactor! * 0.8)
                  : null,
            ),
        ],
      ),
    );
    if (widget.onPressed == null) {
      return button;
    }
    return IconButton(
      padding: const EdgeInsets.only(bottom: 10),
      icon: button,
      focusNode: _focus,
      onPressed: widget.onPressed,
    );
  }
}
