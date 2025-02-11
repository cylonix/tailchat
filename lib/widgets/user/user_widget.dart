// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tailchat/models/config/config_change_event.dart';
import '../../api/config.dart';
import '../../api/contacts.dart';
import 'user_avatar.dart';
import 'user_card.dart';

class UserWidget extends StatefulWidget {
  final bool showCloseButton;
  final bool showDetailsPage;
  final bool enableDetails;
  final bool narrow;
  final double? avatarSize;
  final String? userID;
  final void Function()? onClosePressed;
  const UserWidget({
    super.key,
    this.avatarSize,
    this.showCloseButton = true,
    this.showDetailsPage = true,
    this.enableDetails = true,
    this.narrow = false,
    this.onClosePressed,
    this.userID,
  });

  @override
  State<UserWidget> createState() => _UserWidgetState();
}

class _UserWidgetState extends State<UserWidget> {
  StreamSubscription<SelfUserChangeEvent>? _configChangeSub;
  String? _userID;
  String? _userDisplayName;
  late final FocusNode _focus;

  @override
  void initState() {
    super.initState();
    if (widget.userID == null) {
      _userID = Pst.selfUser?.id;
      _userDisplayName = Pst.selfUser?.name;
      _registerToConfigChangeEvent();
    } else {
      _userID = widget.userID;
      _setName(widget.userID!);
    }
    _focus = FocusNode();
    _focus.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    _configChangeSub?.cancel();
    super.dispose();
  }

  void _setName(String userID) async {
    final user = await getContact(userID);
    if (mounted) {
      setState(() {
        _userDisplayName = user?.name;
      });
    }
  }

  void _updateSelfUser() {
    if (mounted) {
      setState(() {
        if (widget.userID == null) {
          _userID = Pst.selfUser?.id;
          _userDisplayName = Pst.selfUser?.name;
        }
      });
    }
  }

  void _registerToConfigChangeEvent() {
    final eventBus = Pst.eventBus;
    _configChangeSub = eventBus.on<SelfUserChangeEvent>().listen((onData) {
      _updateSelfUser();
    });
  }

  Widget get _userAvatar {
    if (widget.userID != null) {
      return UserAvatar(
        enableUpdate: widget.enableDetails,
        userID: _userID,
        username: _userDisplayName,
        size: widget.avatarSize ?? 100,
      );
    }
    return UserAvatar(
      enableUpdate: false,
      size: widget.avatarSize ?? 100,
      child: Icon(Icons.account_circle_rounded, size: widget.avatarSize ?? 100),
    );
  }

  TextStyle? get _nameStyle {
    return Theme.of(context).textTheme.titleLarge;
  }

  Widget get _usernameWidget {
    String name = _userDisplayName ?? "";
    if (widget.narrow && name.length >= 20) {
      name = "${name.substring(0, 20)}...";
    }
    return Text(name, style: _nameStyle, textAlign: TextAlign.center);
  }

  @override
  Widget build(BuildContext context) {
    return UserCard(
      noGradient: true,
      avatarChild: widget.narrow
          ? Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [_userAvatar, _usernameWidget],
            )
          : _userAvatar,
      noMargin: true,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      shape: const ContinuousRectangleBorder(),
      trailing: widget.showCloseButton
          ? IconButton(
              onPressed: () {
                (widget.onClosePressed != null)
                    ? widget.onClosePressed?.call()
                    : Navigator.pop(context);
              },
              icon: const Icon(Icons.arrow_back, color: Colors.black),
            )
          : widget.enableDetails
              ? const Icon(Icons.arrow_forward_ios_rounded)
              : null,
      child: widget.narrow
          ? null
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [_usernameWidget],
            ),
    );
  }
}
