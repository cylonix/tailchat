// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'package:flutter/material.dart';
import '../gen/l10n/app_localizations.dart';
import '../models/chat/chat_session.dart';
import 'chat/add_group_chat.dart';
import 'chat/add_user_chat.dart';
import 'tv/caption.dart';
import 'tv/icon_button.dart';
import 'tv/left_side.dart';
import 'tv/menu_button.dart';

class AddSession {
  final String label;
  final Icon icon;
  final void Function(BuildContext) action;
  final bool enabled;
  const AddSession({
    required this.label,
    required this.icon,
    required this.action,
    this.enabled = false,
  });
}

/// AddSessionWidget creates a menu for creating new group or individual chat
class AddSessionWidget extends StatelessWidget {
  final void Function(ChatSession session) onNewChat;
  final String? Function(String) validateGroupName;
  final bool showAsLeftSide;
  final Color? color;
  final double? iconSize;
  final Widget? leading;

  const AddSessionWidget({
    super.key,
    required this.validateGroupName,
    required this.onNewChat,
    this.showAsLeftSide = false,
    this.color,
    this.iconSize,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    final tr = AppLocalizations.of(context);
    final options = <AddSession>[
      AddSession(
        label: tr.chatWithAUserOnDeviceText,
        icon: Icon(Icons.computer_rounded),
        action: (context) => newUserChat(context, true, onNewChat),
        enabled: true,
      ),
      AddSession(
        label: tr.chatWithAUserText,
        icon: Icon(Icons.account_circle_rounded),
        action: (context) => newUserChat(context, false, onNewChat),
      ),
      AddSession(
        label: tr.addGroupChatText,
        icon: Icon(Icons.supervised_user_circle_rounded),
        action: (context) => newGroupChat(
          context,
          onNewChat: onNewChat,
          validateGroupName: validateGroupName,
        ),
      ),
    ];

    if (showAsLeftSide) {
      return LeftSide(
        width: 300,
        padding: const EdgeInsets.all(0),
        children: [
          if (leading == null) const SizedBox(height: 32),
          if (leading == null) Caption(context, tr.sessionsTitle),
          if (leading != null) leading!,
          if (leading != null) const Divider(height: 1),
          const SizedBox(height: 32),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: options
                  .map(
                    (a) => Expanded(
                      child: Material(
                        type: MaterialType.transparency,
                        child: ListTile(
                          leading: a.icon,
                          title: Text(a.label),
                          trailing:
                              a.enabled ? null : Text("Not supported yet"),
                          onTap:
                              a.enabled ? () => a.action.call(context) : null,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 32),
        ],
      );
    }

    return MenuButtonWidget(
      builder: (context, controller, child) {
        if (controller == null) {
          return Icon(
            Icons.add,
            size: iconSize,
            color: Theme.of(context).colorScheme.secondary,
          );
        }
        return IconButtonWidget(
          focusZoom: 1.5,
          icon: const Icon(Icons.add),
          size: iconSize,
          onPressed: () {
            controller.isOpen ? controller.close() : controller.open();
          },
        );
      },
      highlightSelected: false,
      menuItems: options.map<MenuItem>((a) {
        return MenuItem(
          child: a.enabled
              ? Text(a.label)
              : Text('${a.label} [Not supported yet]'),
          leadingIcon: a.icon,
          onPressed: () => a.enabled ? a.action.call(context) : {},
        );
      }).toList(),
    );
  }
}
