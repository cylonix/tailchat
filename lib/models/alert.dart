// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'package:flutter/material.dart';

enum AlertVariant {
  success,
  error,
  warning,
  info,
}

class Alert {
  final AlertVariant variant;
  final String text;
  const Alert(this.text, {this.variant = AlertVariant.error});
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
        return const Icon(Icons.done);
      case (AlertVariant.error):
        return const Icon(Icons.error);
      case (AlertVariant.warning):
        return const Icon(Icons.warning);
      default:
        return null;
    }
  }
}
