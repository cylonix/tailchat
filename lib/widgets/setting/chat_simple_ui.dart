// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'package:flutter/material.dart';
import '../../api/config.dart';
import '../../gen/l10n/app_localizations.dart';
import '../../utils/utils.dart';
import '../common_widgets.dart';

class ChatSimpleUI extends StatefulWidget {
  const ChatSimpleUI({
    super.key,
  });
  @override
  State<ChatSimpleUI> createState() => _ChatSimpleUIState();
}

class _ChatSimpleUIState extends State<ChatSimpleUI> {
  bool _simpleUI = Pst.chatSimpleUI ?? false;

  @override
  Widget build(BuildContext context) {
    return _setChatSimpleUIOnOff;
  }

  void _setChatSimpleUI(bool enable) async {
    final success = await Pst.saveChatSimpleUISetting(enable);
    if (mounted) {
      if (success) {
        setState(() {
          _simpleUI = enable;
        });
      } else {
        final tr = AppLocalizations.of(context);
        await showAlertDialog(
          context,
          tr.prompt,
          tr.failedToSaveChangeText,
          showCancel: false,
        );
      }
    }
  }

  Widget get _setChatSimpleUIOnOff {
    final tr = AppLocalizations.of(context);
    return ListTile(
      leading: getIcon(
        Icons.chat_bubble_outline_rounded,
        darkTheme: isDarkMode(context),
      ),
      trailing: Switch.adaptive(
        value: _simpleUI,
        onChanged: _setChatSimpleUI,
      ),
      title: Text(tr.simpleChatUI),
      onTap: () => _setChatSimpleUI(!_simpleUI),
    );
  }
}
