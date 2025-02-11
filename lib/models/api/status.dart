// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'package:flutter/material.dart';

import '../../gen/l10n/app_localizations.dart';
import 'error_code.dart';

enum LocalMsgKey {
  codeInvalid,
  failedToStopCylonixd,
  fileNotExists,
  notYetImplemented,
  selfUserNotFound,
  serverNotReachable,
  unauthenticated,
  userNotAvailable,
  userNotExist,
}

class Status {
  final bool success;
  final String msg;
  LocalMsgKey? localMsgKey; // localized message key
  String? placeHolder; // localized message with a placeholder.
  String? errorCode;

  Status(this.success, [this.msg = ""]);
  static final ok = Status(true);
  Status.fail({
    this.success = false,
    this.msg = "",
    this.localMsgKey,
    this.placeHolder,
    this.errorCode,
  });
  Status.local(
    this.success,
    this.localMsgKey, [
    this.msg = "",
    this.placeHolder = "",
  ]);
  Status.withErrorCode(this.errorCode, [this.success = false, this.msg = ""]);

  @override
  String toString() {
    return "success=$success msg=\"$msg\" lm=$localMsgKey";
  }

  String? _localize(BuildContext? context) {
    if (context == null) {
      return null;
    }
    final tr = AppLocalizations.of(context);
    switch (localMsgKey) {
      case LocalMsgKey.codeInvalid:
        return tr.codeInvalidText;
      case LocalMsgKey.fileNotExists:
        return tr.fileNotExistsText;
      case LocalMsgKey.notYetImplemented:
        return tr.notYetImplementedMessageText;
      case LocalMsgKey.selfUserNotFound:
        return tr.selfUserNotFoundError;
      case LocalMsgKey.serverNotReachable:
        return tr.serverNotReachableText(placeHolder ?? "");
      case LocalMsgKey.unauthenticated:
        return tr.unauthenticated;
      case LocalMsgKey.userNotAvailable:
        return tr.userNotAvailableText(placeHolder ?? tr.userText);
      case LocalMsgKey.userNotExist:
        return tr.userNotExist;
      default:
        return null;
    }
  }

  String? _errorMessage(BuildContext? context) {
    return ErrorCode(context, errorCode).message;
  }

  String? error(BuildContext? context) {
    final err = _errorMessage(context) ?? _localize(context);
    if (err == null && msg.isEmpty) {
      return null;
    }
    if (err == null) {
      return msg;
    }
    return msg.isEmpty ? err : '$err: $msg';
  }
}
