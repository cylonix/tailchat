// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../utils/utils.dart';

class DialogAction extends StatelessWidget {
  final Widget child;
  final Function() onPressed;
  const DialogAction({super.key, required this.child, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return isApple()
        ? CupertinoDialogAction(onPressed: onPressed, child: child)
        : TextButton(
            onPressed: onPressed,
            child: Container(
              constraints: const BoxConstraints(minWidth: 60),
              child: child,
            ),
          );
  }
}
