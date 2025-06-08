// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:pull_down_button/pull_down_button.dart';
import '../models/alert.dart';
import '../utils/utils.dart';

class AlertChip extends Card {
  AlertChip(
    Alert alert, {
    super.key,
    Function()? onDeleted,
    Color? backgroundColor,
    double? fontSize,
    double? width,
    EdgeInsetsGeometry? margin,
  }) : super(
          margin: margin ?? EdgeInsets.all(0),
          color: backgroundColor ?? alert.background,
          child: Builder(
            builder: (context) {
              final text = Text(
                alert.text,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: alert.color,
                  fontSize: fontSize,
                ),
                maxLines: 100,
                overflow: TextOverflow.visible,
              );
              final title = width == null
                  ? text
                  : SizedBox(
                      width: width,
                      child: text,
                    );
              final trailing = onDeleted != null
                  ? IconButton(
                      icon: Icon(
                        isApple() ? CupertinoIcons.delete : Icons.delete,
                      ),
                      onPressed: onDeleted,
                    )
                  : null;
              List<Widget> actions = [];
              List<PullDownMenuEntry> appleActions = [];
              if (isApple()) {
                for (var a in alert.actions) {
                  appleActions.add(PullDownMenuItem(
                    onTap: a.onPressed,
                    title: a.title,
                    icon: a.icon,
                    isDestructive: a.destructive,
                  ));
                  if (a.destructive) {
                    appleActions.add(PullDownMenuDivider.large());
                  }
                }
              } else {
                actions = alert.actions
                    .map(
                      (a) => TextButton.icon(
                        onPressed: a.onPressed,
                        label: Text(
                          a.title,
                          style: a.destructive
                              ? TextStyle(color: Colors.red)
                              : null,
                        ),
                        icon: Icon(a.icon),
                      ),
                    )
                    .toList();
              }
              if (appleActions.isNotEmpty) {
                return PullDownButton(
                  itemBuilder: (c) => appleActions,
                  buttonAnchor: PullDownMenuAnchor.center,
                  buttonBuilder: (context, showMenu) => CupertinoButton(
                    onPressed: showMenu,
                    child: Tooltip(
                      message: "Show options",
                      child: CupertinoListTile(
                        leading: alert.avatar,
                        title: title,
                        trailing: const Icon(
                          CupertinoIcons.chevron_down_circle,
                        ),
                      ),
                    ),
                  ),
                );
              }
              if (actions.isNotEmpty) {
                return ExpansionTile(
                  leading: alert.avatar,
                  title: title,
                  children: actions,
                );
              }
              return isApple()
                  ? CupertinoListTile(
                      leading: alert.avatar,
                      title: title,
                      trailing: trailing,
                    )
                  : ListTile(
                      leading: alert.avatar,
                      title: title,
                      trailing: trailing,
                    );
            },
          ),
        );
}
