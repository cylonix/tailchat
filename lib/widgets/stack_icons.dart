// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'package:flutter/material.dart';

class StackIcons extends SizedBox {
  StackIcons(
    IconData icon1,
    IconData icon2, {
    super.key,
    double? size,
    Color? color1,
    Color? color2,
  })
      : super(
          height: size ?? 24,
          width: size ?? 24,
          child: Stack(
            alignment: Alignment.bottomLeft,
            children: [
              Icon(icon1, size: (size ?? 24) * 0.6, color: color1),
              Positioned(
                right: 0,
                top: 0,
                child: Icon(icon2, size: (size ?? 24) * 0.6, color: color2),
              ),
            ],
          ),
        );
}
