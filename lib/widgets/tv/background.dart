// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'package:flutter/material.dart';

class Background extends Container {
  Background(BuildContext context, {super.key, super.child})
      : super(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            image: const DecorationImage(
              opacity: 0.8,
              image: AssetImage(
                "packages/sase_app_ui/assets/images/background.jpg",
              ),
              fit: BoxFit.cover,
            ),
          ),
        );
}
