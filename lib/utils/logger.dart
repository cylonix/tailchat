// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'global.dart';

class Logger {
  final String tag;
  Logger({required this.tag});
  void d(String log) {
    Global.wrappedLogger.d("tailchat: $tag: $log");
  }

  void w(String log) {
    Global.wrappedLogger.w("tailchat: $tag: $log");
  }

  void i(String log) {
    Global.wrappedLogger.i("tailchat: $tag: $log");
  }

  void e(String log) {
    Global.wrappedLogger.e("tailchat: $tag: $log");
  }
}
