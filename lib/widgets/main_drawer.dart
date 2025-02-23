// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../about_page.dart';
import '../api/config.dart';
import '../gen/l10n/app_localizations.dart';
import '../utils/utils.dart';
import 'common_widgets.dart';
import 'contacts_icon.dart';
import 'contacts/user_profile_header.dart';
import 'main_bottom_bar.dart';
import 'sessions_icon.dart';
import 'setting/settings_page.dart';
import 'setting/theme_setting_widget.dart';
import 'status_widget.dart';

class MainDrawer extends StatefulWidget {
  const MainDrawer({super.key});

  @override
  State<MainDrawer> createState() => _MainDrawerState();
}

class _MainDrawerState extends State<MainDrawer> {
  bool get _isAR {
    return Pst.enableAR ?? false;
  }

  bool get _isTV {
    return Pst.enableTV ?? false;
  }

  bool get _showHomeButton {
    return isDesktop() && !_isAR && !_isTV;
  }

  bool get _showStatus {
    return !_isTV;
  }

  bool get _showThemeSetting {
    return !_isTV && !_isAR;
  }

  void _selectTVPage(MainBottomBarPage page) {
    final notifier = context.read<BottomBarSelection>();
    Navigator.of(context).pop();
    FocusScope.of(context).unfocus();
    notifier.selectPage(page);
  }

  List<Widget> get _tvMenuItems {
    final tr = AppLocalizations.of(context);
    return [
      ListTile(
        leading: const ContactsIcon(useDefaultColor: true),
        title: Text(tr.contactsTitle),
        onTap: () => _selectTVPage(MainBottomBarPage.contacts),
      ),
      ListTile(
        leading: const SessionsIcon(useDefaultColor: true),
        title: Text(tr.sessionsTitle),
        onTap: () => _selectTVPage(MainBottomBarPage.sessions),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final tr = AppLocalizations.of(context);
    return SafeArea(
      child: Drawer(
        semanticLabel: tr.sidebarText,
        width: isMediumScreen(context) ? 400 : 320,
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(0),
          children: <Widget>[
            ConstrainedBox(
              constraints: BoxConstraints(minHeight: _isAR ? 100 : 200.0),
              child: UserProfileHeader(
                user: Pst.selfUser,
              ),
            ),
            const Divider(height: 1),
            const SizedBox(height: 8),
            if (_showHomeButton)
              ListTile(
                leading: _listIcon(Icons.home),
                title: Text(tr.homeText),
                onTap: () {
                  Navigator.popUntil(
                    context,
                    ModalRoute.withName('/'),
                  );
                },
              ),
            if (_showThemeSetting)
              const ThemeSettingWidget(adaptiveIcon: false),
            if (_showStatus) const StatusWidget(),
            ListTile(
              leading: _listIcon(Icons.settings),
              title: Text(tr.settingsTitle),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const SettingsPage(
                      showThemeSetting: true,
                    ),
                  ),
                );
              },
            ),
            if (_isTV) ..._tvMenuItems,
            if (!_isAR)
              ListTile(
                leading: _listIcon(Icons.info),
                title: Text(tr.aboutTitle),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const AboutPage(),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _listIcon(IconData icon, {Color? color}) {
    return getIcon(
      icon,
      color: color,
      darkTheme: isDarkMode(context),
      adaptive: false,
    );
  }
}
