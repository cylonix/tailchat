// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'dart:async';

import 'package:flutter/material.dart';
import '../../gen/l10n/app_localizations.dart';
import '../../models/api/status.dart';
import '../../utils/global.dart';
import '../../utils/utils.dart';

class ConfigSwitch extends StatefulWidget {
  final Widget Function(
    BuildContext context,
    bool value,
    void Function(bool) onSet,
  ) builder;
  final String errAlertPrefix;
  final bool? initialValue;
  final void Function(bool)? onBeginningChange;
  final void Function(bool)? onCompletingChange;
  final Future<bool> Function(bool)? toSave;
  final Future<Status> Function(bool)? toSet;

  const ConfigSwitch({
    super.key,
    required this.builder,
    required this.errAlertPrefix,
    this.onBeginningChange,
    this.onCompletingChange,
    this.initialValue,
    this.toSave,
    this.toSet,
  });

  @override
  State<ConfigSwitch> createState() => _ConfigSwitchState();
}

class _ConfigSwitchState extends State<ConfigSwitch> {
  bool _value = false;

  @override
  void initState() {
    super.initState();
    _value = widget.initialValue ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, _value, _onSet);
  }

  void _onSet(bool value) async {
    final tr = AppLocalizations.of(context);
    widget.onBeginningChange?.call(value);
    try {
      final status = await widget.toSet?.call(value) ?? Status.ok;
      if (!status.success) {
        throw status.error(context.mounted ? context : null) ?? "";
      }
      final result = await widget.toSave?.call(value) ?? true;
      if (!result) {
        throw tr.failedToSaveChangeText;
      }
      setState(() {
        _value = value;
      });
    } catch (e) {
      final msg = "${widget.errAlertPrefix}: $e";
      Global.logger.e(msg);
      if (mounted) {
        await showAlertDialog(
          context,
          tr.alertErrorMessage,
          msg,
          showCancel: false,
        );
      }
    }
    widget.onCompletingChange?.call(value);
  }
}
