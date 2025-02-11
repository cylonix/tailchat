// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'package:flutter/material.dart';

class InkWellButton extends StatelessWidget {
  final Widget? child;
  final Color? color;
  final void Function() onTap;
  const InkWellButton({super.key, this.child, this.color, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Material(
      type: color == null ? MaterialType.transparency : MaterialType.button,
      color: color,
      child: InkWell(onTap: onTap, child: child),
    );
  }
}
