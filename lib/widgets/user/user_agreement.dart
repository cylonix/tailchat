// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'dart:io';

import 'package:flutter/material.dart';
import '../../api/config.dart';
import '../../gen/l10n/app_localizations.dart';
import '../base_input/button.dart';
import '../url_link.dart';

class UserAgreement extends StatelessWidget {
  final void Function() onAgreed;
  const UserAgreement({
    super.key,
    required this.onAgreed,
  });

  bool get _isAR {
    return Pst.enableAR ?? false;
  }

  Widget get _divider {
    return SizedBox(height: _isAR ? 4 : 16);
  }

  @override
  Widget build(BuildContext context) {
    final tr = AppLocalizations.of(context);
    final style = (Pst.enableTV ?? false)
        ? Theme.of(context).textTheme.titleMedium
        : null;

    return Column(
      children: [
        _divider,
        Text(tr.policyDialog, textAlign: TextAlign.justify, style: style),
        _divider,
        Wrap(
          spacing: 16,
          runSpacing: _isAR ? 4 : 16,
          children: [
            UrlLink(
              label: tr.userAgreement,
              url: "https://cylonix.io/web/view/tailchat/terms.html",
            ),
            UrlLink(
              label: tr.policyTitle,
              url: "https://cylonix.io/web/view/tailchat/privacy_policy.html",
            ),
            BaseInputButton(
              autoFocus: true,
              height: _isAR ? 30 : 40,
              width: _isAR ? null : 200,
              onPressed: onAgreed,
              filledButton: true,
              child: Text(tr.agree, style: style),
            ),
            BaseInputButton(
              height: _isAR ? 30 : 40,
              width: _isAR ? null : 200,
              outlineButton: true,
              onPressed: () => exit(0),
              child: Text(tr.disAgree, style: style),
            ),
          ],
        ),
        _divider,
      ],
    );
  }
}
