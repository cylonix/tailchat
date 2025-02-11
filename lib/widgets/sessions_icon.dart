// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tailchat/utils/utils.dart';
import 'common_widgets.dart';
import 'main_bottom_bar.dart';
import 'stack_with_status.dart';

class SessionsIcon extends StatefulWidget {
  final bool useDefaultColor;
  final Color? color;
  final double? size;
  const SessionsIcon(
      {super.key, this.color, this.size, this.useDefaultColor = false});

  @override
  State<SessionsIcon> createState() => _SessionsIconState();
}

class _SessionsIconState extends State<SessionsIcon> {
  int _sessionNoticeCount = 0;

  @override
  void initState() {
    super.initState();
    _registerToBottomBarSessionNoticeCount();
  }

  void _registerToBottomBarSessionNoticeCount() {
    final notifier = context.read<BottomBarSessionNoticeCount>();
    notifier.addListener(() {
      if (mounted) {
        setState(() {
          // Trigger a rebuild with the new session
          _sessionNoticeCount = notifier.getCount();
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return StackWithStatus(
      widget.useDefaultColor
          ? Icon(Icons.chat_rounded, color: widget.color, size: widget.size)
          : getIcon(
              Icons.chat_rounded,
              color: widget.color,
              size: widget.size,
              darkTheme: isDarkMode(context),
            ),
      _sessionNoticeCount > 0,
      size: 10,
      status: Text(
        '$_sessionNoticeCount',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 8,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
