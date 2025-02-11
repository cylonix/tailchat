// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'package:flutter/material.dart';
import 'session.dart';
import '../utils/global.dart';

class NewSessionNotifier extends ChangeNotifier {
  Session? session;
  void add(Session newSession) {
    Global.logger.d("New session notifier: ${newSession.sessionID}");
    session = newSession;
    notifyListeners();
  }
}
