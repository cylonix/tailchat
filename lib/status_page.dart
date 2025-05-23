// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:tailchat/models/chat/chat_event.dart';
import 'package:tailchat/widgets/base_input/button.dart';
import 'api/chat_server.dart';
import 'api/chat_service.dart';
import 'gen/l10n/app_localizations.dart';
import 'models/alert.dart';
import 'utils/logger.dart';
import 'utils/utils.dart';
import 'widgets/alert_chip.dart';
import 'widgets/common_widgets.dart';
import 'widgets/main_app_bar.dart';

class StatusPage extends StatefulWidget {
  const StatusPage({super.key});
  @override
  State<StatusPage> createState() => _StatusPageState();
}

class _StatusPageState extends State<StatusPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey();
  StreamSubscription<ChatServiceStateEvent>? _chatServiceSub;
  StreamSubscription<ChatReceiveNetworkAvailableEvent>? _networkStateSub;
  bool _isConnecting = false;
  Alert? _alert;
  static const _logger = Logger(tag: "StatusPage");

  @override
  void initState() {
    super.initState();
    _chatServiceSub =
        ChatService.eventBus.on<ChatServiceStateEvent>().listen((event) {
      _logger.d(
        "Chat serivice event: err=${event.error} state=${event.state} "
        "device_id=${event.deviceID} isSelf=${event.isSelfDevice}",
      );
      if (event.isSelfDevice) {
        if (mounted) {
          setState(() {
            if (event.error != null ||
                event.state == ChatServiceState.connected ||
                event.state == ChatServiceState.disconnected) {
              _isConnecting = false;
              if (event.error != null) {
                _alert = Alert(event.error!);
              } else {
                _alert = null;
              }
            }
          });
        }
      }
    });
    _networkStateSub = ChatServer.getChatEventBus()
        .on<ChatReceiveNetworkAvailableEvent>()
        .listen((event) {
      if (mounted) {
        setState(() {
          // Update UI.
        });
      }
    });
  }

  @override
  void dispose() {
    _chatServiceSub?.cancel();
    _networkStateSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tr = AppLocalizations.of(context);
    return Scaffold(
      key: _scaffoldKey,
      appBar: MainAppBar(
        titleWidget: Text(tr.statusTitle),
      ),
      body: Center(
        child: Column(
          spacing: 32,
          children: [
            const SizedBox(height: 32),
            if (_alert != null)
              AlertChip(
                _alert!,
                onDeleted: () {
                  setState(() {
                    _alert = null;
                  });
                },
              ),
            ChatServer.isNetworkAvailable
                ? const Text(
                    "Network is vailable",
                    style: TextStyle(color: Colors.green),
                  )
                : const Text(
                    "Network is not available.",
                    style: TextStyle(color: Colors.red),
                  ),
            Card(
              child: Container(
                constraints: BoxConstraints(
                  minWidth: isMediumScreen(context) ? 600 : 360,
                  minHeight: 200,
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const SizedBox(height: 32),
                    ChatServer.isServiceSocketConnected
                        ? const Text(
                            "Chat service monitoring is connected",
                            style: TextStyle(color: Colors.green),
                          )
                        : const Text(
                            "Chat service montoring is disconnected.",
                            style: TextStyle(color: Colors.red),
                          ),
                    const SizedBox(height: 32),
                    if (_isConnecting) loadingWidget(),
                    if (!_isConnecting)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        spacing: 16,
                        children: [
                          if (!ChatServer.isServiceSocketConnected)
                            BaseInputButton(
                              shrinkWrap: true,
                              onPressed: () async {
                                setState(() {
                                  _isConnecting = true;
                                });
                                try {
                                  await ChatServer.startServiceStateMonitor(
                                    _onChatServiceError,
                                  );
                                  await ChatServer.subscribeToMessages(
                                    _onChatServiceError,
                                  );
                                } catch (e) {
                                  _logger.e(
                                      "Failed to connect to chat service: $e");
                                  setState(() {
                                    _isConnecting = false;
                                    _alert = Alert(e.toString());
                                  });
                                }
                              },
                              child: const Text("Connect"),
                            ),
                          BaseInputButton(
                            shrinkWrap: true,
                            onPressed: () async {
                              setState(() {
                                _isConnecting = true;
                              });
                              await ChatServer.restartServer();
                            },
                            child: const Text("Restart"),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onChatServiceError(dynamic error) {
    _logger.e("Chat service error: $error");
    if (mounted) {
      setState(() {
        _alert = Alert("Chat service error: $error");
      });
    }
  }
}
