// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'package:flutter/material.dart';

import 'api/config.dart';
import 'gen/l10n/app_localizations.dart';
import 'models/theme_change_event.dart';
import 'utils/global.dart';

/// enum theme option
/// [ThemeOption.LITHT] Light Mode
/// [ThemeOption.DARK] Dark Mode
enum ThemeOption {
  light,
  dark,
}

/// ThemeOption mapping themes
Map<ThemeOption, String> themeOption(BuildContext context) => {
      ThemeOption.light: AppLocalizations.of(context).lightMode,
      ThemeOption.dark: AppLocalizations.of(context).darkMode,
    };

class ThemePage extends StatefulWidget {
  const ThemePage({super.key});

  @override
  State createState() => _State();
}

class _State extends State<ThemePage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey();
  int _selectedTheme = 0;
  @override
  void initState() {
    _getPstSelectedTheme();
    super.initState();
  }

  /// Get saved theme index
  void _getPstSelectedTheme() {
    final idx = Pst.themeIndex;
    setState(() {
      _selectedTheme = idx ?? 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    const checkIcon = Icon(Icons.check);
    return Scaffold(
        key: _scaffoldKey,
        appBar: AppBar(
          elevation: 0.0,
          title: Text(AppLocalizations.of(context).themeMode),
          centerTitle: true,
        ),
        body: SizedBox(
          width: double.infinity,
          child: ListView(
            // Important: Remove any padding from the ListView.
            padding: EdgeInsets.zero,
            children: <Widget>[
              ListTile(
                trailing: _selectedTheme == 0 ? checkIcon : null,
                title: Text(themeOption(context).values.first),
                selected: _selectedTheme == 0,
                onTap: () => selectDestination(0),
              ),
              const Divider(height: 1, thickness: 1),
              ListTile(
                trailing: _selectedTheme == 1 ? checkIcon : null,
                title: Text(themeOption(context).values.last),
                selected: _selectedTheme == 1,
                onTap: () => selectDestination(1),
              ),
              const Divider(height: 1, thickness: 1),
            ],
          ),
        ));
  }

  Future<void> selectDestination(int index) async {
    await Pst.saveThemeIndex(index);
    final eventBus = Global.getThemeEventBus();
    eventBus.fire(ThemeChangeEvent(themeIndex: index));
    setState(() {
      _selectedTheme = index;
    });
  }
}
