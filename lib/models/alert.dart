// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:tailchat/utils/utils.dart';

enum AlertVariant {
  success,
  error,
  warning,
  info,
}

class Alert {
  final AlertVariant variant;
  final String text;
  final String? setter;
  const Alert(this.text, {this.setter, this.variant = AlertVariant.error});
  Color? get color {
    switch (variant) {
      case (AlertVariant.success):
        return Colors.green;
      case (AlertVariant.error):
        return Colors.red;
      case (AlertVariant.warning):
        return Colors.orange;
      default:
        return null;
    }
  }

  Color? get background {
    switch (variant) {
      case (AlertVariant.success):
        return null;
      case (AlertVariant.error):
        return null;
      case (AlertVariant.warning):
        return Colors.grey.shade800;
      default:
        return null;
    }
  }

  Widget? get avatar {
    switch (variant) {
      case (AlertVariant.success):
        return Icon(isApple() ? CupertinoIcons.checkmark : Icons.done);
      case (AlertVariant.error):
        return Icon(
          isApple() ? CupertinoIcons.exclamationmark_octagon : Icons.error,
          color: Colors.red,
        );
      case (AlertVariant.warning):
        return Icon(
          isApple() ? CupertinoIcons.exclamationmark_triangle : Icons.warning,
          color: Colors.amber,
        );
      default:
        return null;
    }
  }
}
