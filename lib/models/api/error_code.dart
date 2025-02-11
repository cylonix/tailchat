// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'package:flutter/material.dart';
import '../../gen/l10n/app_localizations.dart';

class ErrorCode {
  final BuildContext? context;
  final String? code;
  ErrorCode(this.context, this.code);
  String? get message {
    if (context == null) {
      return null;
    }
    final tr = AppLocalizations.of(context!);
    final m = <String, String>{
      "err_bad_user_info": tr.errBadUserInfo,
      "err_device_exists": tr.errDeviceExists,
      "err_email_exists": tr.errEmailExists,
      "err_label_exists": tr.errLabelExists,
      "err_user_exists": tr.errUserExists,
      "err_user_not_exists": tr.errUserNotExists,
      "err_user_profile_not_exists": tr.userAvatarNotExistsText,
    };
    return m[code];
  }
}
