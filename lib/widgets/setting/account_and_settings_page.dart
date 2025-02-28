// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'package:flutter/material.dart';

import '../../api/config.dart';
import '../../gen/l10n/app_localizations.dart';
import '../../utils/utils.dart';
import '../contacts/user_profile_header.dart';
import '../main_app_bar.dart';
import '../top_row.dart';
import 'settings_widget.dart';

class AccountAndSettingsPage extends StatelessWidget {
  AccountAndSettingsPage({
    super.key,
  });
  final _isTV = Pst.enableTV ?? false;

  bool _showAppBar(context) {
    return !_isTV && !useNavigationRail(context);
  }

  bool get _showFooter {
    return !_isTV;
  }

  Widget get _body {
    if (_isTV) {
      return SettingsWidget(showLoginLogout: !_showFooter);
    }
    return Column(
      children: [
        const SizedBox(height: 8),
        TopRow(
          child: UserProfileHeader(user: Pst.selfUser),
        ),
        const Divider(height: 1),
        const Expanded(child: SettingsWidget(showThemeSetting: true)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final tr = AppLocalizations.of(context);
    return Scaffold(
      appBar: _showAppBar(context) ? MainAppBar(title: tr.settingsTitle) : null,
      body: _showAppBar(context) ? _body : SafeArea(left: false, child: _body),
    );
  }
}
