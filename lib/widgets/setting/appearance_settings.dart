// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'package:flutter/material.dart';
import '../../gen/l10n/app_localizations.dart';
import 'theme_setting_widget.dart';
import 'ar_mode.dart';
import 'chat_simple_ui.dart';
import 'setting_app_bar.dart';
import 'text_scale.dart';
import 'tv_mode.dart';

class AppearanceSettings extends StatelessWidget {
  const AppearanceSettings({
    super.key,
    this.showAppBar = true,
    this.showThemeSetting = false,
  });
  final bool showThemeSetting;
  final bool showAppBar;

  @override
  Widget build(BuildContext context) {
    final tr = AppLocalizations.of(context);
    return Scaffold(
      appBar: showAppBar
          ? SettingAppBar(context, tr.appearanceSettingsTitle)
          : null,
      body: ListView(
        children: [
          if (showThemeSetting) const ThemeSettingWidget(),
          const ARMode(),
          const TVMode(),
          const ChatSimpleUI(),
          const TextScale(),
        ],
      ),
    );
  }
}
