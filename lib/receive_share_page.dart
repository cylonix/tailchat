// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'dart:io';

// Please keep the imports in alphabetic order
import 'package:flutter/material.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import 'api/config.dart';
import 'gen/l10n/app_localizations.dart';
import 'models/chat/chat_id.dart';
import 'models/chat/chat_session.dart';
import 'models/session.dart';
import 'models/session_storage.dart';
import 'utils/logger.dart';
import 'utils/utils.dart' as utils;
import 'widgets/add_session_widget.dart';
import 'widgets/main_app_bar.dart';
import 'widgets/main_drawer.dart';
import 'widgets/search_widget.dart';
import 'widgets/session_list.dart';
import 'widgets/share_preview.dart';

class ReceiveSharePage extends StatefulWidget {
  final List<SharedMediaFile>? files;
  final List<types.Message>? messages;
  final bool showDrawer;
  final bool showSideBySide;
  const ReceiveSharePage({
    super.key,
    this.files,
    this.messages,
    this.showDrawer = false,
    this.showSideBySide = false,
  });

  @override
  State<ReceiveSharePage> createState() => _State();
}

class _State extends State<ReceiveSharePage> {
  final _scaffoldKey = GlobalKey();
  final _sessions = <ChatSession>[];
  final _sessionsMap = <String, Session?>{};
  String? _filterText;
  static const String _tag = "Share";
  late final Logger _logger;

  @override
  void initState() {
    super.initState();
    _logger = Logger(tag: _tag);
    _loadSessions();
  }

  @override
  Widget build(BuildContext context) {
    return _buildUi(context);
  }

  void _loadSessions() async {
    final userID = Pst.selfUser?.id;
    if (userID == null) {
      _logger.d("user not yet logged in");
      return;
    }
    final storage = SessionStorage(userID: userID);
    storage.readSessions().then((sessions) {
      for (var session in sessions) {
        if (session is ChatSession) {
          _sessions.add(session);
          _sessionsMap[session.sessionID] = session;
        }
      }
      _logger.d("chat sessions: ${_sessions.length}");
      if (_sessions.isNotEmpty) {
        setState(() {});
      }
    });
  }

  void _handleOnSelectSession(int index, Session session) {
    if (session is ChatSession) {
      _shareWithSession(session);
    }
  }

  void _shareWithSession(ChatSession session) {
    var paths = <String>[];
    final files = widget.files;
    String? text;
    if (files != null) {
      for (var element in files) {
        switch (element.type) {
          case SharedMediaType.file:
            var path = element.path;
            if (Platform.isIOS && element.type == SharedMediaType.file) {
              path = path.replaceAll(utils.replaceableText, "");
            }
            paths.add(path);
            break;
          case SharedMediaType.text:
            text = element.path;
            break;
          case SharedMediaType.image:
            paths.add(element.path);
            break;
          case SharedMediaType.video:
            paths.add(element.path);
            break;
          case SharedMediaType.url:
            text = element.path;
            // TODO: handle url correctly.
            break;
        }
      }
    }
    Navigator.pop(context);
    Navigator.of(context).push(MaterialPageRoute(
      builder: (context) => SharingMediaPreviewScreen(
        session: session,
        paths: paths,
        messages: widget.messages,
        text: text,
        showSideBySide: widget.showSideBySide,
      ),
    ));
  }

  void _onSearchTextChanged(String text) {
    setState(() {
      _filterText = text;
    });
  }

  String? _validateGroupName(String groupName) {
    final sessionID = ChatID.fromGroupName(groupName).id;
    final oldSession = _sessionsMap[sessionID];
    if (oldSession != null) {
      return "Group $groupName already exits";
    }
    return null;
  }

  void _newChat(ChatSession newSession) {
    _shareWithSession(newSession);
  }

  Widget _buildUi(BuildContext context) {
    final tr = AppLocalizations.of(context);
    final title = tr.chooseChatTitle;
    _logger.d("Receiving share page: sessions[${_sessions.length}]");

    return Scaffold(
      key: _scaffoldKey,
      appBar: MainAppBar(title: title),
      drawer: widget.showDrawer ? const MainDrawer() : null,
      body: ListView(
        controller: ScrollController(),
        shrinkWrap: true,
        children: [
          SearchWidget(
            hintText: tr.searchHintText,
            onSearchChanged: _onSearchTextChanged,
            onSearchCleared: () => _onSearchTextChanged(''),
          ),
          ListTile(
            leading: Text(tr.recentChatsText),
            trailing: AddSessionWidget(
              onNewChat: _newChat,
              validateGroupName: _validateGroupName,
              showAsLeftSide: false,
            ),
          ),
          SessionList(
            itemSelectedCallback: _handleOnSelectSession,
            sessions: _sessions,
            filterText: _filterText,
            showPopUpMenuOnLongPressed: false,
          ),
        ],
      ),
    );
  }
}
