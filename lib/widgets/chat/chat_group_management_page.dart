// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

// Please keep the imports in alphabetic order
import 'package:flutter/material.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;

import '../../api/config.dart';
import '../../gen/l10n/app_localizations.dart';
import '../../models/chat/chat_message.dart';
import '../../models/chat/chat_session.dart';
import '../../models/contacts/user_profile.dart';
import '../../utils/global.dart';
import '../../utils/utils.dart';
import '../main_app_bar.dart';
import '../user/select_users_page.dart';
import '../user/user_card.dart';
import 'user_status.dart';

class ChatGroupManagementPage extends StatefulWidget {
  final ChatSession session;
  final types.Room room;
  final void Function(ChatSession)? onSessionUpdate;
  final void Function(types.Room)? onRoomUpdate;
  const ChatGroupManagementPage({
    super.key,
    required this.session,
    required this.room,
    this.onSessionUpdate,
    this.onRoomUpdate,
  });

  @override
  State<ChatGroupManagementPage> createState() =>
      _ChatGroupManagementPageState();
}

class _ChatGroupManagementPageState extends State<ChatGroupManagementPage> {
  bool _isAdmin = false;
  @override
  void initState() {
    super.initState();
    try {
      final user = widget.room.users.firstWhere(
        (u) => u.id == Pst.selfUser?.id,
      );
      _isAdmin = user.role == types.Role.admin;
    } catch (e) {
      Global.logger.e("failed to get self user from the room users");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MainAppBar(
        title: widget.session.groupName ?? "",
      ),
      body: Container(
        alignment: Alignment.topCenter,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1000),
          margin: const EdgeInsets.only(left: 10, right: 10),
          alignment: Alignment.topCenter,
          child: ListView(
            shrinkWrap: true,
            controller: ScrollController(),
            children: [
              const SizedBox(height: 20),
              _notificationOnOff(context),
              const SizedBox(height: 10),
              _addMember(context),
              const SizedBox(height: 10),
              _groupUserList(context),
            ],
          ),
        ),
      ),
    );
  }

  void _updateNotifications(bool on) {
    widget.session.isNotificationOn = on;
    final update = widget.onSessionUpdate;
    if (update != null) update(widget.session);
    setState(() {});
  }

  void _flipNotifications() {
    _updateNotifications(!widget.session.isNotificationOn);
  }

  Widget _notificationOnOff(BuildContext context) {
    final tr = AppLocalizations.of(context);
    return ListTile(
      leading: const Icon(Icons.notifications),
      trailing: Switch.adaptive(
        value: widget.session.isNotificationOn,
        onChanged: _updateNotifications,
      ),
      title: Text(tr.notificationsText),
      onTap: _flipNotifications,
    );
  }

  void _updateRoomWithMoreUsers(List<UserProfile> selected) {
    for (var u in selected) {
      widget.room.users.add(ChatMessage.toAuthor(u));
    }
    widget.onRoomUpdate?.call(widget.room);
    setState(() {});
  }

  Widget _addMember(BuildContext context) {
    var exclude = <String>[];
    for (var u in widget.room.users) {
      exclude.add(u.id);
    }
    final tr = AppLocalizations.of(context);
    return ListTile(
      leading: const Icon(Icons.add),
      title: Text(tr.addUsersText),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => SelectUsersPage(
              exclude: exclude,
              selectButtonText: tr.confirmAddingToGroupChatText,
              onSelected: (selected, {device}) {
                _updateRoomWithMoreUsers(selected);
              },
            ),
          ),
        );
      },
    );
  }

  void _removeUser(types.User user) async {
    // Only allow remove of self if not admin.
    final tr = AppLocalizations.of(context);
    if (!_isAdmin && !Pst.isSelfUser(user.id)) {
      await showAlertDialog(
        context,
        tr.prompt,
        tr.onlyGroupChatAdminCanRemoveMemberText,
      );
      return;
    }

    widget.room.users.remove(user);
    widget.onRoomUpdate?.call(widget.room);
    setState(() {});
  }

  Widget _groupUserList(BuildContext context) {
    final tr = AppLocalizations.of(context);
    return ListView.builder(
      shrinkWrap: true,
      controller: ScrollController(),
      itemBuilder: (context, index) {
        final chatUser = widget.room.users[index];
        final userID = chatUser.id;
        final isMe = Pst.isSelfUser(userID);
        var username = widget.room.users[index].firstName ?? tr.unknownText;
        return UserCard(
          userID: userID,
          child: ListTile(
            title: Text(username),
            subtitle: UserStatus(userID: userID),
            trailing: _isAdmin || isMe
                ? TextButton(
                    onPressed: () => _removeUser(chatUser),
                    child: Text(tr.removeText),
                  )
                : null,
          ),
        );
      },
      itemCount: widget.room.users.length,
    );
  }
}
