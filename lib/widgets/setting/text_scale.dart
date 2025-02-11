// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'package:flutter/material.dart';
import 'package:tailchat/utils/utils.dart';
import '../../models/theme_change_event.dart';
import '../../utils/global.dart';
import '../common_widgets.dart';

class TextScale extends StatelessWidget {
  const TextScale({super.key});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: getIcon(Icons.format_size, darkTheme: isDarkMode(context)),
      title: const Text("Format size"),
      trailing: SizedBox(
        width: 160,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            ElevatedButton(
              child: const Icon(Icons.remove),
              onPressed: () => _changeScale(add: false),
            ),
            const SizedBox(width: 16),
            ElevatedButton(
              child: const Icon(Icons.add),
              onPressed: () => _changeScale(add: true),
            )
          ],
        ),
      ),
    );
  }

  void _changeScale({required bool add}) {
    Global.getThemeEventBus().fire(ThemeChangeEvent(
      textScaleFactor: add ? 1.1 : 0.9,
    ));
  }
}
