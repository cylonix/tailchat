// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'package:flutter/material.dart';
import 'chat_page.dart';
import '../../api/config.dart';
import '../../gen/l10n/app_localizations.dart';
import '../../models/chat/chat_id.dart';
import '../../models/chat/chat_session.dart';
import '../../models/contacts/user_profile.dart';
import '../../models/session.dart';
import '../../utils/global.dart';
import '../base_input/text_input.dart';
import '../main_app_bar.dart';
import '../snackbar_widget.dart';
import '../user/select_users.dart';

class AddGroupChat extends StatefulWidget {
  final void Function(String, List<UserProfile>) onAdded;
  final String? Function(String) validateGroupName;
  const AddGroupChat({
    super.key,
    required this.onAdded,
    required this.validateGroupName,
  });
  @override
  State<AddGroupChat> createState() => _AddGroupChatState();
}

class _AddGroupChatState extends State<AddGroupChat> {
  String? _groupName;

  @override
  Widget build(BuildContext context) {
    final tr = AppLocalizations.of(context);
    return Scaffold(
      appBar: MainAppBar(title: tr.addGroupChatText),
      body: Container(
        alignment: Alignment.topCenter,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1000),
          padding: const EdgeInsets.all(16),
          alignment: Alignment.topCenter,
          child: Column(
            children: [
              const SizedBox(height: 20),
              _buildGroupNameInput(context),
              const SizedBox(height: 10),
              Text(tr.selectUsersForGroupChatText),
              Expanded(
                child: SelectUsers(
                  onSelected: (selectedUsers, {device}) => {
                    _onSelectedUsers(selectedUsers),
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGroupNameInput(BuildContext context) {
    final tr = AppLocalizations.of(context);
    return BaseTextInput(
      label: tr.groupNameText,
      hint: tr.groupNameInputHintText,
      icon: Icons.supervised_user_circle_rounded,
      validator: _validateGroupName,
      onChanged: (value) => _groupName = value,
    );
  }

  String? _validateGroupName(String? value) {
    final tr = AppLocalizations.of(context);
    if (value == null || value.isEmpty) {
      return tr.groupNameEmptyError;
    }
    return widget.validateGroupName(value);
  }

  void _onSelectedUsers(List<UserProfile> selectedUsers) {
    Global.logger.d("Selected users are: $selectedUsers");
    final inputInvalid = _validateInput(selectedUsers);
    if (inputInvalid != null) {
      SnackbarWidget.e(inputInvalid).show(context);
      return;
    }
    Navigator.pop(context);
    widget.onAdded(_groupName!, selectedUsers);
  }

  String? _validateInput(List<UserProfile> selectedUsers) {
    final tr = AppLocalizations.of(context);
    final groupNameInvalid = _validateGroupName(_groupName);
    if (groupNameInvalid != null) {
      return groupNameInvalid;
    }
    final selfUser = Pst.selfUser;
    if (selfUser == null) {
      return tr.selfUserNotFoundError;
    }
    bool selectedSelf = false;
    for (var user in selectedUsers) {
      if (Pst.isSelfUser(user.id)) {
        selectedSelf = true;
        break;
      }
    }
    if (!selectedSelf) {
      selectedUsers.insert(0, selfUser);
    }
    if (selectedUsers.length < 2) {
      return tr.groupChatUserCountNotEnoughError;
    }
    return null;
  }
}

void newGroupChat(
  BuildContext context, {
  required void Function(ChatSession session) onNewChat,
  required String? Function(String) validateGroupName,
}) {
  void handleNewGroupChat(
    BuildContext context,
    String groupName,
    List<UserProfile> groupUsers,
  ) async {
    final selfUser = Pst.selfUser;
    if (selfUser == null) {
      return;
    }

    final sessionID = ChatID.fromGroupName(groupName).id;
    await ChatPage.addNewGroupChat(sessionID, groupName, selfUser, groupUsers);
    final newSession = ChatSession(
      sessionID: sessionID,
      selfUserID: selfUser.id,
      groupName: groupName,
      createdAt: DateTime.now(),
      status: SessionStatus.read, // will show this session right now
    );
    onNewChat(newSession);
  }

  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (BuildContext context) => AddGroupChat(
        onAdded: (String groupName, List<UserProfile> groupUsers) {
          handleNewGroupChat(context, groupName, groupUsers);
        },
        validateGroupName: validateGroupName,
      ),
    ),
  );
}
