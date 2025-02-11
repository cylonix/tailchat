// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'package:flutter/material.dart';
import '../../utils/utils.dart';
import '../common_widgets.dart';

class MenuItem {
  final Widget child;
  final Widget? leadingIcon;
  final void Function() onPressed;
  const MenuItem({
    required this.child,
    this.leadingIcon,
    required this.onPressed,
  });
}

/// Choose between MenuAnchor and PopupMenuButton depending on the preference.
class MenuButtonWidget extends StatefulWidget {
  final Widget Function(
    BuildContext context,
    MenuController? controller,
    Widget? child,
  ) builder;
  final bool highlightSelected;
  final int? initialValue;
  final List<MenuItem> menuItems;
  final bool Function(int index)? isSelected;
  const MenuButtonWidget({
    super.key,
    required this.builder,
    this.highlightSelected = true,
    this.initialValue,
    this.isSelected,
    required this.menuItems,
  });

  @override
  State<MenuButtonWidget> createState() => _MenuButtonWidgetState();
}

class _MenuButtonWidgetState extends State<MenuButtonWidget> {
  int? _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialValue;
  }

  @override
  Widget build(BuildContext context) {
    final menuChildren = <Widget>[];
    if (preferPopupMenuButton()) {
      return _popupMenuButton;
    }
    for (var i = 0; i < widget.menuItems.length; i++) {
      final item = widget.menuItems[i];
      final selected = widget.isSelected != null
          ? widget.isSelected!.call(i)
          : (widget.highlightSelected && _selectedIndex == i);
      menuChildren.add(
        MenuItemButton(
          onPressed: () {
            setState(() {
              _selectedIndex = i;
            });
            item.onPressed.call();
          },
          leadingIcon: item.leadingIcon,
          trailingIcon: selected
              ? const Icon(
                  Icons.check,
                  size: 16,
                )
              : null,
          child: item.child,
        ),
      );
    }
    return MenuAnchor(
      builder: (context, controller, child) => widget.builder(
        context,
        controller,
        child,
      ),
      alignmentOffset: const Offset(20, 0),
      menuChildren: menuChildren,
    );
  }

  TapDownDetails? _d;
  Widget get _popupMenuButton {
    final menuChildren = <PopupMenuItem<int>>[];
    for (var i = 0; i < widget.menuItems.length; i++) {
      final item = widget.menuItems[i];
      final selected = widget.isSelected != null
          ? widget.isSelected!.call(i)
          : (widget.highlightSelected && _selectedIndex == i);
      menuChildren.add(
        PopupMenuItem<int>(
          value: i,
          child: preferPopupMenuItemExpanded()
              ? ListTile(
                  selected: selected,
                  title: Row(
                    mainAxisSize: MainAxisSize.max,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      item.child,
                      if (selected) const SizedBox(width: 8),
                      if (selected) const Icon(Icons.check),
                    ],
                  ),
                )
              : item.child,
          onTap: () {
            setState(() {
              _selectedIndex = i;
            });
            item.onPressed.call();
          },
        ),
      );
    }
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        focusColor: focusColor(context),
        customBorder: commonShapeBorder(),
        onTapDown: (details) => _d = details,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: widget.builder(context, null, null),
        ),
        onTap: () {
          showMenu(
            constraints: preferPopupMenuItemExpanded()
                ? const BoxConstraints(minWidth: double.infinity)
                : null,
            context: context,
            position: getShowMenuPosition(
              context,
              _d?.globalPosition,
              offset: getPopupMenuOffset(),
            )!,
            initialValue:
                preferPopupMenuItemExpanded() || !widget.highlightSelected
                    ? null
                    : _selectedIndex,
            items: menuChildren,
            shape: commonShapeBorder(),
          );
        },
      ),
    );
  }
}
