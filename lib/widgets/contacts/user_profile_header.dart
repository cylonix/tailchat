// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'package:flutter/material.dart';
import '../../api/config.dart';
import '../../models/contacts/user_profile.dart';
import 'user_avatar.dart';

class UserProfileHeader extends StatelessWidget {
  final UserProfile? user;
  final String? heroTag;
  final double avatarRadius;
  final double? nameSize;
  final TextStyle? nameStyle;
  final EdgeInsetsGeometry padding;

  const UserProfileHeader({
    super.key,
    this.user,
    this.heroTag,
    this.avatarRadius = 48,
    this.nameSize,
    this.nameStyle,
    this.padding = const EdgeInsets.all(8.0),
  });

  @override
  Widget build(BuildContext context) {
    final isSelf = (user?.id == Pst.selfUser?.id && Pst.selfUser?.id != null);
    final hostname = isSelf ? Pst.selfDevice?.hostname : null;
    final address = isSelf ? Pst.selfDevice?.address : null;
    return Center(
      child: Padding(
        padding: padding,
        child: Column(
          spacing: 4,
          children: [
            UserAvatar(
              user: user,
              radius: avatarRadius,
              heroTag: heroTag,
            ),
            const SizedBox(height: 16),
            Text(
              user?.name ?? "Not Set",
              style: nameStyle ??
                  TextStyle(
                    fontSize: nameSize ?? 24,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            if (hostname != null) Text(hostname),
            if (address != null && hostname != address) Text(address),
          ],
        ),
      ),
    );
  }
}
