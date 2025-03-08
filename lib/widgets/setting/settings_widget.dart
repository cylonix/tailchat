// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../api/config.dart';
import '../../gen/l10n/app_localizations.dart';
import '../../utils/utils.dart';
import '../common_widgets.dart';
import '../tv/left_side.dart';
import '../tv/return_button.dart';
import 'advanced_settings_widget.dart';
import 'appearance_settings.dart';
import 'ar_mode.dart';
import 'theme_setting_widget.dart';

class SettingsWidget extends StatefulWidget {
  final bool showThemeSetting;
  const SettingsWidget({
    super.key,
    this.showThemeSetting = false,
  });
  @override
  State<SettingsWidget> createState() => _SettingsWidgetState();
}

class _SettingsWidgetState extends State<SettingsWidget> {
  Widget _rightSide = Container();
  String _rightSidePageName = "";

  bool get _enableAR {
    return Pst.enableAR ?? false;
  }

  bool get _enableTV {
    return Pst.enableTV ?? false;
  }

  bool get _showSideBySide {
    return _enableTV || (!_enableAR && isLargeScreen(context));
  }

  void _pushPage(Widget page, String name) {
    return _showSideBySide
        ? setState(() {
            _rightSide = page;
            _rightSidePageName = name;
          })
        : Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => page),
          );
  }

  void _openAppearanceSettingPage() {
    _pushPage(
      AppearanceSettings(
        showAppBar: !_showSideBySide,
        showThemeSetting: widget.showThemeSetting,
      ),
      "appearance",
    );
  }

  Widget get _appearance {
    final tr = AppLocalizations.of(context);
    final leading = getIcon(
      Icons.display_settings,
      darkTheme: isDarkMode(context),
    );

    if (isApple()) {
      return CupertinoListTile(
        leading: leading,
        title: Text(tr.appearanceTitle),
        onTap: _openAppearanceSettingPage,
      );
    }
    return ListTile(
      leading: leading,
      title: Text(tr.appearanceTitle),
      onTap: _openAppearanceSettingPage,
      selected: _rightSidePageName == "appearance",
    );
  }

  void _pushAdanvedSettingPage() {
    _pushPage(
      AdvancedSettingsWidget(
        showAppBar: !_showSideBySide,
      ),
      "advanced",
    );
  }

  Widget get _advanced {
    final tr = AppLocalizations.of(context);
    final leading = getIcon(
      Icons.settings_ethernet_rounded,
      darkTheme: isDarkMode(context),
    );
    if (isApple()) {
      return CupertinoListTile(
        leading: leading,
        title: Text(tr.advancedSettingsTitle),
        onTap: _pushAdanvedSettingPage,
      );
    }
    return ListTile(
      leading: leading,
      title: Text(tr.advancedSettingsTitle),
      onTap: _pushAdanvedSettingPage,
      selected: _rightSidePageName == "advanced",
    );
  }

  List<Widget> get _settingList {
    return [
      _appearance,
      _advanced,
    ];
  }

  Widget _buildForARorTV(List<Widget> children, {bool scaleDown = false}) {
    final tr = AppLocalizations.of(context);
    final style = scaleDown
        ? Theme.of(context).textTheme.bodySmall
        : Theme.of(context).textTheme.titleLarge;
    final color = Theme.of(context).focusColor;
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: LeftSide(
            mainAxisAlignment: MainAxisAlignment.start,
            color: _enableTV ? color : null,
            children: [
              if (_enableTV) ...[
                ReturnButton(),
                const SizedBox(height: 16),
                Text(
                  tr.settingsTitle,
                  style: style,
                  textAlign: TextAlign.center,
                ),
                Expanded(
                  child: Column(
                    children: children.map((e) => Expanded(child: e)).toList(),
                  ),
                ),
              ],
              if (!_enableTV) _fullSettingList,
            ],
          ),
        ),
        Expanded(
          flex: 3,
          child: Padding(
            padding: const EdgeInsets.only(top: 32),
            child: _rightSide,
          ),
        ),
      ],
    );
  }

  Widget get _buildForARSmallScreen {
    return Column(
      children: [
        if (!enableARByDefault) const ARMode(),
        const ThemeSettingWidget(adaptiveIcon: true),
      ],
    );
  }

  Widget get _buildForTV {
    return _buildForARorTV(_settingList);
  }

  Widget get _fullSettingList {
    if (isApple()) {
      return CupertinoListSection.insetGrouped(
        children: _settingList,
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      shrinkWrap: true,
      controller: ScrollController(),
      children: _settingList.map((e) => Card(child: e)).toList(),
    );
  }

  Widget get _setting {
    if (_enableAR) {
      return _buildForARSmallScreen;
    }
    if (_enableTV || isLargeScreen(context)) {
      return _buildForTV;
    }
    return _fullSettingList;
  }

  @override
  Widget build(BuildContext context) {
    return _setting;
  }
}
