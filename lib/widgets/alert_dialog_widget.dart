// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'package:flutter/material.dart';
import '../models/alert.dart';
import '../utils/utils.dart';
import 'dialog_action.dart';

class Content {
  final String content;
  final TextStyle? style;

  Content({
    required this.content,
    this.style,
  });
}

/// A dialog that returns a bool result
class AlertDialogWidget extends StatelessWidget {
  final String title;
  final TextStyle? titleStyle;
  final List<Content> contents;
  final List<AlertAction> actions;
  final Widget? child;

  const AlertDialogWidget({
    super.key,
    required this.title,
    required this.actions,
    this.titleStyle,
    this.contents = const [],
    this.child,
  });

  Future<bool?> show(BuildContext context) async {
    return showDialog<bool>(
      barrierDismissible: false,
      context: context,
      builder: (BuildContext context) => this,
    );
  }

  Widget _buildContent(BuildContext context) {
    final v = Column(
      mainAxisSize: MainAxisSize.min,
      spacing: 4,
      children: [
        if (!isApple()) const SizedBox(width: 300, height: 4),
        if (contents.isNotEmpty)
          ...contents.map(
            (c) => Text(
              c.content,
              style: c.style,
              textAlign: TextAlign.center,
            ),
          ),
        if (child != null) child!,
        if (!isApple()) const SizedBox(width: 300, height: 4),
      ],
    );
    return isApple() ? v : Padding(padding: const EdgeInsets.all(8), child: v);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog.adaptive(
      key: key,
      title: Text(title, textAlign: TextAlign.center, style: titleStyle),
      contentPadding: const EdgeInsets.only(bottom: 4),
      content: Material(
        type: MaterialType.transparency,
        child: SingleChildScrollView(
          controller: ScrollController(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (!isApple()) const Divider(height: 1),
              if (contents.isNotEmpty || child != null) _buildContent(context),
            ],
          ),
        ),
      ),
      actionsAlignment: MainAxisAlignment.spaceEvenly,
      actions: actions
          .map(
            (a) => DialogAction(
              onPressed: a.onPressed,
              isDefault: a.isDefault,
              isDestructive: a.destructive,
              child: Text(
                a.title,
                style: !isApple() && a.destructive
                    ? TextStyle(color: Colors.red)
                    : null,
              ),
            ),
          )
          .toList(),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16.0)),
      ),
    );
  }
}
