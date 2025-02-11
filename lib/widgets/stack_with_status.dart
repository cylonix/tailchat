// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'package:flutter/material.dart';

class StackWithStatus extends Stack {
  StackWithStatus(Widget child, bool toStack,
      {super.key, Widget? status, double? size})
      : super(
          children: [
            child,
            if (toStack)
              Positioned(
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(1),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  constraints: BoxConstraints(
                    minWidth: size ?? 12,
                    minHeight: size ?? 12,
                  ),
                  child: status,
                ),
              ),
          ],
        );
}
