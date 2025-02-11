// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'package:flutter/material.dart';
import 'contacts/user_profile.dart';
import '../utils/logger.dart';

class NewVideoCallNotifier extends ChangeNotifier {
  UserProfile? peer;
  void add(UserProfile newPeer) {
    Logger(tag: "NewVideoCallNotifier").d("new call to ${newPeer.name}");
    peer = newPeer;
    notifyListeners();
  }
}
