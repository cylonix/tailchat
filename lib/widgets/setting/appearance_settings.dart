// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:tailchat/utils/utils.dart';
import '../../gen/l10n/app_localizations.dart';
import 'theme_setting_widget.dart';
//import 'ar_mode.dart';
import 'chat_simple_ui.dart';
import 'setting_app_bar.dart';
import 'text_scale.dart';
//import 'tv_mode.dart';

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
    if (isApple()) {
      return CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(
          middle: Text(tr.appearanceSettingsTitle),
        ),
        child: Container(
          padding: const EdgeInsets.only(
            top: 80,
            right: 16,
            left: 16,
            bottom: 32,
          ),
          child: CupertinoListSection.insetGrouped(
            margin: const EdgeInsets.all(16),
            header: const Text("Style options"),
            children: [
              if (showThemeSetting)
                const ThemeSettingWidget(adaptiveIcon: true),
              //const ARMode(),
              //const TVMode(),
              const ChatSimpleUI(),
              const TextScale(),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      appBar: showAppBar
          ? SettingAppBar(context, tr.appearanceSettingsTitle)
          : null,
      body: ListView(
        padding: EdgeInsets.all(8),
        children: [
          Card(
            child: Column(
              children: [
                if (showThemeSetting) ...[
                  const ThemeSettingWidget(),
                  const Divider(height: 1),
                ],
                //const ARMode(),
                //const Divider(height: 1),
                //const TVMode(),
                //const Divider(height: 1),
                const ChatSimpleUI(),
              ],
            ),
          ),
          Card(
            child: const TextScale(),
          ),
        ],
      ),
    );
  }
}
