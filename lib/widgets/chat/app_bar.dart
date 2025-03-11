// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:pull_down_button/pull_down_button.dart';
import 'package:tailchat/models/alert.dart';
import 'package:tailchat/widgets/alert_dialog_widget.dart';
import '../../gen/l10n/app_localizations.dart';
import '../../utils/utils.dart';
import '../common_widgets.dart';
import '../main_app_bar.dart';
import '../tv/icon_button.dart';

/// ChatAppBar implements the chat page app bar.
class ChatAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  final bool canReceive;
  final bool canSend;
  final bool canSendChecking;
  final bool showTrailingActions;
  final int? messageExpireInMs;
  final Widget? leading;
  final void Function() onTryToConnect;
  final Function(bool deleteForAllPeers)? onDeleteAllPressed;
  final Function()? onGroupChatManagementPressed;
  final Function(Duration? duration)? onSettingMessageExpirationTime;
  const ChatAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.canReceive = false,
    this.canSend = false,
    this.canSendChecking = false,
    this.showTrailingActions = true,
    this.messageExpireInMs,
    this.leading,
    required this.onTryToConnect,
    this.onDeleteAllPressed,
    this.onGroupChatManagementPressed,
    this.onSettingMessageExpirationTime,
  });

  @override
  Size get preferredSize {
    return const Size.fromHeight(46);
  }

  @override
  Widget build(BuildContext context) {
    final titleWidget = isLargeScreen(context)
        ? Text(
            '$title${subtitle != null ? "@$subtitle" : ""}',
          )
        : Text(title);
    final subtitleWidget = isLargeScreen(context)
        ? null
        : (subtitle != null)
            ? Text(
                subtitle!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              )
            : null;
    return MainAppBar(
      titleSpacing: 0.0,
      titleWidget: isApple()
          ? CupertinoListTile(
              title: titleWidget,
              subtitle: subtitleWidget,
            )
          : ListTile(
              dense: true,
              title: titleWidget,
              subtitle: subtitleWidget,
            ),
      trailing: [
        Icon(
          isApple() ? CupertinoIcons.arrow_down : Icons.arrow_downward,
          color: canReceive ? Colors.green : Colors.grey,
          size: 20,
        ),
        const SizedBox(width: 4),
        IconButtonWidget(
          padding: const EdgeInsets.all(0),
          icon: canSendChecking
              ? loadingWidget(
                  constraints: BoxConstraints.tight(const Size(20, 20)),
                )
              : Icon(
                  isApple() ? CupertinoIcons.arrow_up : Icons.arrow_upward,
                  color: canSend ? Colors.green : Colors.grey,
                  size: 20,
                ),
          onPressed: onTryToConnect,
          tooltip: canSendChecking
              ? "Connecting to peer"
              : "Press to try to connect to send",
        ),
        const SizedBox(width: 8),
        if (messageExpireInMs != null && showTrailingActions) ...[
          ChatAppBarPopupMenuButton(
            icon: Icon(
              isApple() ? CupertinoIcons.timelapse : Icons.timelapse_outlined,
            ),
            messageExpireInMs: messageExpireInMs,
            onSettingMessageExpirationTime: onSettingMessageExpirationTime,
          ),
          const SizedBox(width: 8),
        ],
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

  void _showDeleteAllDialog() async {
    final tr = AppLocalizations.of(context);
    await AlertDialogWidget(
      title: tr.confirmText,
      contents: [
        Content(content: "Please confirm to delete all messages."),
        Content(
          content: "Messages will be forever deleted.",
          style: TextStyle(color: Colors.red),
        ),
      ],
      actions: [
        AlertAction(
          tr.cancelButton,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        AlertAction(
          tr.ok,
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
  }

  @override
  Widget build(BuildContext context) {
    if (isApple()) {
      final tr = AppLocalizations.of(context);
      final durationItems = _getDurationPullDownMenuItems(context);
      return PullDownButton(
        itemBuilder: (context) => [
          if (widget.onGroupChatManagementPressed != null)
            PullDownMenuItem(
              onTap: widget.onGroupChatManagementPressed,
              title: tr.editText,
              icon: CupertinoIcons.pencil,
            ),
          if (widget.onDeleteAllPressed != null)
            PullDownMenuItem(
              onTap: _showDeleteAllDialog,
              title: tr.deleteAllChatMessagesText,
              icon: CupertinoIcons.delete,
              isDestructive: true,
            ),
          if (widget.messageExpireInMs != null ||
              widget.onSettingMessageExpirationTime != null) ...[
            PullDownMenuDivider.large(),
            PullDownMenuTitle(
              title: Text(
                "${(widget.messageExpireInMs == null ? "Change" : "Set")}"
                " message expiration time:",
              ),
            ),
            if (widget.messageExpireInMs != null) ...durationItems,
            if (widget.messageExpireInMs == null) ...[
              PullDownMenuActionsRow.medium(items: durationItems.sublist(0, 3)),
              PullDownMenuActionsRow.medium(items: durationItems.sublist(3, 6)),
            ],
          ],
        ],
        buttonBuilder: (context, showMenu) => CupertinoButton(
          onPressed: showMenu,
          padding: EdgeInsets.zero,
          child: widget.icon ??
              const Icon(
                CupertinoIcons.ellipsis_vertical,
              ),
        ),
      );
    }
    return PopupMenuButton<String>(
      shape: commonShapeBorder(),
      offset: const Offset(0, 50),
      child: widget.icon ?? const Icon(Icons.more_vert_rounded),
      onSelected: (value) {
        switch (value) {
          case 'group-chat-management':
            widget.onGroupChatManagementPressed?.call();
            return;
          case 'delete-all-messages':
            _showDeleteAllDialog();
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

  List<PullDownMenuItem> _getDurationPullDownMenuItems(BuildContext context) {
    const durations = [
      Duration(seconds: 15),
      Duration(minutes: 1),
      Duration(hours: 1),
      Duration(days: 1),
      Duration(days: 7),
      null,
    ];
    final durationsInMs = durations.map((e) => e?.inMilliseconds).toList();
    final durationsText = [
      '15 sec',
      '1 min',
      '1 hour',
      '1 day',
      "1 week",
      'Never',
    ];
    final durationsIcon = [
      CupertinoIcons.time, // 15 seconds
      CupertinoIcons.clock, // 1 minute
      CupertinoIcons.clock_fill, // 1 hour
      CupertinoIcons.calendar, // 1 day
      CupertinoIcons.calendar_today, // 1 week
      CupertinoIcons.infinite, // No expiration
    ];

    return List.generate(durations.length, (i) {
      final isSelected = durationsInMs[i] == widget.messageExpireInMs;
      return PullDownMenuItem.selectable(
        onTap: () {
          widget.onSettingMessageExpirationTime?.call(durations[i]);
        },
        title: durationsText[i],
        selected: isSelected,
        icon: durationsIcon[i],
      );
    });
  }

  List<Widget> _getDurationEntries(BuildContext context) {
    const durations = [
      Duration(seconds: 15),
      Duration(minutes: 1),
      Duration(hours: 1),
      Duration(days: 1),
      Duration(days: 7),
      null,
    ];
    final durationsInMs = durations.map((e) => e?.inMilliseconds).toList();
    final durationsText = [
      '15 seconds',
      '1 minute',
      '1 hour',
      '1 day',
      '1 week',
      'Never',
    ];
    final durationsIcon = [
      Icons.timer_outlined, // 15 seconds
      Icons.access_time, // 1 minute
      Icons.access_time_filled, // 1 hour
      Icons.calendar_today, // 1 day
      Icons.date_range, // 1 week
      Icons.all_inclusive, // No expiration
    ];

    final entries = <Widget>[];
    final selected =
        durationsInMs.indexWhere((e) => e == widget.messageExpireInMs);

    for (int i = 0; i < durations.length; i++) {
      entries.add(ListTile(
        leading: Icon(durationsIcon[i]),
        selected: i == selected,
        trailing: i == selected ? const Icon(Icons.check) : null,
        title: Text(durationsText[i]),
        onTap: () {
          Navigator.pop(context);
          widget.onSettingMessageExpirationTime?.call(durations[i]);
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
