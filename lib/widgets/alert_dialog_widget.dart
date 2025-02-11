// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'package:flutter/material.dart';
import '../gen/l10n/app_localizations.dart';
import '../utils/utils.dart';
import 'dialog_action.dart';

/// A dialog that returns a bool result
class AlertDialogWidget extends StatelessWidget {
  final String title;
  final String? content;
  final String? additionalAskTitle;
  final String? successSubtitle;
  final String? successMsg;
  final String? failureSubtitle;
  final String? failureMsg;
  final Widget? otherActions;
  final String? okText;
  final String? cancelText;
  final void Function()? onAdditionalAskPressed;
  final void Function()? onCancel;
  final void Function()? onOK;
  final bool showOK;

  const AlertDialogWidget({
    required this.title,
    this.content,
    super.key,
    this.additionalAskTitle,
    this.otherActions,
    this.successSubtitle,
    this.successMsg,
    this.failureSubtitle,
    this.failureMsg,
    this.cancelText,
    this.okText,
    this.onAdditionalAskPressed,
    this.onCancel,
    this.onOK,
    this.showOK = true,
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
    final tr = AppLocalizations.of(context);
    const red = TextStyle(color: Colors.red);
    const green = TextStyle(color: Colors.green);

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
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 16,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (content != null) Text(content!),
                    if (successMsg != null) const SizedBox(height: 8),
                    if (successSubtitle != null) Text(successSubtitle!),
                    if (successMsg != null) Text(successMsg!, style: green),
                    if (failureMsg != null) const SizedBox(height: 8),
                    if (failureSubtitle != null) Text(failureSubtitle!),
                    if (failureMsg != null) Text(failureMsg!, style: red),
                    if (otherActions != null) const SizedBox(height: 8),
                    if (otherActions != null) otherActions!,
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        if (additionalAskTitle != null)
          _action(
            child: Text(additionalAskTitle!, textAlign: TextAlign.center),
            onPressed: () {
              onAdditionalAskPressed?.call();
              Navigator.of(context).pop(true);
            },
          ),
        if (onCancel != null)
          _action(
            child: Text(
              cancelText ?? tr.cancelButton,
              textAlign: TextAlign.center,
            ),
            onPressed: () => Navigator.of(context).pop(false),
          ),
        if (showOK)
          _action(
            //autofocus: true,
            child: Text(okText ?? tr.ok, textAlign: TextAlign.center),
            onPressed: () {
              Navigator.of(context).pop(true);
              onOK?.call();
            },
          ),
      ],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(32.0)),
      ),
    );
  }
}
