// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'dart:async';

import 'package:flutter/material.dart';
import 'api/config.dart';
import 'models/alert.dart';
import 'models/config/config_change_event.dart';
import 'utils/utils.dart';
import 'widgets/alert_chip.dart';
import 'widgets/contacts/contact_list.dart';
import 'widgets/main_app_bar.dart';
import 'widgets/main_drawer.dart';
import 'widgets/slider.dart';
import 'widgets/tv/background.dart';
import 'widgets/tv/caption.dart';
import 'widgets/tv/end_drawer_button.dart' as tv;

class ContactsPage extends StatefulWidget {
  final bool showDrawer;
  const ContactsPage({super.key, this.showDrawer = true});

  @override
  State<ContactsPage> createState() => _ContactsPageState();
}

class _ContactsPageState extends State<ContactsPage>
    with AutomaticKeepAliveClientMixin {
  //static final _logger = Logger(tag: 'ContactsPage');
  static const int _defaultFlex = 30;
  Widget? _selectedWidget;
  StreamSubscription<ConfigChangeEvent>? _configSub;
  Alert? _alert;
  bool _showSideBySide = false;
  bool _isTV = false;
  int _flex = _defaultFlex;

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    _showSideBySide = showSideBySide(context) && !_isTV;
    super.build(context);

    return Scaffold(
      appBar: _showAppBar
          ? MainAppBar(
              titleWidget: isMediumScreen(context)
                  ? ListTile(
                      title: Text("Contacts"),
                      subtitle: Text(
                        Pst.selfDevice?.title ?? "Self device not found.",
                      ),
                    )
                  : Text("Contacts"),
            )
          : null,
      drawer: _showAppBar && widget.showDrawer ? const MainDrawer() : null,
      body: _showAppBar ? SafeArea(left: false, child: _body) : _body,
    );
  }

  Widget get _body {
    return Column(children: [
      if (_alert != null)
        AlertChip(
          _alert!,
          width: double.infinity,
          onDeleted: () {
            setState(() {
              _alert = null;
            });
          },
        ),
      Expanded(child: _showSideBySide ? _tabletLayout : _contactList),
    ]);
  }

  Widget get _contactList {
    final list = ContactList(
      isTV: _isTV,
      showSideBySide: _showSideBySide,
      onSelected: (selectedWidget) {
        if (_showSideBySide) {
          setState(() {
            _selectedWidget = selectedWidget;
          });
          return;
        }
        if (selectedWidget == null) {
          Navigator.of(context).pop();
          return;
        }
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => selectedWidget,
          ),
        );
      },
    );
    if (_isTV) {
      return Stack(children: [
        Background(context),
        Column(
          children: [_topRowForTV, Expanded(child: list)],
        ),
      ]);
    }
    return list;
  }

  Widget get _rightSide {
    return _selectedWidget ?? Container(color: Theme.of(context).canvasColor);
  }

  Widget get _tabletLayout {
    return LayoutBuilder(
      builder: (context, constraints) {
        final listWidth = _flex * constraints.maxWidth / 100;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (listWidth >= 350 || _flex >= _defaultFlex)
              Flexible(flex: _flex, child: _contactList),
            SliderWidget(
              flexScale: 100,
              initialFlex: 30,
              width: constraints.maxWidth,
              onFlexChanged: (flex) {
                setState(() {
                  _flex = flex;
                });
              },
            ),
            Flexible(flex: 100 - _flex, child: _rightSide),
          ],
        );
      },
    );
  }

  bool get _showAppBar {
    return !_isTV && widget.showDrawer;
  }

  Widget get _topRowForTV {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(children: [
        Caption(context, "Contacts"),
        Expanded(
          child: Caption(
            context,
            Pst.selfDevice?.hostname ?? "",
          ),
        ),
        tv.EndDrawerButton(context: context),
      ]),
    );
  }

  @override
  void initState() {
    super.initState();
    _registerConfigChangeEvent();
  }

  @override
  void dispose() {
    _configSub?.cancel();
    super.dispose();
  }

  void _registerConfigChangeEvent() {
    if (Pst.configLoaded) {
      _isTV = Pst.enableTV ?? false;
      _showSideBySide = false;
    }
    _configSub = Pst.eventBus.on<ConfigChangeEvent>().listen((event) {
      if (!mounted) {
        return;
      }
      if (event is ConfigLoadedEvent) {
        setState(() {
          _isTV = Pst.enableTV ?? false;
          _showSideBySide = false;
        });
        return;
      }
      if (event is EnableTVEvent) {
        setState(() {
          _isTV = Pst.enableTV ?? false;
          _showSideBySide = false;
        });
        return;
      }
    });
  }
}
