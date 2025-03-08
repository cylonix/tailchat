// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'package:flutter/material.dart';

import '../../api/config.dart';
import '../../gen/l10n/app_localizations.dart';
import '../main_app_bar.dart';
import 'settings_widget.dart';

class SettingsPage extends StatelessWidget {
  final bool aRMode;
  final bool showThemeSetting;
  const SettingsPage({
    super.key,
    this.aRMode = false,
    this.showThemeSetting = false,
  });

  bool get _showAppBar {
    return !aRMode && !(Pst.enableTV ?? false);
  }

  @override
  Widget build(BuildContext context) {
    final tr = AppLocalizations.of(context);

    return Scaffold(
      appBar: _showAppBar ? MainAppBar(title: tr.settingsTitle) : null,
      body: SettingsWidget(
        showThemeSetting: showThemeSetting,
      ),
    );
  }
}
