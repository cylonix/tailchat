// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'package:flutter/material.dart';

class TopRow extends Container {
  TopRow({
    super.key,
    required Widget super.child,
    bool large = false,
    EdgeInsetsGeometry? padding,
  }) : super(
          padding: padding ?? EdgeInsets.only(top: large ? 100 : 50),
          constraints: BoxConstraints(minHeight: large ? 300 : 208),
        );
}
