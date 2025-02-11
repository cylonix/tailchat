// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'package:flutter/material.dart';
import '../../models/contacts/user_profile.dart';

class UserAvatar extends StatelessWidget {
  final UserProfile? user;
  final double radius;
  final String? heroTag;
  final VoidCallback? onTap;

  const UserAvatar({
    super.key,
    this.user,
    this.radius = 48,
    this.heroTag,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final avatar = CircleAvatar(
      radius: radius,
      backgroundImage:
          user?.profileUrl != null ? NetworkImage(user!.profileUrl!) : null,
      child: user?.profileUrl == null
          ? Text(
              user?.name.isNotEmpty == true ? user!.name[0].toUpperCase() : '?',
              style: TextStyle(fontSize: radius * 0.66),
            )
          : null,
    );
    final wrapped =
        heroTag != null ? Hero(tag: heroTag!, child: avatar) : avatar;

    return onTap != null
        ? GestureDetector(onTap: onTap, child: wrapped)
        : wrapped;
  }
}
