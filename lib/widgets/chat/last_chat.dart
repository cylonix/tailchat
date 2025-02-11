// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

// Widget that reacts to the latest chat of the chat session

import 'dart:async';

import 'package:cylonix_emojis/cylonix_emojis.dart' show lookupByCode;
import 'package:flutter/material.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;

import '../../api/chat_server.dart';
import '../../api/config.dart';
import '../../gen/l10n/app_localizations.dart';
import '../../models/chat/chat_event.dart';
import '../../models/chat/chat_session.dart';
import '../../models/session_storage.dart';
import '../../utils/global.dart';
import '../../utils/utils.dart';

class LastChat extends StatefulWidget {
  final ChatSession session;
  final void Function() onUpdate;

  const LastChat({
    super.key,
    required this.session,
    required this.onUpdate,
  });

  @override
  State<LastChat> createState() => _LastChatState();
}

class _LastChatState extends State<LastChat> {
  StreamSubscription<ChatEvent>? _chatSub;
  bool _fromMe = false;
  late bool _isGroupChat;
  late String _chatID, _messageSummary;

  @override
  void initState() {
    super.initState();
    _chatID = widget.session.sessionID;
    _isGroupChat = (widget.session.groupName != null);
    _messageSummary = widget.session.lastChat ?? "";
    _registerChatEventCallback();
  }

  @override
  void dispose() {
    _chatSub?.cancel();
    super.dispose();
  }

  void _registerChatEventCallback() {
    final eventBus = ChatServer.getChatEventBus();
    _chatSub = eventBus.on<ChatEvent>().listen((chatEvent) {
      _handleChatEvent(chatEvent);
    });
  }

  void _updateSession(String messageSummary) {
    widget.session.lastChat = messageSummary;
    widget.session.lastChatTime = DateTime.now();
    try {
      final userID = Pst.selfUser!.id;
      final storage = SessionStorage(userID: userID);
      storage.updateSession(widget.session);
    } catch (e) {
      Global.logger.e("failed to save updated session info $e");
    }
  }

  void _handleChatEvent(ChatEvent event) {
    //Global.logger.d("chat event: id ${event.chatID} my $_chatID");
    if (event.chatID != _chatID) {
      return;
    }
    final message = event.message;
    var messageSummary = message.summary;
    if (_isGroupChat) {
      final username = message.author.firstName;
      messageSummary = "$username: $messageSummary";
    }

    if (message is types.CustomMessage) {
      final meta = message.metadata;
      if (meta != null && meta['sub_type'] == "Video Call") {
        String? server = meta['server'];
        final room = meta['room'];
        if (server != null && room != null) {
          server = server.protocolPrefixRemoved();
          messageSummary = 'VideoCall: $server/$room';
        }
      }
    }

    _updateSession(messageSummary);
    setState(() {
      _fromMe = event.message.author.id == widget.session.selfUserID;
      _messageSummary = messageSummary;
    });
    widget.onUpdate();
  }

  @override
  Widget build(BuildContext context) {
    if (_messageSummary.startsWith('Emoji: ')) {
      final messageSummary = _messageSummary..replaceFirst("Emoji: ", "");
      return Row(
        children: messageSummary.codeUnits.map((e) {
          final asset = lookupByCode(e)?.assetPath;
          return asset == null
              ? const SizedBox()
              : Image.asset(asset, width: 16);
        }).toList(),
      );
    }
    final tr = AppLocalizations.of(context);
    var messageSummary = _messageSummary.replaceFirst("File:", tr.file);
    messageSummary = messageSummary.replaceFirst("Image:", tr.photo);
    messageSummary = messageSummary.replaceFirst(
      "VideoCall:",
      tr.videoMeetingText,
    );
    if (messageSummary.startsWith("Delete: ")) {
      messageSummary = messageSummary.replaceFirst(
        "Delete: ",
        _fromMe ? tr.recallText : tr.deleteText,
      );
    }
    if (messageSummary.startsWith("Delete all: ")) {
      messageSummary = _fromMe
          ? tr.deleteAllChatMessagesText
          : messageSummary.replaceFirst(
              "Delete all: ",
              tr.deleteAllChatMessagesText,
            );
    }
    return Text(messageSummary, style: smallTextStyle(context));
  }
}
