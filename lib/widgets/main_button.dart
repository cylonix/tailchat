// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'package:flutter/material.dart';
import 'base_input/button.dart';

class MainButton extends BaseInputButton {
  MainButton(BuildContext context, IconData icon, String label,
      {super.key, Color? iconColor, required void Function() super.onPressed})
      : super(
          height: 160,
          width: 160,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 60,
                color: iconColor,
              ),
              LayoutBuilder(builder: (
                BuildContext context,
                BoxConstraints constraints,
              ) {
                return constraints.maxWidth >= 120.0
                    ? Padding(
                        padding: const EdgeInsets.all(10),
                        child: Text(label),
                      )
                    : Container();
              }),
            ],
          ),
        );
}
