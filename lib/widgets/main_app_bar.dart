// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'package:flutter/material.dart';
import '../utils/global.dart';
import '../utils/utils.dart';

class MainAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String? title;
  final Widget? leading;
  final List<Widget>? trailing;
  final Widget? titleWidget;
  const MainAppBar({
    super.key,
    this.title,
    this.leading,
    this.titleWidget,
    this.trailing,
  });

  @override
  Size get preferredSize {
    return const Size.fromHeight(46);
  }

  @override
  Widget build(BuildContext context) {
    return AppBar(
      centerTitle: true,
      automaticallyImplyLeading:
          !Global.isAndroidTV, // Keep back arrow for emulated TV.
      elevation: 0.0,
      backgroundColor: defaultBackgroundColor(context),
      title: titleWidget ?? Text(title ?? ""),
      leading: leading,
      actions: trailing,
      foregroundColor: defaultForegroundColor(context),
    );
  }

  static Color? defaultBackgroundColor(BuildContext context) {
    if (enableMaterial3()) {
      return null;
    }
    final t = Theme.of(context);
    return t.canvasColor;
  }

  static Color? defaultForegroundColor(BuildContext context) {
    if (enableMaterial3()) {
      return null;
    }
    final t = Theme.of(context);
    return t.colorScheme.inverseSurface;
  }
}
