// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'package:flutter/material.dart';
import 'session.dart';
import '../utils/global.dart';

class DeleteSessionNotifier extends ChangeNotifier {
  Session? session;
  void add(Session deleteSession) {
    Global.logger.d("Delete session ${deleteSession.sessionID}");
    session = deleteSession;
    notifyListeners();
  }
}
