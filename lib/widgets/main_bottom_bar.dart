// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/config.dart';
import '../gen/l10n/app_localizations.dart';
import '../models/config/config_change_event.dart';
import '../utils/global.dart';
import 'contacts_icon.dart';
import 'sessions_icon.dart';

enum MainBottomBarPage {
  home,
  settings,
  contacts,
  sessions,
}

enum VisibleMainBottomBarPage {
  contacts,
  sessions,
}

enum VisibleDesktopPages {
  home,
  settings,
  contacts,
  sessions,
}

enum VisibleTVPages {
  settings,
  contacts,
  sessions,
}

class MainBottomBar extends StatefulWidget {
  const MainBottomBar({super.key});

  @override
  State<MainBottomBar> createState() => _MainBottomBarState();

  static int pageIndexOf(MainBottomBarPage page) {
    return page.index;
  }
}

class _MainBottomBarState extends State<MainBottomBar> {
  StreamSubscription<ConfigChangeEvent>? _configSub;
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = _defaultIndex;
    _registerToBottomBarSelectionNotice();
    _registerToConfigChangeEvents();
  }

  @override
  void dispose() {
    _configSub?.cancel();
    super.dispose();
  }

  void _registerToConfigChangeEvents() {
    final eventBus = Pst.eventBus;
    _configSub = eventBus.on<ConfigChangeEvent>().listen((event) {
      if (event is ConfigLoadedEvent) {
        _selectedIndex = _defaultIndex;
      }
    });
  }

  /// Skip home, settings, and qrscan.
  int get _indexBase {
    return MainBottomBarPage.contacts.index;
  }

  /// Default to be on video calls page. If not autostart then on VPN page.
  int get _defaultIndex {
    return VisibleMainBottomBarPage.sessions.index;
  }

  void _registerToBottomBarSelectionNotice() {
    final notifier = context.read<BottomBarSelection>();
    notifier.addListener(() {
      var index = notifier.getIndex() - _indexBase;
      if (index < 0) {
        index = _defaultIndex;
      }
      if (mounted) {
        setState(() {
          _selectedIndex = index;
        });
      }
    });
  }

  void _onItemTapped(int index) {
    final notifier = context.read<BottomBarSelection>();
    notifier.select(index + _indexBase);
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tr = AppLocalizations.of(context);
    // Make sure the list of the items are the same as VisibleBottomBarPages.
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      items: <BottomNavigationBarItem>[
        BottomNavigationBarItem(
          icon: const ContactsIcon(),
          label: tr.contactsTitle,
        ),
        BottomNavigationBarItem(
          icon: const SessionsIcon(),
          label: "Chats",
        ),
      ],
      selectedItemColor: Colors.blue,
      currentIndex: _selectedIndex,
      onTap: _onItemTapped,
    );
  }
}

class BottomBarSelection extends ChangeNotifier {
  int _pageIndex = -1; // Default to an invalid index.
  void select(int index) {
    _pageIndex = index;
    Global.logger.d("selecting page index $index");
    notifyListeners();
  }

  void selectPage(MainBottomBarPage page) {
    select(page.index);
  }

  int getIndex() {
    return _pageIndex;
  }
}

class BottomBarSessionNoticeCount extends ChangeNotifier {
  int _count = 0;
  void add(int inc) {
    _count += inc;
    notifyListeners();
  }

  void set(int count) {
    _count = count;
    notifyListeners();
  }

  void clear() {
    if (_count != 0) {
      _count = 0;
      notifyListeners();
    }
  }

  int getCount() {
    return _count;
  }
}

class BottomBarContactNotice extends ChangeNotifier {
  bool hasNotice = false;
  void set(bool state) {
    hasNotice = state;
    notifyListeners();
  }
}
