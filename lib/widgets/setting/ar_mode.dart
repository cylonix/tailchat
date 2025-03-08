// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../api/config.dart';
import '../../gen/l10n/app_localizations.dart';
import '../../utils/utils.dart';
import '../common_widgets.dart';
import 'config_switch.dart';

class ARMode extends StatelessWidget {
  const ARMode({super.key});

  @override
  Widget build(BuildContext context) {
    final tr = AppLocalizations.of(context);
    return ConfigSwitch(
      builder: (context, value, onSet) {
        if (isApple()) {
          return CupertinoListTile(
            leading: getIcon(
              Icons.center_focus_strong,
              darkTheme: isDarkMode(context),
            ),
            trailing: CupertinoSwitch(
              value: value,
              onChanged: onSet,
            ),
            title: Text(tr.enableARSetting),
            onTap: () => onSet(!value),
          );
        }
        return ListTile(
          leading: getIcon(
            Icons.center_focus_strong,
            darkTheme: isDarkMode(context),
          ),
          trailing: Switch(
            value: value,
            onChanged: onSet,
          ),
          title: Text(tr.enableARSetting),
          onTap: () => onSet(!value),
        );
      },
      errAlertPrefix: tr.enableARSetting,
      initialValue: Pst.enableAR,
      toSave: Pst.saveEnableAR,
      onBeginningChange: (value) {
        if (!value) {
          Navigator.pop(context);
        } else {
          switchToDefaultHomePage(context);
        }
      },
    );
  }
}
