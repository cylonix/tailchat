// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'package:flutter/material.dart';

class Caption extends Text {
  Caption(BuildContext context, super.text, {super.key})
      : super(
          style: Theme.of(context).textTheme.titleLarge,
          textAlign: TextAlign.center,
        );
}
