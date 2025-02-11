// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'package:flutter/material.dart';
import '../../gen/l10n/app_localizations.dart';
import 'icon_button.dart';

class EndDrawerButton extends IconButtonWidget {
  EndDrawerButton({
    super.key,
    required BuildContext context,
  }) : super(
          debugLabel: "end-drawer-button",
          icon: const Icon(Icons.settings),
          onPressed: () => Scaffold.of(context).openEndDrawer(),
          size: 48,
          tooltip: AppLocalizations.of(context).settingsTitle,
        );
}
