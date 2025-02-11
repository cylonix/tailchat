// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'dart:async';
import 'package:flutter/material.dart';
import '../../api/config.dart';
import '../../models/config/config_change_event.dart';
import 'user_avatar.dart';

class SelfUserAvatar extends StatefulWidget {
  const SelfUserAvatar({super.key});

  @override
  State<SelfUserAvatar> createState() => _SelfUserAvatarState();
}

class _SelfUserAvatarState extends State<SelfUserAvatar> {
  StreamSubscription<SelfUserChangeEvent>? _configChangeSub;
  String? _displayName = Pst.selfUser?.name;
  String? _userID = Pst.selfUser?.id;

  @override
  void initState() {
    super.initState();
    _registerToSelfUserChangeEvent();
  }

  @override
  void dispose() {
    _configChangeSub?.cancel();
    super.dispose();
  }

  void _registerToSelfUserChangeEvent() {
    final eventBus = Pst.eventBus;
    _configChangeSub =
        eventBus.on<SelfUserChangeEvent>().listen((onData) async {
      final displayName = Pst.selfUser?.name;
      final userID = Pst.selfUser?.id;
      if (_displayName != displayName || _userID != userID) {
        if (mounted) {
          setState(() {
            _displayName = displayName;
            _userID = userID;
          });
        }
      }
    });
  }

  @override
  Widget build(BuildContext cotext) {
    final name = Pst.selfUser?.name ?? "Please set up profile";
    return Column(
      children: [
        UserAvatar(
          size: 64,
          username: _displayName,
          userID: _userID,
          enableUpdate: false,
        ),
        const SizedBox(height: 8),
        Text(name),
      ],
    );
  }
}
