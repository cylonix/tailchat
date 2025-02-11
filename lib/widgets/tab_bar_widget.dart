// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'package:flutter/material.dart';
import '../api/config.dart';
import '../utils/utils.dart';
import 'base_input/button.dart';
import 'common_widgets.dart';
import 'tv/menu_button.dart';

/// From tab.dart.
const double _kTabHeight = 46.0;
const double _kTextAndIconTabHeight = 72.0;

class TabBarWidget extends StatefulWidget implements PreferredSizeWidget {
  final bool? asMenu;
  final int initialIndex;
  final Widget? leading;
  final MainAxisAlignment? mainAxisAlignment;
  final void Function(int)? onTabSelected;
  final List<Widget> tabs;
  final List<Widget> tabMenuItems;
  final List<Widget>? trailing;
  final bool? withIcon;
  const TabBarWidget({
    super.key,
    this.asMenu = false,
    this.initialIndex = 0,
    this.leading,
    this.mainAxisAlignment,
    this.onTabSelected,
    required this.tabs,
    required this.tabMenuItems,
    this.trailing,
    this.withIcon,
  });

  @override
  Size get preferredSize {
    if (withIcon ?? false) {
      return const Size.fromHeight(_kTextAndIconTabHeight);
    } else {
      return const Size.fromHeight(_kTabHeight);
    }
  }

  @override
  State<TabBarWidget> createState() => _TabBarWidgetState();
}

class _TabBarWidgetState extends State<TabBarWidget> {
  int _initialIndex = 0;
  int _selectedIndex = 0;
  FocusNode? _focus;

  @override
  void initState() {
    super.initState();
    if (Pst.enableTV ?? false) {
      _focus = FocusNode(debugLabel: "tab-bar-widget");
      _focus?.addListener(() {
        setState(() {});
      });
    }
    _initialIndex = widget.initialIndex;
    _selectedIndex = _initialIndex;
  }

  @override
  void dispose() {
    _focus?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final tabWidgets = <Widget>[];

    if ((widget.asMenu ?? false) || !enableMaterial3()) {
      if (widget.leading == null && widget.trailing == null) {
        return _asMenu;
      }
      return SafeArea(
        left: false, // Navigation rail already protects it.
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              if (widget.leading != null) widget.leading!,
              Expanded(
                child: Container(
                  alignment: Alignment.center,
                  child: _asMenu,
                ),
              ),
              if (widget.trailing != null) ...widget.trailing!,
            ],
          ),
        ),
      );
    }

    for (int i = 0; i < widget.tabs.length; i++) {
      tabWidgets.add(
        Container(
          padding: const EdgeInsets.only(left: 8, right: 8),
          child: i == _selectedIndex
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    widget.tabs[i],
                    const SizedBox(width: 8),
                    const Icon(Icons.check, size: 16)
                  ],
                )
              : widget.tabs[i],
        ),
      );
    }

    return DefaultTabController(
      length: widget.tabs.length,
      initialIndex: _initialIndex,
      child: SafeArea(
        left: false, // Navigation rail already protects it.
        child: Row(
          mainAxisAlignment:
              widget.mainAxisAlignment ?? MainAxisAlignment.spaceBetween,
          children: [
            if (widget.leading != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: widget.leading,
              ),
            Expanded(
              child: Container(
                margin: const EdgeInsets.only(top: 4),
                child: TabBar(
                  labelPadding: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.all(0),
                  indicatorPadding: const EdgeInsets.only(top: 4),
                  indicatorSize: TabBarIndicatorSize.label,
                  labelStyle: t.textTheme.titleMedium?.apply(
                    fontWeightDelta: 2,
                  ),
                  unselectedLabelStyle: t.textTheme.titleMedium?.apply(
                    fontSizeDelta: -2,
                    fontWeightDelta: -2,
                  ),
                  tabs: tabWidgets,
                  onTap: _handleSelect,
                ),
              ),
            ),
            if (widget.trailing != null) ...widget.trailing!,
          ],
        ),
      ),
    );
  }

  void _handleSelect(int index) {
    setState(() => _selectedIndex = index);
    widget.onTabSelected?.call(index);
  }

  Widget _menuButton(MenuController? controller) {
    return SizedBox(
      height: focusAwareSize(context, _focus, 32, zoom: 1.5),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          widget.tabMenuItems[_selectedIndex],
          const SizedBox(width: 8),
          Icon(
            (controller?.isOpen ?? false)
                ? Icons.expand_less
                : Icons.expand_more,
          ),
        ],
      ),
    );
  }

  void _menuPressed(MenuController? controller) {
    if (controller != null) {
      setState(() {}); // Re-draw the icon.
      controller.isOpen ? controller.close() : controller.open();
    }
  }

  Widget get _asMenu {
    final menuItems = <MenuItem>[];
    for (var i = 0; i < widget.tabMenuItems.length; i++) {
      menuItems.add(MenuItem(
        child: widget.tabMenuItems[i],
        onPressed: () => _handleSelect(i),
      ));
    }
    return MenuButtonWidget(
      builder: (context, controller, child) {
        if (controller != null) {
          return BaseInputButton(
            focusNode: _focus,
            onPressed: () => _menuPressed(controller),
            outlineButton: preferOutlinedMenuAnchorButton(),
            filledTonalButton: !preferOutlinedMenuAnchorButton(),
            child: _menuButton(controller),
          );
        }
        return _menuButton(controller);
      },
      initialValue: _selectedIndex,
      menuItems: menuItems,
    );
  }
}
