// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'dart:async';
import 'package:collection/collection.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../about_page.dart';
import '../api/config.dart';
import '../gen/l10n/app_localizations.dart';
import '../models/config/config_change_event.dart';
import '../utils/utils.dart';
import 'common_widgets.dart';
import 'contacts_icon.dart';
import 'contacts/user_avatar.dart';
import 'contacts/user_profile_header.dart';
import 'main_bottom_bar.dart';
import 'sessions_icon.dart';
import 'status_widget.dart';
import 'setting/theme_setting_widget.dart';
import 'top_row.dart';

class MainNavigationRail extends StatefulWidget {
  final void Function(int)? onSelected;
  const MainNavigationRail({super.key, this.onSelected});

  @override
  State<MainNavigationRail> createState() => _MainNavigationRailState();
}

class _MainNavigationRailState extends State<MainNavigationRail> {
  int _selectedIndex = 0;
  bool _extended = false;
  StreamSubscription<ConfigChangeEvent>? _configSub;
  late final FocusNode _contractFocus, _expandFocus, _infoFocus;
  bool _isTV = Pst.enableTV ?? false;
  String _focusLabel = "";

  @override
  void initState() {
    super.initState();
    _selectedIndex = _defaultIndex;
    _registerToBottomBarSelectionNotice();
    _registerToConfigChangeEvents();
    _contractFocus = FocusNode();
    _expandFocus = FocusNode();
    _infoFocus = FocusNode();
    _contractFocus.addListener(() {
      setState(() {});
    });
    _expandFocus.addListener(() {
      setState(() {
        if (_expandFocus.hasFocus) {
          _focusLabel = "expand";
        }
      });
    });
    _infoFocus.addListener(() {
      setState(() {
        if (_infoFocus.hasFocus) {
          _focusLabel = "info";
        }
      });
    });
  }

  @override
  void dispose() {
    _configSub?.cancel();
    _contractFocus.dispose();
    _expandFocus.dispose();
    _infoFocus.dispose();
    super.dispose();
  }

  void _registerToBottomBarSelectionNotice() {
    final notifier = context.read<BottomBarSelection>();
    notifier.addListener(() {
      var index = notifier.getIndex();
      final page = MainBottomBarPage.values[index].name;
      if (_isTV) {
        index = VisibleTVPages.values
            .firstWhere(
              (e) => e.name == page,
              orElse: () => VisibleTVPages.sessions,
            )
            .index;
      } else if (isDesktop()) {
        index = VisibleDesktopPages.values
            .firstWhere(
              (e) => e.name == page,
              orElse: () => VisibleDesktopPages.sessions,
            )
            .index;
      }
      if (index > _maxIndex) {
        index = _maxIndex;
      }
      if (mounted) {
        setState(() {
          _selectedIndex = index;
        });
      }
    });
  }

  void _registerToConfigChangeEvents() {
    final eventBus = Pst.eventBus;
    _configSub = eventBus.on<ConfigChangeEvent>().listen((event) {
      if (!mounted) {
        return;
      }
      if (event is ConfigLoadedEvent || event is EnableTVEvent) {
        if (mounted) {
          setState(() {
            _isTV = Pst.enableTV ?? false;
            _selectedIndex = _defaultIndex;
          });
        }
      }
    });
  }

  /// Default to be on sessions page. If not autostart then on VPN page.
  int get _defaultIndex {
    if (_isTV) {
      return VisibleTVPages.sessions.index;
    }
    if (isDesktop()) {
      return VisibleDesktopPages.sessions.index;
    }
    return MainBottomBarPage.sessions.index;
  }

  int get _maxIndex {
    if (_isTV) {
      return VisibleTVPages.values.length - 1;
    }
    if (isDesktop()) {
      return VisibleDesktopPages.values.length - 1;
    }
    return MainBottomBarPage.values.length - 1;
  }

  int _toNotifyIndex(int index) {
    if (index > _maxIndex) {
      index = _maxIndex;
    }
    var page = MainBottomBarPage.values[index].name;
    if (_isTV) {
      page = VisibleTVPages.values[index].name;
    } else if (isDesktop()) {
      page = VisibleDesktopPages.values[index].name;
    } else {
      return index;
    }
    index = MainBottomBarPage.values
        .firstWhere(
          (e) => e.name == page,
          orElse: () => MainBottomBarPage.sessions,
        )
        .index;
    return index;
  }

  Widget get _userCard {
    return Column(
      children: [
        TopRow(
          child: UserProfileHeader(user: Pst.selfUser),
        ),
        const Divider(height: 1),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget get _userAvatar {
    return UserAvatar(
      user: Pst.selfUser,
      radius: 24,
      onTap: () {
        final user = Pst.selfUser;
        if (user != null) {
          final index = MainBottomBarPage.values
              .firstWhereOrNull(
                (e) => e.name == MainBottomBarPage.contacts.name,
              )
              ?.index;
          if (index != null) {
            widget.onSelected?.call(index);
          }
        }
      },
    );
  }

  void _showAboutPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AboutPage(),
      ),
    );
  }

  Widget? get _leading {
    if (_extended) {
      return Container(
        margin: const EdgeInsets.all(0),
        constraints: const BoxConstraints(maxWidth: 400),
        child: _userCard,
      );
    }
    final tr = AppLocalizations.of(context);
    return Container(
      constraints: const BoxConstraints(maxWidth: 400),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _userAvatar,
          const SizedBox(height: 16),
          IconButton(
            focusNode: _expandFocus,
            tooltip: tr.expandText,
            onPressed: () {
              setState(() {
                _extended = true;
              });
            },
            icon: _icon(
              isApple() ? CupertinoIcons.chevron_right : Icons.arrow_forward,
              size: _iconSize("expand"),
            ),
          ),
        ],
      ),
    );
  }

  void _onFocusChange(bool? value, String label) {
    if (value == true) {
      setState(() {
        _focusLabel = label;
      });
    }
  }

  Widget get _trailing {
    final tr = AppLocalizations.of(context);
    final extended = _extended;
    return Container(
      padding: EdgeInsets.only(
        left: extended ? 8 : 0,
      ),
      constraints: const BoxConstraints(maxWidth: 400),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 16),
          if (extended) const Divider(height: 1),
          if (extended) const SizedBox(height: 8),
          if (!_isTV)
            Focus(
              onFocusChange: (value) => _onFocusChange(value, "theme"),
              child: ThemeSettingWidget(
                compact: !extended,
                adaptiveIcon: false,
                size: _iconSize("theme"),
              ),
            ),
          if (!_isTV)
            Focus(
              onFocusChange: (value) => _onFocusChange(value, "status"),
              child: StatusWidget(
                compact: !extended,
                size: _iconSize("status"),
              ),
            ),
          extended
              ? _about
              : IconButton(
                  focusNode: _infoFocus,
                  icon: Icon(
                    isApple() ? CupertinoIcons.info : Icons.info,
                    size: _iconSize("info"),
                  ),
                  tooltip: tr.aboutTitle,
                  onPressed: _showAboutPage,
                ),
        ],
      ),
    );
  }

  void _switchToAboutPage() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const AboutPage(),
      ),
    );
  }

  Widget get _about {
    final tr = AppLocalizations.of(context);
    if (isApple()) {
      return CupertinoListTile(
        leading: getIcon(CupertinoIcons.info, adaptive: false),
        title: Text(tr.aboutTitle),
        onTap: _switchToAboutPage,
      );
    }
    return ListTile(
      leading: getIcon(Icons.info, adaptive: false),
      title: Text(tr.aboutTitle),
      onTap: _switchToAboutPage,
    );
  }

  NavigationRailDestination _rail(bool extended, Widget icon, String label) {
    return NavigationRailDestination(
      icon: Focus(
        onFocusChange: (value) => _onFocusChange(value, label),
        child: extended ? icon : Tooltip(message: label, child: icon),
      ),
      label: Text(label),
      padding: extended ? EdgeInsets.only(left: 8) : null,
    );
  }

  double _iconSize(String label) {
    return MediaQuery.of(context).textScaler.scale(
          _focusLabel == label ? 36 : 24,
        );
  }

  Widget _icon(IconData icon, {double? size}) {
    return Icon(icon, size: size);
  }

  List<NavigationRailDestination> get _destinations {
    final tr = AppLocalizations.of(context);
    final extended = _extended;
    return [
      if (!_isTV)
        _rail(
          extended,
          _icon(
            isApple() ? CupertinoIcons.home : Icons.home,
            size: _iconSize(tr.homeText),
          ),
          tr.homeText,
        ),
      _rail(
        extended,
        _icon(
          isApple() ? CupertinoIcons.settings : Icons.settings,
          size: _iconSize(tr.settingsTitle),
        ),
        tr.settingsTitle,
      ),
      _rail(
        extended,
        ContactsIcon(
          useDefaultColor: true,
          size: _iconSize(tr.contactsTitle),
        ),
        tr.contactsTitle,
      ),
      _rail(
        extended,
        SessionsIcon(
          useDefaultColor: true,
          size: _iconSize(tr.sessionsTitle),
        ),
        'Chats',
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final extended = _extended;
    final tr = AppLocalizations.of(context);
    final unselectedTextStyle = Theme.of(context).textTheme.titleMedium;
    final selectedTextStyle = unselectedTextStyle?.apply(
      fontSizeDelta: 3,
      fontWeightDelta: 3,
      color: enableMaterial3() ? focusColor(context) : null,
    );

    final child = Stack(
      children: [
        SafeArea(
          top: false,
          bottom: false,
          right: false,
          child: LayoutBuilder(builder: (context, constraint) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraint.maxHeight),
                child: IntrinsicHeight(
                  child: NavigationRail(
                    minWidth: 64,
                    minExtendedWidth: 400,
                    leading: _leading,
                    trailing: _trailing,
                    selectedIndex: _selectedIndex,
                    groupAlignment: -1.0,
                    extended: extended,
                    onDestinationSelected: (int index) {
                      setState(() {
                        _selectedIndex = index;
                        widget.onSelected?.call(_toNotifyIndex(index));
                      });
                    },
                    unselectedLabelTextStyle: unselectedTextStyle,
                    selectedLabelTextStyle: selectedTextStyle,
                    destinations: _destinations,
                    indicatorColor: Colors.blue.withValues(alpha: 0.2),
                  ),
                ),
              ),
            );
          }),
        ),
        if (extended)
          Positioned(
            right: 0,
            top: 80,
            child: IconButton(
              focusNode: _contractFocus,
              focusColor: Colors.pinkAccent,
              iconSize: _contractFocus.hasFocus ? 64 : null,
              padding: const EdgeInsets.all(0),
              tooltip: tr.compactText,
              icon: Icon(
                isApple() ? CupertinoIcons.chevron_left : Icons.arrow_back,
              ),
              onPressed: () {
                setState(() {
                  _extended = false;
                });
              },
            ),
          ),
      ],
    );

    // Capture go-back key event and minimize the rail if it is extended.
    return Focus(
      child: child,
      onKeyEvent: (node, event) {
        if (event is KeyUpEvent &&
            event.logicalKey == LogicalKeyboardKey.goBack) {
          if (_extended) {
            setState(() {
              _extended = false;
            });
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
    );
  }
}
