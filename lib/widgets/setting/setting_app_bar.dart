// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'package:flutter/material.dart';
import '../../api/config.dart';
import '../../utils/utils.dart';

class SettingAppBar extends AppBar {
  SettingAppBar(
    BuildContext context,
    String title, {
    super.key,
  }) : super(
          title: Text(title),
          automaticallyImplyLeading:
              !(Pst.enableTV ?? false || isLargeScreen(context)),
        );
}
