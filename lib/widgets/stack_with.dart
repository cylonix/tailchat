// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'package:flutter/material.dart';

class StackWith extends Stack {
  StackWith({
    super.key,
    required List<Widget> bottom,
    required Widget top,
    required bool toStackOn,
    bool withModalBarrier = true,
  }) : super(
          children: [
            ...bottom,
            if (toStackOn && withModalBarrier)
              const Opacity(
                opacity: 0.8,
                child: ModalBarrier(dismissible: false, color: Colors.black),
              ),
            if (toStackOn) top,
          ],
        );
}
