// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'package:flutter/material.dart';
import 'package:tailchat/widgets/alert_dialog_widget.dart' as ad;
import '../../gen/l10n/app_localizations.dart';
import '../common_widgets.dart';
import '../main_app_bar.dart';
import '../tv/icon_button.dart';

/// ChatAppBar implements the chat page app bar.
class ChatAppBar extends MainAppBar {
  ChatAppBar({
    super.key,
    required String title,
    String? subtitle,
    bool canReceive = false,
    bool canSend = false,
    bool canSendChecking = false,
    bool showTrailingActions = true,
    int? messageExpireInMs,
    super.leading,
    required void Function() onTryToConnect,
    void Function(bool deleteForAllPeers)? onDeleteAllPressed,
    void Function()? onGroupChatManagementPressed,
    void Function(Duration? duration)? onSettingMessageExpirationTime,
  }) : super(
          titleWidget: ListTile(
            dense: true,
            title: Text(title),
            subtitle: (subtitle != null)
                ? Text(subtitle, textScaler: TextScaler.linear(0.8))
                : null,
          ),
          trailing: [
            Icon(
              Icons.arrow_downward,
              color: canReceive ? Colors.green : Colors.grey,
            ),
            const SizedBox(width: 4),
            IconButtonWidget(
              icon: canSendChecking
                  ? loadingWidget()
                  : Icon(
                      Icons.arrow_upward,
                      color: canSend ? Colors.green : Colors.grey,
                    ),
              onPressed: onTryToConnect,
              tooltip: canSendChecking
                  ? "Connecting to peer"
                  : "Press to try to connect to send",
            ),
            const SizedBox(width: 16),
            if (messageExpireInMs != null && showTrailingActions)
              ChatAppBarPopupMenuButton(
                icon: const Icon(Icons.timelapse_outlined),
                messageExpireInMs: messageExpireInMs,
                onSettingMessageExpirationTime: onSettingMessageExpirationTime,
              ),
            if (messageExpireInMs != null && showTrailingActions)
              const SizedBox(width: 16),
            if (showTrailingActions)
              ChatAppBarPopupMenuButton(
                onDeleteAllPressed: onDeleteAllPressed,
                onGroupChatManagementPressed: onGroupChatManagementPressed,
                onSettingMessageExpirationTime: messageExpireInMs == null
                    ? onSettingMessageExpirationTime
                    : null,
              ),
            if (showTrailingActions) const SizedBox(width: 16),
          ],
        );
}

class ChatAppBarPopupMenuButton extends StatefulWidget {
  final int? messageExpireInMs;
  final Widget? icon;
  final void Function(bool deleteForAllPeers)? onDeleteAllPressed;
  final void Function()? onGroupChatManagementPressed;
  final void Function(Duration? duration)? onSettingMessageExpirationTime;

  const ChatAppBarPopupMenuButton({
    super.key,
    this.icon,
    this.messageExpireInMs,
    this.onDeleteAllPressed,
    this.onGroupChatManagementPressed,
    this.onSettingMessageExpirationTime,
  });
  @override
  ChatAppBarPopupMenuButtonState createState() =>
      ChatAppBarPopupMenuButtonState();
}

class ChatAppBarPopupMenuButtonState extends State<ChatAppBarPopupMenuButton> {
  bool _deleteFromAllPeers = false;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      shape: commonShapeBorder(),
      offset: const Offset(0, 50),
      child: widget.icon ?? const Icon(Icons.more_vert_rounded),
      onSelected: (value) async {
        switch (value) {
          case 'group-chat-management':
            widget.onGroupChatManagementPressed?.call();
            return;
          case 'delete-all-messages':
            final tr = AppLocalizations.of(context);
            await ad.AlertDialogWidget(
              title: tr.confirmText,
              contents: [
                ad.Content(
                  content: tr.confirmDeleteAllChatMessagesText,
                )
              ],
              actions: [
                ad.Action(
                  title: tr.cancelButton,
                  onPressed: () => Navigator.of(context).pop(false),
                ),
                ad.Action(
                  title: tr.ok,
                  onPressed: () {
                    Navigator.of(context).pop(true);
                    widget.onDeleteAllPressed?.call(_deleteFromAllPeers);
                  },
                ),
              ],
              child: DeleteFromAllSwitchListTile(
                onChanged: (value) => _deleteFromAllPeers = value,
              ),
            ).show(context);
            return;
          default:
            return;
        }
      },
      itemBuilder: (context) {
        final tr = AppLocalizations.of(context);
        return [
          if (widget.onGroupChatManagementPressed != null)
            PopupMenuItem<String>(
              value: "group-chat-management",
              child: ListTile(
                leading: const Icon(Icons.edit_rounded),
                title: Text(tr.editText),
              ),
            ),
          if (widget.onDeleteAllPressed != null)
            PopupMenuItem<String>(
              value: "delete-all-messages",
              child: ListTile(
                leading: const Icon(
                  Icons.delete_forever_outlined,
                ),
                title: Text(tr.deleteAllChatMessagesText),
              ),
            ),
          if (widget.messageExpireInMs != null)
            PopupMenuItem<String>(
              value: "change-expiration-time",
              child: Column(children: _getDurationEntries(context)),
            ),
          if (widget.messageExpireInMs == null &&
              widget.onSettingMessageExpirationTime != null)
            PopupMenuItem<String>(
              value: "set-expiration-time",
              child: ExpansionTile(
                leading: const Icon(Icons.timelapse_outlined),
                title: Text(tr.setMessageExpirationTimeText),
                children: _getDurationEntries(context),
              ),
            ),
        ];
      },
    );
  }

  List<Widget> _getDurationEntries(BuildContext context) {
    final tr = AppLocalizations.of(context);
    const durations = [
      Duration(seconds: 15),
      Duration(minutes: 1),
      Duration(hours: 1),
      Duration(days: 1),
      null,
    ];
    final durationsInMs = durations.map((e) => e?.inMilliseconds).toList();
    final durationsText = [
      tr.fifteenSecondsText,
      tr.oneMinuteText,
      tr.oneHourText,
      tr.oneDayText,
      tr.noExpirationText,
    ];
    final entries = <Widget>[];
    final selected =
        durationsInMs.indexWhere((e) => e == widget.messageExpireInMs);
    for (int i = 0; i < durations.length; i++) {
      entries.add(ListTile(
        leading: i == selected ? const Icon(Icons.check) : const SizedBox(),
        selected: i == selected,
        title: Text(durationsText[i]),
        onTap: () {
          Navigator.pop(context);
          widget.onSettingMessageExpirationTime?.call(
            durations[i],
          );
        },
      ));
    }
    return entries;
  }
}

class DeleteFromAllSwitchListTile extends StatefulWidget {
  final void Function(bool)? onChanged;
  const DeleteFromAllSwitchListTile({
    super.key,
    this.onChanged,
  });
  @override
  State<DeleteFromAllSwitchListTile> createState() =>
      _DeleteFromAllSwitchListTileState();
}

class _DeleteFromAllSwitchListTileState
    extends State<DeleteFromAllSwitchListTile> {
  bool _deleteFromAllPeers = false;
  @override
  Widget build(BuildContext context) {
    final tr = AppLocalizations.of(context);
    return SwitchListTile.adaptive(
      contentPadding: const EdgeInsets.all(0),
      value: _deleteFromAllPeers,
      onChanged: (value) {
        widget.onChanged?.call(value);
        setState(() {
          _deleteFromAllPeers = value;
        });
      },
      title: Text(
        tr.deleteFromAllPeersText,
        textAlign: TextAlign.end,
      ),
    );
  }
}
