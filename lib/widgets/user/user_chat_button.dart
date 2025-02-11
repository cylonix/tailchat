// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../gen/l10n/app_localizations.dart';
import '../../models/chat/chat_id.dart';
import '../../models/chat/chat_session.dart';
import '../../models/new_session_notifier.dart';
import '../../models/contacts/device.dart';
import '../../models/session.dart';
import '../../models/contacts/user_profile.dart';
import '../main_bottom_bar.dart';
import '../snackbar_widget.dart';

class UserChatButton extends StatelessWidget {
  final UserProfile user;
  final UserProfile selfUser;
  final Device selfDevice;
  final List<Device>? onlinePeers;
  final bool showSideBySide;
  final Widget? child;
  const UserChatButton({
    super.key,
    required this.user,
    required this.selfUser,
    required this.selfDevice,
    this.onlinePeers,
    this.child,
    this.showSideBySide = false,
  });

  @override
  Widget build(BuildContext context) {
    return _buildUserChat(context);
  }

  void _pushNewChatPage({
    required BuildContext context,
    required ChatSession session,
  }) {
    Navigator.of(context).pushNamed(
      '/chat/${session.sessionID}',
      arguments: session.toJson(),
    );
  }

  void _chatWithAllDevicesOfUser({
    required BuildContext context,
    required UserProfile user,
    required UserProfile selfUser,
    required Device selfDevice,
    required List<Device> peers,
  }) {
    final tr = AppLocalizations.of(context);
    var chatPeers = <Device>[];
    for (var peer in peers) {
      if (peer.isAvailable) {
        chatPeers.add(peer);
      }
    }
    if (chatPeers.isEmpty) {
      Future.microtask(() {
        if (context.mounted) {
          SnackbarWidget.w(tr.noDeviceAvailableToChatMessageText).show(context);
        }
      });
      return;
    }
    final chatID = ChatID.fromTwoUserIDs(
      user1: selfUser.id,
      user2: user.id,
    ).id;
    final notifier = context.read<NewSessionNotifier>();
    final session = ChatSession(
      sessionID: chatID,
      selfUserID: selfUser.id,
      peerUserID: user.id,
      peerName: user.name,
      status: SessionStatus.unread,
      createdAt: DateTime.now(),
    );
    notifier.add(session);
    if (showSideBySide) {
      final notifier = context.read<BottomBarSelection>();
      notifier.select(MainBottomBar.pageIndexOf(MainBottomBarPage.sessions));
    } else {
      _pushNewChatPage(
        context: context,
        session: session,
      );
    }
  }

  Widget _buildUserChat(BuildContext context) {
    final tr = AppLocalizations.of(context);
    final titleLargeStyle = Theme.of(context).textTheme.titleLarge;
    final style = TextStyle(fontSize: titleLargeStyle?.fontSize);
    var chatAvailablePeers = <Device>[];
    for (var peer in onlinePeers ?? []) {
      if (peer.isAvailable) {
        chatAvailablePeers.add(peer);
      }
    }
    if (chatAvailablePeers.isEmpty) {
      return child ?? Container();
    }

    void onPressed() {
      _chatWithAllDevicesOfUser(
        context: context,
        user: user,
        selfUser: selfUser,
        selfDevice: selfDevice,
        peers: chatAvailablePeers,
      );
    }

    return Tooltip(
      message: tr.chatWithAllDevicesText,
      child: child != null
          ? InkWell(onTap: onPressed, child: child)
          : TextButton(
              onPressed: onPressed,
              child: Text("${tr.chatText} | ${user.name}", style: style),
            ),
    );
  }
}
