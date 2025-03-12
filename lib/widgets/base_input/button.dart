// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../api/config.dart';
import '../../utils/utils.dart';
import '../tv/icon_button.dart';

class BaseInputButton extends StatefulWidget {
  final FocusNode? focusNode;
  final bool autoFocus;
  final bool outlineButton;
  final bool filledButton;
  final bool filledTonalButton;
  final bool shrinkWrap;
  final double? height;
  final double? width;
  final Widget child;
  final void Function()? onPressed;

  const BaseInputButton({
    super.key,
    this.focusNode,
    this.autoFocus = false,
    this.outlineButton = false,
    this.filledButton = false,
    this.filledTonalButton = false,
    this.shrinkWrap = false,
    this.height,
    this.width,
    required this.child,
    required this.onPressed,
  });

  @override
  State<BaseInputButton> createState() => _BaseInputButtonWidgetState();
}

class _BaseInputButtonWidgetState extends State<BaseInputButton> {
  FocusNode? _focus;

  @override
  void initState() {
    super.initState();
    _focus = widget.focusNode ??
        (Pst.enableTV ?? false ? FocusNode(debugLabel: "base-button") : null);
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

  ButtonStyle? get _buttonStyle {
    final side = ((Pst.enableTV ?? false) && (_focus?.hasFocus ?? false))
        ? BorderSide(
            color: isDarkMode(context) ? Colors.tealAccent : Colors.blueAccent,
            width: 2,
          )
        : widget.outlineButton
            ? null // Use default side for outline button.
            : BorderSide.none;
    return ElevatedButton.styleFrom(
      minimumSize: _buttonMinSize,
      side: side,
    );
  }

  double? get _buttonWidth {
    return widget.width ?? (widget.shrinkWrap ? null : 200);
  }

  Size? get _buttonMinSize {
    final scaleDown = Pst.enableAR ?? enableARByDefault;
    final minSize =
        _buttonWidth != null ? Size(_buttonWidth!, scaleDown ? 36 : 40) : null;
    return minSize;
  }

  CupertinoButtonSize get _cupertinoButtonSize {
    return widget.shrinkWrap
        ? CupertinoButtonSize.small
        : CupertinoButtonSize.medium;
  }

  Widget get _button {
    if (widget.outlineButton) {
      return OutlinedButton(
        autofocus: widget.autoFocus,
        focusNode: _focus,
        onPressed: widget.onPressed,
        style: _buttonStyle,
        child: widget.child,
      );
    }
    if (widget.filledButton) {
      if (isApple()) {
        return CupertinoButton.filled(
          autofocus: widget.autoFocus,
          focusNode: _focus,
          onPressed: widget.onPressed,
          sizeStyle: _cupertinoButtonSize,
          child: widget.child,
        );
      }
      return FilledButton(
        autofocus: widget.autoFocus,
        focusNode: _focus,
        onPressed: widget.onPressed,
        style: _buttonStyle,
        child: widget.child,
      );
    }
    if (widget.filledTonalButton) {
      if (isApple()) {
        return CupertinoButton.tinted(
          autofocus: widget.autoFocus,
          focusNode: _focus,
          onPressed: widget.onPressed,
          sizeStyle: _cupertinoButtonSize,
          child: widget.child,
        );
      }
      return FilledButton.tonal(
        autofocus: widget.autoFocus,
        focusNode: _focus,
        onPressed: widget.onPressed,
        style: _buttonStyle,
        child: widget.child,
      );
    }
    if (isApple()) {
      return Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: CupertinoColors.systemGrey3.resolveFrom(context),
            width: 0.5,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: CupertinoButton(
          autofocus: widget.autoFocus,
          focusNode: _focus,
          onPressed: widget.onPressed,
          sizeStyle: _cupertinoButtonSize,
          child: widget.child,
        ),
      );
    }
    return ElevatedButton(
      autofocus: widget.autoFocus,
      focusNode: _focus,
      onPressed: widget.onPressed,
      style: _buttonStyle,
      child: widget.child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      width: _buttonWidth,
      child: _button,
    );
  }
}

class ClearTextButton extends IconButtonWidget {
  ClearTextButton({
    super.key,
    required TextEditingController controller,
    void Function()? moreOnPressed,
    super.focusNode,
  }) : super(
          icon: const Icon(Icons.clear),
          onPressed: () {
            controller.clear();
            moreOnPressed?.call();
          },
        );
}
