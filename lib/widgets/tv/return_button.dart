// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'package:flutter/material.dart';
import '../../gen/l10n/app_localizations.dart';

class ReturnButton extends StatelessWidget {
  final bool showText;
  final bool showTextAsSubtitle;
  const ReturnButton({
    super.key,
    this.showText = true,
    this.showTextAsSubtitle = true,
  });

  @override
  Widget build(BuildContext context) {
    final tr = AppLocalizations.of(context);
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        child: ListTile(
          title: const Icon(Icons.arrow_back),
          subtitle: showText && showTextAsSubtitle
              ? Text(
                  tr.returnText,
                  textAlign: TextAlign.center,
                )
              : null,
          trailing: showText && !showTextAsSubtitle
              ? Text(
                  tr.returnText,
                  textAlign: TextAlign.center,
                )
              : null,
        ),
        onTap: () => Navigator.of(context).pop(),
      ),
    );
  }
}
