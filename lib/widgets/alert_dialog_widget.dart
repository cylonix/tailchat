// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'package:flutter/material.dart';
import '../utils/utils.dart';
import 'dialog_action.dart';

class Action {
  final String title;
  final void Function() onPressed;

  Action({
    required this.title,
    required this.onPressed,
  });
}

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
  final List<Content> contents;
  final List<Action> actions;
  final Widget? child;

  const AlertDialogWidget({
    super.key,
    required this.title,
    required this.contents,
    required this.actions,
    this.child,
  });

  Future<bool?> show(BuildContext context) async {
    return showDialog<bool>(
      barrierDismissible: false,
      context: context,
      builder: (BuildContext context) => this,
    );
  }

  Widget _action({required Widget child, required void Function() onPressed}) {
    return DialogAction(onPressed: onPressed, child: child);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog.adaptive(
      key: key,
      title: Text(title, textAlign: TextAlign.center),
      contentPadding: const EdgeInsets.only(bottom: 8),
      content: Material(
        type: MaterialType.transparency,
        child: SingleChildScrollView(
          controller: ScrollController(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (!isApple()) const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 8,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 4,
                  children: [
                    ...contents.map((c) => Text(c.content, style: c.style)),
                    if (child != null) child!,
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: actions
          .map(
            (a) => _action(
              child: Text(a.title, textAlign: TextAlign.center),
              onPressed: a.onPressed,
            ),
          )
          .toList(),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(32.0)),
      ),
    );
  }
}
