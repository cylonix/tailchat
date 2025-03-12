// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'package:flutter/material.dart';

class StackWithStatus extends Stack {
  StackWithStatus(Widget child, bool toStack,
      {super.key, Widget? status, double? size, bool noDecoration = false})
      : super(
          children: [
            child,
            if (toStack)
              Positioned(
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(1),
                  decoration: noDecoration
                      ? null
                      : BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(6),
                        ),
                  constraints: BoxConstraints(
                    maxWidth: size ?? 12,
                    maxHeight: size ?? 12,
                  ),
                  child: status,
                ),
              ),
          ],
        );
}
