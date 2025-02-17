// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../api/chat_service.dart';
import '../api/config.dart';
import '../gen/l10n/app_localizations.dart';
import '../models/chat/chat_event.dart';
import '../status_page.dart';
import '../utils/logger.dart';
import 'common_widgets.dart';
import 'tv/icon_button.dart';

class StatusWidget extends StatefulWidget {
  final bool compact;
  final IconData? icon;
  final void Function()? onPressed;
  final double? size;
  const StatusWidget({
    super.key,
    this.compact = false,
    this.icon,
    this.onPressed,
    this.size,
  });

  @override
  State<StatusWidget> createState() => _StatusWidgetState();
}

class _StatusWidgetState extends State<StatusWidget> {
  static final _logger = Logger(tag: "StatusWidget");
  StreamSubscription<ChatServiceStateEvent>? _serviceStateSub;
  ChatServiceState _serviceState = ChatServiceState.disconnected;

  @override
  void initState() {
    super.initState();
    if (Pst.selfDevice?.isOnline ?? false) {
      _serviceState = ChatServiceState.connected;
    }
    _registerServiceStateEvent();
  }

  @override
  void dispose() {
    _serviceStateSub?.cancel();
    super.dispose();
  }

  void _registerServiceStateEvent() {
    final eventBus = ChatService.eventBus;
    _serviceStateSub = eventBus.on<ChatServiceStateEvent>().listen((event) {
      if (event.deviceID == null) {
        _logger.i("update service state to ${event.state.name}");
        setState(() {
          _serviceState = event.state;
        });
      }
    });
  }

  void _showStatusPage() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const StatusPage()),
    );
  }

  Color get _color {
    switch (_serviceState) {
      case ChatServiceState.connected:
        return Colors.green;
      case ChatServiceState.connecting:
        return Colors.yellow;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tr = AppLocalizations.of(context);

    if (widget.compact) {
      return IconButtonWidget(
        tooltip: tr.statusTitle,
        icon: Icon(
          widget.icon ?? Icons.connect_without_contact,
          color: _color,
        ),
        onPressed: widget.onPressed ?? _showStatusPage,
        size: widget.size,
      );
    }

    return ListTile(
      leading: getIcon(widget.icon ?? Icons.connect_without_contact,
          color: _color, appleBackgroundColor: CupertinoColors.systemGrey4),
      title: Text(tr.statusTitle),
      onTap: widget.onPressed ?? _showStatusPage,
    );
  }
}
