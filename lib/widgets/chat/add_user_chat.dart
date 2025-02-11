// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'package:flutter/material.dart';
import '../../api/config.dart';
import '../../gen/l10n/app_localizations.dart';
import '../../models/chat/chat_id.dart';
import '../../models/chat/chat_session.dart';
import '../../models/session.dart';
import '../../models/contacts/device.dart';
import '../../models/contacts/user_profile.dart';
import '../main_app_bar.dart';
import '../snackbar_widget.dart';
import '../user/select_users.dart';
import '../tv/left_side.dart';
import '../tv/return_button.dart';

/// AddUserChat only select one user to the chat. Please use AddGroupChat if
/// to select multiple users.
class AddUserChat extends StatelessWidget {
  final void Function(
    UserProfile, {
    Device? device,
  })? onAdded;
  final bool chooseOnlyOneDevice;
  final String? title;
  final bool Function(Device)? deviceFilter;
  final bool Function(UserProfile)? userFilter;
  final bool enableScroll;
  final bool popOnSelected;
  const AddUserChat({
    super.key,
    this.onAdded,
    this.chooseOnlyOneDevice = false,
    this.title,
    this.deviceFilter,
    this.userFilter,
    this.enableScroll = true,
    this.popOnSelected = true,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _appBar(context),
      body: _body(context),
    );
  }

  String _title(BuildContext context) {
    final tr = AppLocalizations.of(context);
    return title ??
        (chooseOnlyOneDevice
            ? tr.chatWithAUserOnDeviceText
            : tr.chatWithAUserText);
  }

  String _subTitle(BuildContext context) {
    final tr = AppLocalizations.of(context);
    return chooseOnlyOneDevice
        ? tr.pleaseSelectOneDeviceText
        : tr.pleaseSelectOneUserText;
  }

  PreferredSizeWidget? _appBar(BuildContext context) {
    if ((Pst.enableTV ?? false) || !enableScroll) {
      return null;
    }
    return MainAppBar(title: _title(context));
  }

  Widget _body(BuildContext context) {
    if (Pst.enableTV ?? false) {
      final style = Theme.of(context).textTheme.titleLarge;
      return Row(
        children: [
          LeftSide(
            width: enableScroll ? null : 120,
            mainAxisAlignment: enableScroll
                ? MainAxisAlignment.spaceAround
                : MainAxisAlignment.start,
            children: [
              const ReturnButton(),
              Icon(Icons.supervisor_account, size: enableScroll ? 96 : 64),
              const SizedBox(height: 32),
              Text(
                _title(context),
                style: style,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Text(_subTitle(context), textAlign: TextAlign.center),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(child: _selectUsers(context)),
        ],
      );
    }
    if (!enableScroll) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Text(_title(context)),
          Expanded(child: _selectUsers(context)),
        ],
      );
    }
    return Container(
      alignment: Alignment.center,
      child: Container(
        padding: const EdgeInsets.all(16),
        constraints: const BoxConstraints(maxWidth: 1000),
        child: _selectUsers(context),
      ),
    );
  }

  Widget _selectUsers(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SelectUsers(
        chooseOnlyOneUser: true,
        chooseOnlyOneDevice: chooseOnlyOneDevice,
        onSelected: (selectedUsers, {Device? device}) =>
            _onSelected(context, selectedUsers, device: device),
        userFilter: userFilter,
        enableScroll: enableScroll,
      ),
    );
  }

  void _onSelected(
    BuildContext context,
    List<UserProfile> selectedUsers, {
    Device? device,
  }) {
    final inputInvalid = _validateInput(context, selectedUsers, device);
    if (inputInvalid != null) {
      SnackbarWidget.e(inputInvalid).show(context);
      return;
    }
    if (popOnSelected) {
      Navigator.pop(context);
    }
    onAdded?.call(
      selectedUsers[0],
      device: device,
    );
  }

  String? _validateInput(
    BuildContext context,
    List<UserProfile> selectedUsers,
    Device? device,
  ) {
    final tr = AppLocalizations.of(context);
    if (selectedUsers.length != 1) {
      return tr.selectOneUserOnlyForChatText;
    }
    if (device == null && chooseOnlyOneDevice) {
      return tr.selectOneDeviceOnlyForChatText;
    }
    return null;
  }
}

void newUserChat(
  BuildContext context,
  bool chooseOnlyOneDevice,
  void Function(ChatSession session) onNewChat,
) {
  void handleNewUserChat(
    BuildContext context,
    UserProfile peerUser, {
    Device? device,
  }) {
    final selfUser = Pst.selfUser;
    final selfDevice = Pst.selfDevice;
    final tr = AppLocalizations.of(context);
    if (selfUser == null || selfDevice == null) {
      SnackbarWidget.e(tr.selfUserNotFoundError).show(context);
      return;
    }

    final chatID = ChatID.fromTwoUserIDs(
      user1: selfUser.id,
      user2: peerUser.id,
      machine1: (device != null) ? selfDevice.id : null,
      machine2: device?.id,
    ).id;

    final newSession = ChatSession(
      sessionID: chatID,
      selfUserID: selfUser.id,
      peerUserID: peerUser.id,
      peerDeviceID: device?.id,
      peerDeviceName: device?.hostname,
      peerIP: device?.address,
      peerName: peerUser.name,
      status: SessionStatus.read, // will show this session right now
      createdAt: DateTime.now(),
    );
    onNewChat(newSession);
  }

  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (BuildContext context) => AddUserChat(
        onAdded: (peerUser, {Device? device}) {
          handleNewUserChat(context, peerUser, device: device);
        },
        chooseOnlyOneDevice: chooseOnlyOneDevice,
      ),
    ),
  );
}
