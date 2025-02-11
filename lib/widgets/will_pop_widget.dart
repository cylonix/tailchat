// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:overlay_support/overlay_support.dart';

class WillPopWidget extends StatefulWidget {
  final Widget child;
  final Function()? onPop;
  final String? popMessage;
  const WillPopWidget({
    required this.child,
    this.onPop,
    this.popMessage,
    super.key,
  });

  @override
  State<WillPopWidget> createState() => _WillPopWidgetState();
}

class _WillPopWidgetState extends State<WillPopWidget> {
  bool _willPopOnce = false;

  @override
  Widget build(BuildContext context) {
    // ignore: deprecated_member_use
    return WillPopScope(
      onWillPop: () async {
        final scaffold = Scaffold.maybeOf(context);
        if ((scaffold?.isDrawerOpen ?? false) ||
            (scaffold?.isEndDrawerOpen ?? false)) {
          return true;
        }
        if (_willPopOnce) {
          widget.onPop?.call();
          return true;
        }
        if (widget.popMessage != null) {
          toast(widget.popMessage!);
        }
        _willPopOnce = true;
        Future.delayed(
          const Duration(seconds: 10),
          () => _willPopOnce = false,
        );
        return false;
      },
      child: widget.child,
    );
  }
}
