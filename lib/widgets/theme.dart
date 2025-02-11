// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'package:flutter/material.dart';
import '../utils/utils.dart';

final _light = ThemeData.light(useMaterial3: enableMaterial3());
final _dark = ThemeData.dark(useMaterial3: enableMaterial3());
final List<ThemeData> themeList = [
  _light.copyWith(
    listTileTheme: _light.listTileTheme.copyWith(
      titleTextStyle:
          (_light.listTileTheme.titleTextStyle ?? _light.textTheme.titleMedium)
              ?.copyWith(
        fontWeight: FontWeight.w500,
      ),
    ),
  ),
  _dark.copyWith(
    listTileTheme: _dark.listTileTheme.copyWith(
      titleTextStyle:
          (_dark.listTileTheme.titleTextStyle ?? _dark.textTheme.titleMedium)
              ?.copyWith(
        fontWeight: FontWeight.w500,
      ),
    ),
  ),
];
