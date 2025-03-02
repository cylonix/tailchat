// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../api/api.dart' as api;
import '../../api/config.dart';
import '../../api/user_avatar.dart';
import '../../gen/l10n/app_localizations.dart';
import '../../models/api/user_avatar_change_event.dart';
import '../../utils/utils.dart';
import '../snackbar_widget.dart';

class UserAvatar extends StatefulWidget {
  final bool enableUpdate;
  final String? firstName;
  final String? lastName;
  final String? username;
  final String? userID;
  final Image? image;
  final Widget? child;
  final Color? color;
  final double size;
  const UserAvatar({
    super.key,
    this.size = 100.0,
    this.firstName,
    this.lastName,
    this.username,
    this.userID,
    this.image,
    this.child,
    this.color,
    this.enableUpdate = true,
  });

  @override
  State<UserAvatar> createState() => _UserAvatarState();
}

class _UserAvatarState extends State<UserAvatar> {
  StreamSubscription<UserAvatarChangeEvent>? _avatarChangeSub;
  Uint8List? _avatar;

  @override
  void initState() {
    super.initState();
    if (widget.image == null && widget.username != null) {
      _getUserAvatar(false);
    }
    _avatarChangeSub =
        api.apiEventBus.on<UserAvatarChangeEvent>().listen((event) {
      if (mounted && widget.userID == event.userID) {
        setState(() {
          _avatar = event.avatar;
        });
      }
    });
  }

  @override
  void dispose() {
    _avatarChangeSub?.cancel();
    super.dispose();
  }

  void _getUserAvatar(bool forceUpdate) async {
    final avatar = await getUserAvatar(
      widget.userID,
      forceUpdate: forceUpdate,
    );
    if (avatar != null && avatar.isNotEmpty) {
      _avatar = avatar;
      if (mounted) {
        setState(() {});
      }
    }
  }

  Image _getAvatarImage(Uint8List avatar) {
    return Image.memory(
      avatar,
      height: widget.size - 4,
      width: widget.size - 4,
      fit: BoxFit.cover,
      errorBuilder: (context, object, stackTrace) {
        return _getInitialAvatar();
      },
    );
  }

  Widget _getGradientAvatar(Widget child) {
    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        widget.color ?? const Color(0xff12c2e9),
        const Color.fromARGB(255, 57, 55, 65),
      ],
    );
    return Container(
      height: widget.size,
      width: widget.size,
      decoration: BoxDecoration(gradient: gradient, shape: BoxShape.circle),
      child: Center(child: child),
    );
  }

  Widget _getImageAvatar(Image image) {
    return _getGradientAvatar(
      ClipOval(
        child: FittedBox(clipBehavior: Clip.hardEdge, child: image),
      ),
    );
  }

  Widget _getChildAvatar(Widget child) {
    return _getGradientAvatar(child);
  }

  Widget _getDefaultAvatar() {
    return Icon(
      Icons.account_circle_sharp,
      color: Colors.white,
      size: widget.size,
    );
  }

  Widget _getInitialAvatar() {
    var firstName = widget.firstName;
    if (firstName == null || firstName.isEmpty) {
      var username = widget.username;
      if (username == null || username.isEmpty) {
        username = Pst.selfUser?.name ?? "";
      }
      firstName = username;
    }
    if (firstName.isEmpty) {
      return _getDefaultAvatar();
    }

    var initial = firstName.substring(0, 1).toUpperCase();
    final lastName = widget.lastName;
    if (lastName != null && lastName.isNotEmpty) {
      initial = "$initial${lastName.substring(0, 1).toUpperCase()}";
    } else if (firstName.length > 1) {
      initial = "$initial${firstName.substring(1, 2)}";
    }

    final style = TextStyle(color: Colors.white, fontSize: widget.size / 2.5);
    return _getGradientAvatar(Text(initial, style: style));
  }

  Widget _getAvatar() {
    final child = widget.child;
    if (child != null) {
      return _getChildAvatar(child);
    }
    var image = widget.image;
    if (image == null) {
      final avatar = _avatar;
      if (avatar != null) {
        image = _getAvatarImage(avatar);
      }
    }
    if (image != null) {
      return _getImageAvatar(image);
    }
    return _getInitialAvatar();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enableUpdate || widget.userID == null) {
      return _getAvatar();
    }
    final tr = AppLocalizations.of(context);
    return GestureDetector(
      onTap: _updateUserAvatar,
      child: Tooltip(message: tr.updateProfilePictureText, child: _getAvatar()),
    );
  }

  void _updateUserAvatar() async {
    final userID = widget.userID;
    if (userID == null) {
      return;
    }
    final status = await changeUserAvatar(userID);
    if (status != null && mounted) {
      final tr = AppLocalizations.of(context);
      if (status.success) {
        Toast.s(tr.successText).show(context);
      } else {
        await showAlertDialog(
          context,
          tr.prompt,
          status.error(context) ?? "",
        );
      }
    }
  }
}
