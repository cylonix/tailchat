// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:tailchat/utils/utils.dart';
import '../../models/theme_change_event.dart';
import '../../utils/global.dart';
import '../common_widgets.dart';

class TextScale extends StatelessWidget {
  const TextScale({super.key});

  @override
  Widget build(BuildContext context) {
    if (isApple()) {
      return CupertinoListTile(
        leading: getIcon(Icons.format_size, darkTheme: isDarkMode(context)),
        title: const Text("Format size"),
        trailing: _scaleButtonsRow,
      );
    }
    return ListTile(
      leading: getIcon(Icons.format_size, darkTheme: isDarkMode(context)),
      title: const Text("Format size"),
      trailing: SizedBox(
        width: 160,
        child: _scaleButtonsRow,
      ),
    );
  }

  Widget get _scaleButtonsRow {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        isApple()
            ? CupertinoButton(
                onPressed: () => _changeScale(add: false),
                child: const Icon(CupertinoIcons.minus),
              )
            : IconButton(
                onPressed: () => _changeScale(add: false),
                icon: const Icon(Icons.remove),
              ),
        const SizedBox(width: 16),
        isApple()
            ? CupertinoButton(
                onPressed: () => _changeScale(add: true),
                child: const Icon(CupertinoIcons.add),
              )
            : IconButton(
                onPressed: () => _changeScale(add: true),
                icon: const Icon(Icons.add),
              )
      ],
    );
  }

  void _changeScale({required bool add}) {
    Global.getThemeEventBus().fire(ThemeChangeEvent(
      textScaleFactor: add ? 1.1 : 0.9,
    ));
  }
}
