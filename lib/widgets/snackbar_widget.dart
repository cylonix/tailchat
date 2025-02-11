// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'package:flutter/material.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';

/// Popup widget that you can use by default to show some information
class SnackbarWidget extends StatefulWidget {
  const SnackbarWidget({
    super.key,
    required this.message,
    required this.backgroundColor,
    required this.textStyle,
  });
  final String message;
  final Color backgroundColor;
  final TextStyle textStyle;

  factory SnackbarWidget.s(String message) {
    return SnackbarWidget.success(message);
  }
  factory SnackbarWidget.i(String message) {
    return SnackbarWidget.info(message);
  }
  factory SnackbarWidget.w(String message) {
    return SnackbarWidget.warn(message);
  }
  factory SnackbarWidget.e(String message) {
    return SnackbarWidget.error(message);
  }
  void show(BuildContext context) {
    showTopSnackBar(Overlay.of(context), this);
  }

  const SnackbarWidget.success(
    this.message, {
    super.key,
  })  : textStyle = const TextStyle(
          fontWeight: FontWeight.w400,
          color: Color(0xff155724),
        ),
        backgroundColor = const Color(0xffd4edda);

  const SnackbarWidget.info(
    this.message, {
    super.key,
  })  : textStyle = const TextStyle(
          fontWeight: FontWeight.w400,
          color: Color(0xff004085),
        ),
        backgroundColor = const Color(0xffcce5ff);

  const SnackbarWidget.error(
    this.message, {
    super.key,
  })  : textStyle = const TextStyle(
          fontWeight: FontWeight.w400,
          color: Color(0xff721c24),
        ),
        backgroundColor = const Color(0xfff8d7da);

  const SnackbarWidget.warn(
    this.message, {
    super.key,
  })  : textStyle = const TextStyle(
          fontWeight: FontWeight.w400,
          color: Color(0xff856404),
        ),
        backgroundColor = const Color(0xfffff3cd);

  @override
  State<SnackbarWidget> createState() => _SnackbarWidgetState();
}

class _SnackbarWidgetState extends State<SnackbarWidget> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 45,
      decoration: BoxDecoration(
        color: widget.backgroundColor,
        borderRadius: const BorderRadius.all(Radius.circular(5)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            offset: Offset(0.0, 8.0),
            spreadRadius: 1,
            blurRadius: 30,
          ),
        ],
      ),
      width: double.infinity,
      child: Stack(
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                widget.message,
                style: theme.textTheme.bodyMedium?.merge(
                  widget.textStyle,
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

typedef Toast = SnackbarWidget;
