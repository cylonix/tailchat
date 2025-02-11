// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'package:flutter/material.dart';
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
    this.padding = const EdgeInsets.all(16.0),
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: padding,
        child: Column(
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
          ],
        ),
      ),
    );
  }
}
