// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'dart:typed_data';

class UserAvatarChangeEvent {
  final String userID;
  final Uint8List avatar;
  UserAvatarChangeEvent({required this.userID, required this.avatar});
}
