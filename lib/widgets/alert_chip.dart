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
    List<Widget>? actions,
    List<PullDownMenuEntry>? appleActions,
  }) : super(
          margin: EdgeInsets.all(0),
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
              if (appleActions != null) {
                return PullDownButton(
                  itemBuilder: (c) => appleActions,
                  buttonAnchor: PullDownMenuAnchor.center,
                  buttonBuilder: (context, showMenu) => CupertinoButton(
                    onPressed: showMenu,
                    child: Tooltip(
                      message: "Click to show action options",
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
              if (actions != null) {
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
