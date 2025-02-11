// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'package:flutter/material.dart';
import '../../api/config.dart';

extension BaseInputEdgeInsets on EdgeInsetsGeometry {
  static EdgeInsetsGeometry get padding {
    return EdgeInsets.symmetric(
      vertical: (Pst.enableAR ?? false) ? 0 : 8,
      horizontal: 8,
    );
  }
}

extension BaseInputBorder on OutlineInputBorder {
  static OutlineInputBorder border({Color? color}) {
    return OutlineInputBorder(
      borderSide: color == null ? const BorderSide() : BorderSide(color: color),
    );
  }
}
