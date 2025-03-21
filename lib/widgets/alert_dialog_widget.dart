// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'package:flutter/cupertino.dart';
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
class AlertDialogWidget extends StatefulWidget {
  final String title;
  final TextStyle? titleStyle;
  final List<Content> contents;
  final String? contentsTitle;
  final bool contentsExpanded;
  final List<AlertAction> actions;
  final Widget? child;

  const AlertDialogWidget({
    super.key,
    required this.title,
    required this.actions,
    this.titleStyle,
    this.contents = const [],
    this.contentsTitle,
    this.contentsExpanded = true,
    this.child,
  });

  Future<bool?> show(BuildContext context) async {
    return showDialog<bool>(
      barrierDismissible: false,
      context: context,
      builder: (BuildContext context) => this,
    );
  }

  @override
  State<AlertDialogWidget> createState() => _AlertDialogWidgetState();
}

class _AlertDialogWidgetState extends State<AlertDialogWidget> {
  final ScrollController _scrollController = ScrollController();
  bool _expanded = true;

  @override
  void initState() {
    super.initState();
    _expanded = widget.contentsExpanded;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Widget _buildContent(BuildContext context) {
    final v = _expanded
        ? Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 4,
            children: [
              if (!isApple()) const SizedBox(width: 300, height: 4),
              if (widget.contents.isNotEmpty)
                ...widget.contents.map(
                  (c) => Text(
                    c.content,
                    style: c.style,
                    textAlign: TextAlign.center,
                  ),
                ),
              if (widget.child != null) widget.child!,
              if (!isApple()) const SizedBox(width: 300, height: 4),
            ],
          )
        : Padding(
            padding: const EdgeInsets.only(top: 16),
            child: TextButton(
              onPressed: () {
                setState(() {
                  _expanded = true;
                });
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                spacing: 16,
                children: [
                  Text(
                    widget.contentsTitle ?? "Show more",
                    style: TextStyle(
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  const Icon(CupertinoIcons.chevron_down),
                ],
              ),
            ),
          );

    return isApple() ? v : Padding(padding: const EdgeInsets.all(8), child: v);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog.adaptive(
      key: widget.key,
      title: Text(
        widget.title,
        textAlign: TextAlign.center,
        style: widget.titleStyle,
      ),
      contentPadding: const EdgeInsets.only(bottom: 4),
      content: Material(
        type: MaterialType.transparency,
        child: SingleChildScrollView(
          controller: _scrollController,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (!isApple()) const Divider(height: 1),
              if (widget.contents.isNotEmpty || widget.child != null)
                _buildContent(context),
            ],
          ),
        ),
      ),
      actionsAlignment: MainAxisAlignment.spaceEvenly,
      actions: widget.actions
          .map(
            (a) => DialogAction(
              onPressed: a.onPressed,
              isDefault: a.isDefault,
              isDestructive: a.destructive,
              child: Text(
                a.title,
                textAlign: TextAlign.center,
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
