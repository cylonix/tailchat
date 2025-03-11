// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../utils/utils.dart';

class DialogAction extends StatelessWidget {
  final Widget child;
  final bool isDestructive;
  final bool isDefault;
  final Function() onPressed;
  const DialogAction({
    super.key,
    required this.child,
    required this.onPressed,
    this.isDefault = false,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    return isApple()
        ? CupertinoDialogAction(
            onPressed: onPressed,
            isDefaultAction: isDefault,
            isDestructiveAction: isDestructive,
            child: child,
          )
        : TextButton(
            onPressed: onPressed,
            child: Container(
              constraints: const BoxConstraints(minWidth: 60),
              child: child,
            ),
          );
  }
}
