// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'dart:async';
import 'package:flutter/material.dart';

import '../../api/config.dart';
import '../../gen/l10n/app_localizations.dart';
import '../../models/theme_change_event.dart';
import '../../utils/global.dart';
import '../../utils/utils.dart';
import '../common_widgets.dart';

class ThemeSettingWidget extends StatefulWidget {
  final bool compact;
  final bool adaptiveIcon;
  final double? size;
  const ThemeSettingWidget({
    super.key,
    this.compact = false,
    this.adaptiveIcon = false,
    this.size,
  });

  @override
  State<ThemeSettingWidget> createState() => _ThemeSettingWidgetState();
}

class _ThemeSettingWidgetState extends State<ThemeSettingWidget> {
  StreamSubscription<ThemeChangeEvent>? _themeChangeSub;
  var _selectedTheme = false;

  @override
  void initState() {
    super.initState();
    _getPstSelectedTheme();
    final eventBus = Global.getThemeEventBus();
    _themeChangeSub = eventBus.on<ThemeChangeEvent>().listen((onData) {
      _selectedTheme = onData.themeIndex == 1 ? true : false;
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _themeChangeSub?.cancel();
    super.dispose();
  }

  void _getPstSelectedTheme() {
    final index = Pst.themeIndex;
    _selectedTheme = index == 1 ? true : false;
  }

  Future<void> _selectDestination(int index) async {
    await Pst.saveThemeIndex(index);
    final eventBus = Global.getThemeEventBus();
    eventBus.fire(ThemeChangeEvent(themeIndex: index));
  }

  @override
  Widget build(BuildContext context) {
    final tr = AppLocalizations.of(context);
    if (widget.compact) {
      return IconButton(
        tooltip: _selectedTheme ? tr.dayMode : tr.nightMode,
        onPressed: () => _selectDestination(_selectedTheme ? 0 : 1),
        icon: Icon(
          _selectedTheme ? Icons.sunny : Icons.nights_stay,
          size: widget.size,
        ),
      );
    }
    if (preferOnOffButtonOverSwitch()) {
      return ListTile(
        leading: getIcon(
          _selectedTheme ? Icons.sunny : Icons.nights_stay,
          darkTheme: isDarkMode(context),
          adaptive: widget.adaptiveIcon,
        ),
        title: Text(
          _selectedTheme ? tr.dayMode : tr.nightMode,
        ),
        onTap: () {
          _selectDestination(_selectedTheme ? 0 : 1);
        },
      );
    }
    return ListTile(
      leading: getIcon(
        Icons.nights_stay,
        darkTheme: isDarkMode(context),
        adaptive: widget.adaptiveIcon,
      ),
      trailing: Switch.adaptive(
        value: _selectedTheme,
        onChanged: (nightModeOn) {
          _selectDestination(nightModeOn ? 1 : 0);
        },
      ),
      title: Text(tr.nightMode),
      onTap: () {
        _selectDestination(_selectedTheme ? 0 : 1);
      },
    );
  }
}
