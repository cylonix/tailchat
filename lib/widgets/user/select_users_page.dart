// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'package:flutter/material.dart';
import '../../gen/l10n/app_localizations.dart';
import '../../models/contacts/device.dart';
import '../../models/contacts/user_profile.dart';
import '../main_app_bar.dart';
import 'select_users.dart';

class SelectUsersPage extends StatefulWidget {
  final void Function(List<UserProfile>, {Device? device}) onSelected;
  final List<UserProfile>? inputUsers;
  final String? title;
  final String? selectButtonText;
  final List<String>? exclude;
  const SelectUsersPage({
    super.key,
    this.title,
    this.exclude,
    this.inputUsers,
    this.selectButtonText,
    required this.onSelected,
  });
  @override
  State<SelectUsersPage> createState() => _SelectUsersPageState();
}

class _SelectUsersPageState extends State<SelectUsersPage> {
  @override
  Widget build(BuildContext context) {
    final tr = AppLocalizations.of(context);
    return Scaffold(
      appBar: MainAppBar(
        title: widget.title ?? tr.selectUsersText,
      ),
      body: Container(
        alignment: Alignment.topCenter,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1000),
          padding: const EdgeInsets.all(16),
          alignment: Alignment.topCenter,
          child: SelectUsers(
            exclude: widget.exclude,
            selectButtonText: widget.selectButtonText,
            onSelected: (selectUsers, {Device? device}) {
              Navigator.pop(context);
              widget.onSelected(selectUsers, device: device);
            },
            inputUsers: widget.inputUsers,
          ),
        ),
      ),
    );
  }
}
