// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../api/config.dart';
import '../../utils/utils.dart';
import '../tv/icon_button.dart';
import 'button.dart';
import 'decoration.dart';

class BaseTextInput extends StatefulWidget {
  final String? text;
  final String? label;
  final String? hint;
  final void Function(String)? onChanged;
  final void Function(String)? onSubmitted;
  final String? Function(String?)? validator;
  final IconData? icon;
  final Widget? suffixIcon;
  final FocusNode? focus;
  final FocusNode? prevFocus;
  final FocusNode? nextFocus;
  final bool autoFocus;
  final bool obscureText;
  final bool readOnly;
  final int? maxLines;
  final InputBorder? border;
  final TextInputAction? inputAction;
  final TextInputType? keyboardType;
  final AutovalidateMode autovalidateMode;
  final Widget? editIcon;
  final GlobalKey<FormFieldState>? formKey;
  final TextEditingController? controller;
  const BaseTextInput({
    super.key,
    this.autoFocus = false,
    this.autovalidateMode = AutovalidateMode.onUserInteraction,
    this.border,
    this.controller,
    this.editIcon,
    this.focus,
    this.formKey,
    this.icon,
    this.inputAction,
    this.hint,
    this.keyboardType,
    this.label,
    this.maxLines = 1,
    this.nextFocus,
    this.obscureText = false,
    this.onChanged,
    this.onSubmitted,
    this.prevFocus,
    this.readOnly = false,
    this.suffixIcon,
    this.text,
    this.validator,
  });

  @override
  State<BaseTextInput> createState() => _BaseTextInputState();
}

class _BaseTextInputState extends State<BaseTextInput> {
  late final FocusNode _rootFocus;
  late final FocusNode _clearButtonFocus;
  late final GlobalKey<FormFieldState> _key;
  late final TextEditingController _controller;
  FocusNode? _focus, _textInputFocus;
  bool _showClearButton = false;
  bool _readOnly = false;
  bool _addTextInputFocus = false;

  @override
  void initState() {
    super.initState();
    final label = widget.label;
    _controller = widget.controller ?? TextEditingController();
    _controller.text = widget.text ?? _controller.text;
    _clearButtonFocus = FocusNode(debugLabel: "$label-clear-button");
    _focus = widget.focus ?? FocusNode(debugLabel: "$label-self-managed");
    _addTextInputFocus = _defaultToReadOnly;
    _textInputFocus = _addTextInputFocus
        ? FocusNode(debugLabel: "$label-input-field")
        : _focus;
    _key = widget.formKey ?? GlobalKey<FormFieldState>();
    _textInputFocus?.addListener(() {
      _setShowClearButton();
    });
    _readOnly = _defaultToReadOnly;
    _rootFocus = FocusNode(debugLabel: "$label-root");
  }

  bool get _defaultToReadOnly {
    return widget.readOnly ||
        (Pst.enableAR ?? false) ||
        (Pst.enableTV ?? false);
  }

  void _setShowClearButton() {
    if (!mounted) {
      return;
    }
    setState(() {
      final hasFocus = _textInputFocus?.hasFocus ?? false;
      _showClearButton = hasFocus && _controller.text.isNotEmpty;
    });
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _controller.dispose();
    }
    _clearButtonFocus.dispose();
    if (widget.focus == null) {
      _focus?.dispose();
    }
    if (_addTextInputFocus) {
      _textInputFocus?.dispose();
    }
    _rootFocus.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _setShowClearButton();
    widget.onChanged?.call(value);
  }

  Widget get _clearButton {
    return ClearTextButton(
      controller: _controller,
      moreOnPressed: () => _onChanged(""),
      focusNode: _clearButtonFocus,
    );
  }

  void _handleMoveFocus(bool next) {
    if (_defaultToReadOnly && (_textInputFocus?.hasPrimaryFocus ?? false)) {
      // Text input field has the primary focus. User wants to end inputting.
      // Setting widget back to read only.
      setState(() {
        _readOnly = true;
      });
    }
    if (next) {
      if (widget.nextFocus == null) {
        _clearButtonFocus.skipTraversal = true;
        _rootFocus.nextFocus();
        _clearButtonFocus.skipTraversal = false;
      } else {
        widget.nextFocus?.requestFocus();
      }
    } else {
      if (widget.prevFocus == null) {
        _textInputFocus?.previousFocus();
      } else {
        widget.prevFocus?.requestFocus();
      }
    }
  }

  bool get _showReadOnlyClearButton {
    return !widget.readOnly &&
        _controller.text.isNotEmpty &&
        widget.editIcon != null;
  }

  @override
  Widget build(BuildContext context) {
    if (_readOnly) {
      var label = _controller.text;
      if (widget.label != null) {
        label = "${widget.label}: $label";
      } else if (label.isNotEmpty && widget.hint != null) {
        label = "${widget.hint}: $label";
      }
      return Row(
        children: [
          if (widget.icon != null) Icon(widget.icon!),
          const SizedBox(width: 8),
          _showReadOnlyClearButton ? Expanded(child: Text(label)) : Text(label),
          if (_showReadOnlyClearButton) _clearButton,
          if (!widget.readOnly)
            _showReadOnlyClearButton
                ? _editButton(_focus)
                : Expanded(child: _editButton(_focus)),
          //if (Platform.isAndroid) _voiceButton,
        ],
      );
    }
    return Focus(
      focusNode: _rootFocus,
      onFocusChange: (value) {
        if (value != true) {
          setState(() {
            _readOnly = _defaultToReadOnly;
          });
        }
      },
      onKeyEvent: (node, event) {
        if (event is KeyUpEvent &&
            event.logicalKey == LogicalKeyboardKey.goBack) {
          if (_defaultToReadOnly && !_readOnly) {
            setState(() {
              _readOnly = true;
            });
            return KeyEventResult.handled;
          }
        }
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.tab) {
          _handleMoveFocus(true);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: _input,
    );
  }

  void _onSubmitted(String value) {
    if (_key.currentState?.validate() == false) {
      return;
    }
    widget.onSubmitted?.call(value);
    _handleMoveFocus(true);
  }

  Widget _editButton(FocusNode? focus) {
    return IconButtonWidget(
      alignment: Alignment.centerRight,
      icon: widget.editIcon ?? const Icon(Icons.edit),
      onPressed: () {
        setState(() {
          _readOnly = false;
          _textInputFocus?.requestFocus();
        });
      },
      focusNode: focus,
    );
  }

  Widget get _input {
    return TextFormField(
      key: _key,
      focusNode: _textInputFocus,
      autofocus: widget.autoFocus,
      controller: _controller,
      onChanged: _onChanged,
      readOnly: _readOnly,
      autovalidateMode: widget.autovalidateMode,
      onFieldSubmitted:
          (widget.inputAction != null && widget.onSubmitted == null)
              ? null
              : _onSubmitted,
      textInputAction: widget.inputAction,
      textAlignVertical: TextAlignVertical.center,
      obscureText: widget.obscureText,
      maxLines: widget.maxLines,
      keyboardType: widget.keyboardType,
      validator: widget.validator,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        focusedBorder: _readOnly
            ? InputBorder.none
            : (widget.border ??
                BaseInputBorder.border(
                  color: focusColor(context),
                )),
        prefixIcon: widget.icon != null ? Icon(widget.icon) : null,
        suffixIcon:
            widget.suffixIcon ?? (_showClearButton ? _clearButton : null),
        contentPadding: BaseInputEdgeInsets.padding,
        border: _readOnly
            ? InputBorder.none
            : widget.border ?? BaseInputBorder.border(),
      ),
    );
  }
}

class MoveNextIntent extends Intent {
  const MoveNextIntent();
}

class MovePreviousIntent extends Intent {
  const MovePreviousIntent();
}
