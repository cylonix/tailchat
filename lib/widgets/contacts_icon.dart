// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tailchat/utils/utils.dart';
import 'common_widgets.dart';
import 'main_bottom_bar.dart';
import 'stack_with_status.dart';

class ContactsIcon extends StatefulWidget {
  final bool useDefaultColor;
  final double? size;
  const ContactsIcon({super.key, this.size, this.useDefaultColor = false});

  @override
  State<ContactsIcon> createState() => _ContactsIconState();
}

class _ContactsIconState extends State<ContactsIcon> {
  bool _hasContactNotice = false;

  @override
  void initState() {
    super.initState();
    _registerToBottomBarContactNotice();
  }

  void _registerToBottomBarContactNotice() {
    final notifier = context.read<BottomBarContactNotice>();
    notifier.addListener(() {
      _hasContactNotice = notifier.hasNotice;
      Future.microtask(() {
        setState(() {
          // Trigger a rebuild with the notice state
        });
      });
    });
  }

  Widget _iconStacked(IconData icon, bool toStack, {Widget? status}) {
    return StackWithStatus(
      widget.useDefaultColor
          ? Icon(icon, size: widget.size)
          : getIcon(icon, size: widget.size, darkTheme: isDarkMode(context)),
      toStack,
      status: status,
      size: 10,
    );
  }

  Widget get _contactsIconWithNotice {
    return _iconStacked(
      isApple() ? CupertinoIcons.person_3 : Icons.supervisor_account_rounded,
      _hasContactNotice,
    );
  }

  @override
  Widget build(BuildContext context) {
    return _contactsIconWithNotice;
  }
}
