// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

// Sessions page list the chat, connection sessions et al.
import 'dart:async';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:provider/provider.dart';

import 'api/chat_server.dart';
import 'api/config.dart';
import 'api/contacts.dart';
import 'api/send_chat.dart';
import 'widgets/chat/chat_page.dart';
import 'gen/l10n/app_localizations.dart';
import 'models/chat/chat_id.dart';
import 'models/chat/chat_event.dart';
import 'models/chat/chat_message.dart';
import 'models/chat/chat_session.dart';
import 'models/chat/chat_storage.dart';
import 'models/config/config_change_event.dart';
import 'models/contacts/contact.dart';
import 'models/delete_session_notifier.dart';
import 'models/new_session_notifier.dart';
import 'models/contacts/device.dart';
import 'models/session.dart';
import 'models/session_event.dart';
import 'models/session_storage.dart';
import 'models/contacts/user_profile.dart';
import 'utils/global.dart';
import 'utils/logger.dart';
import 'utils/utils.dart';
import 'widgets/add_session_widget.dart';
import 'widgets/common_widgets.dart';
import 'widgets/main_app_bar.dart';
import 'widgets/main_drawer.dart';
import 'widgets/main_bottom_bar.dart';
import 'widgets/search_widget.dart';
import 'widgets/session_list.dart';
import 'widgets/slider.dart';
import 'widgets/snackbar_widget.dart';
import 'widgets/stack_with.dart';
import 'widgets/status_widget.dart';
import 'widgets/tv/background.dart';
import 'widgets/tv/end_drawer_button.dart' as tv;
import 'widgets/tv/icon_button.dart';

class SessionsPage extends StatefulWidget {
  final bool showDrawer;
  final bool enableScroll;
  final bool Function(Session s)? sessionFilter;
  const SessionsPage({
    super.key,
    this.showDrawer = true,
    this.enableScroll = true,
    this.sessionFilter,
  });
  @override
  SessionsPageState createState() => SessionsPageState();
}

class SessionsPageState extends State<SessionsPage>
    with AutomaticKeepAliveClientMixin, RouteAware {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey();
  StreamSubscription<ChatReceiveEvent>? _chatReceiveSub;
  StreamSubscription<ChatReceiveRoomEvent>? _chatRxRoomSub;
  StreamSubscription<ConfigChangeEvent>? _configSub;
  StreamSubscription<ContactsEvent>? _contactSub;
  StreamSubscription<SessionEvent>? _sessionEventSub;
  SessionStorage? _storage;
  SessionType _selectedSessionType = SessionType.chat;
  Session? _selectedItem;
  final Map<SessionType, Session?> _selectedItemMap = {};
  String? _userID;
  String? _filterText;
  bool isLoading = false;
  bool _isTV = Pst.enableTV ?? false;
  bool _selectToEdit = false;
  final sessions = <Session>[];
  final sessionsMap = <String, Session?>{};
  final _deviceSessions = <Session>[];
  final _otherSessions = <Session>[];
  static const _defaultFlex = 30;
  int _flex = _defaultFlex;
  String get logTag => "sessions";
  late final Logger _logger;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    _logger = Logger(tag: logTag);
    super.initState();

    _registerConfigChangeEvent();
    _registerToDeleteSessionNotifier();
    _registerToNewSessionNotifier();
    _registerToSessionEvent();
    _registerChatServerEvent();
    _registerContactsEvent();
  }

  @override
  void dispose() {
    _logger.d("$logTag: disposing sessions page");
    _chatReceiveSub?.cancel();
    _chatRxRoomSub?.cancel();
    _configSub?.cancel();
    _contactSub?.cancel();
    _sessionEventSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    Global.routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void didPush() {
    _logger.d("SessionsPageState did push");
  }

  void _registerConfigChangeEvent() {
    if (Pst.configLoaded) {
      _initStorage();
      _handleEnableTVEvent();
    }
    _configSub = Pst.eventBus.on<ConfigChangeEvent>().listen((event) {
      if (!mounted) {
        return;
      }
      if (event is ConfigLoadedEvent) {
        _initStorage();
        _handleEnableTVEvent();
        return;
      }
      if (event is EnableTVEvent) {
        _handleEnableTVEvent();
        return;
      }
    });
  }

  void _handleEnableTVEvent() {
    final isTV = Pst.enableTV ?? false;
    if (_isTV == isTV) {
      return;
    }
    setState(() {
      _isTV = isTV;
    });
  }

  void _registerContactsEvent() {
    _contactSub = contactsEventBus.on<ContactsEvent>().listen((onData) async {
      final device = onData.device;
      _logger.d("contacts event: $onData");
      if ((onData.eventType == ContactsEventType.updateDevice ||
              onData.eventType == ContactsEventType.addDevice) &&
          device != null) {
        final idx = sessions.indexWhere(
            (s) => (s is ChatSession && s.peerDeviceID == device.id));
        if (idx < 0) {
          return;
        }

        final session = sessions[idx] as ChatSession;
        final updated = session.peerIP != device.address ||
            session.peerDeviceName != device.hostname;
        if (!updated) {
          return;
        }
        session.peerDeviceName = device.hostname;
        session.peerIP = device.address;
        // No need to update UI as it is handled in the session widget.
        await _storage?.updateSession(session);
      }
    });
  }

  void _initStorage() {
    _logger.d("$logTag: init sessions storage");
    final userInfo = Pst.selfUser;
    if (userInfo != null) {
      final userID = userInfo.id;
      if (_userID != userID) {
        _userID = userID;
        _storage = SessionStorage(userID: userID);
        _logger.d("$logTag: reload sessions after user id is ready");
        _reloadSessions();
      }
    }
  }

  void _reloadSessions() {
    sessions.clear();
    _deviceSessions.clear();
    _otherSessions.clear();
    _loadSessions();
  }

  void _registerToNewSessionNotifier() {
    final notifier = context.read<NewSessionNotifier>();
    notifier.addListener(() {
      if (!mounted) {
        return;
      }
      final session = notifier.session;
      if (session != null) {
        _logger.d("new ${session.type} session: ${session.sessionID}");
        _addSession(session);
        if (mounted) {
          setState(() {
            // Trigger a rebuild with the new session
            _setSelectedItem(session.type, session);
          });
        }
      }
    });
  }

  void _registerToDeleteSessionNotifier() {
    final notifier = context.read<DeleteSessionNotifier>();
    notifier.addListener(() {
      if (!mounted) {
        return;
      }
      final session = notifier.session;
      if (session != null) {
        _logger.d("delete session: ${session.sessionID}");
        _deleteSession(null, session);
      }
    });
  }

  void _registerToSessionEvent() {
    _sessionEventSub =
        SessionStorage.eventBus.on<SessionEvent>().listen((event) {
      if (!mounted) {
        return;
      }
      if (event is SessionsSavedEvent) {
        _reloadSessions();
        return;
      }
      if (event is SessionUpdateEvent) {
        final session = event.session!;
        var updated = false;
        if (sessionsMap[session.sessionID] != null) {
          sessionsMap[session.sessionID] = session;
          final index = sessions.indexWhere(
            (e) => e.sessionID == session.sessionID,
          );
          if (index >= 0) {
            updated = true;
            sessions[index] = session;
          }
        }
        if (updated) {
          if (mounted) {
            setState(() {});
          }
        } else {
          _logger.e("Session not found in list: $session");
        }
      }
    });
  }

  void _registerChatServerEvent() {
    final eventBus = ChatServer.getChatEventBus();
    _chatReceiveSub = eventBus.on<ChatReceiveEvent>().listen((chatEvent) {
      if (!mounted) {
        return;
      }
      _handleChatReceiveEvent(chatEvent);
    });
    _chatRxRoomSub = eventBus.on<ChatReceiveRoomEvent>().listen((event) {
      if (!mounted) {
        return;
      }
      _handleChatReceiveRoomEvent(event);
    });
  }

  void _handleChatReceiveRoomEvent(ChatReceiveRoomEvent event) {
    _handleRoomReceived(event.chatID, event.room);
  }

  void _handleRoomReceived(String sessionID, types.Room? room) {
    final selfUser = _selfUserChecked;
    if (selfUser == null || room == null) {
      return;
    }
    late DateTime createdAt;
    final ms = room.createdAt;
    if (ms != null) {
      createdAt = DateTime.fromMillisecondsSinceEpoch(ms);
    } else {
      createdAt = DateTime.now();
    }
    final newSession = ChatSession(
      sessionID: sessionID,
      selfUserID: selfUser.id,
      groupName: room.name,
      createdAt: createdAt,
      status: SessionStatus.unread,
    );

    _logger.d("add new session $newSession");
    _addSession(newSession);
  }

  void _handleChatReceiveEvent(ChatReceiveEvent event) async {
    final chatID = ChatID(id: event.chatID);
    _logger.d("received chat event to ID ${event.chatID}");
    final session = sessionsMap[event.chatID];
    if (session != null) {
      // Handle delete-all from self.
      final message = event.message;
      if (message is types.DeleteMessage && message.deleteAll) {
        if (message.author.id == ChatMessage.selfToAuthor()?.id) {
          _logger.i("Delete-all from me. Delete the session.");
          final notifier = context.read<DeleteSessionNotifier>();
          notifier.add(session);
          return;
        }
      }
      // Move it to top and be done handling existing session.
      _logger.d("existing chat session. skip");
      moveSessionToTop(session);
      return;
    }
    if (chatID.isGroup) {
      var room = await ChatStorage(chatID: event.chatID).getRoom();
      if (room != null) {
        _handleRoomReceived(event.chatID, room);
        return;
      }
      final machine = event.machine;
      final peer = await getDevice(machine);
      if (peer == null) {
        final author = event.message.author;
        _logger.e("received a message from unkown user $author $machine");
        return;
      }
      room = await getRoom(event.chatID, peer);
      if (room != null) {
        await ChatStorage(chatID: event.chatID).saveRoom(room);
        _handleRoomReceived(event.chatID, room);
        return;
      }

      _logger.e("received a group chat without a session created");
      return;
    }

    final userIDs = chatID.userIDs;
    final machines = chatID.machines;
    UserProfile? user, selfUser;
    Device? peer;
    selfUser = Pst.selfUser;
    String? peerUserID, peerID;
    if (selfUser != null && userIDs != null && userIDs.length == 2) {
      peerUserID = userIDs[0];
      if (peerUserID == selfUser.id) {
        peerUserID = userIDs[1];
      }
      user = await getUser(peerUserID);
      if (machines != null && machines.length == 2) {
        final selfDevice = Pst.selfDevice;
        if (selfDevice != null) {
          peerID = machines[0];
          if (peerID == selfDevice.id) {
            peerID = machines[1];
          }
          _logger.d("Peer ID: $peerID. Self ID: ${selfDevice.id}");
          peer = await getDevice(peerID);
          if (peer == null) {
            _logger.d("Failed to get peer from storage. Try the known devices");
            peer = ChatServer.deviceList.firstWhereOrNull(
              (d) => d.id == peerID,
            );
            if (peer != null) {
              _logger.d("Found device $peer");
              peer.userID = peerUserID;
              if (user == null) {
                try {
                  final author = event.message.author;
                  await addContact(
                    Contact(
                      id: peerUserID,
                      username: "" /* FIXME */,
                      name: author.firstName,
                    ),
                  );
                } catch (e) {
                  _logger.e("Failed to add contact: $e");
                }
              }
              try {
                _logger.d("add device $peer to storage");
                await addDevice(peer);
              } catch (e) {
                _logger.e("Failed to save device");
              }
            }
          }
        }
      }
    }
    if (selfUser == null || user == null) {
      _logger.d("unknown chat ID $chatID");
      return;
    }
    _logger.d("new chat session to add $chatID");

    final newSession = ChatSession(
      sessionID: event.chatID,
      selfUserID: selfUser.id,
      peerUserID: peerUserID,
      peerDeviceID: peerID,
      peerDeviceName: peer?.hostname,
      peerIP: peer?.address,
      peerName: user.name,
      status: SessionStatus.unread,
      lastChat: event.message.summary,
      lastChatTime: DateTime.now(),
      createdAt: DateTime.now(),
    );
    _addSession(newSession);
    return;
  }

  void _loadSessions() async {
    final storage = _storage;
    if (storage == null) {
      _logger.d("session storage is null. skip loading sessions");
      return;
    }
    _logger.d("loading sessions from $storage...");
    storage.readSessions().then((sessionsRead) {
      if (!mounted) {
        _logger.d("ignored read sessions (${sessionsRead.length})");
        return;
      }
      var unread = 0;
      for (var session in sessionsRead) {
        _otherSessions.add(session);
        sessionsMap[session.sessionID] = session;
        if (session.status == SessionStatus.unread) {
          unread++;
        }
      }
      final notifier = context.read<BottomBarSessionNoticeCount>();
      notifier.set(unread);

      _logger.d("added ${sessionsRead.length} sessions");
      sessions.addAll(_deviceSessions);
      sessions.addAll(_otherSessions);
      setState(() {});
    });
  }

  void _saveSession(Session session) async {
    try {
      if (_storage == null) {
        throw ("session storage is not ready (null)");
      }
      await _storage!.writeSession(session);
      setState(() {});
    } catch (e) {
      _logger.e("failed to write to session storage: $e");
    }
  }

  void _clearSessionUnreadStatus(int index, Session session) async {
    if (session.status == SessionStatus.unread) {
      session.status = SessionStatus.read;
      sessions[index].status = SessionStatus.read;
      await _storage?.updateSession(session);
      if (!mounted) {
        return;
      }
      final notifier = context.read<BottomBarSessionNoticeCount>();
      notifier.add(-1);
      setState(() {
        // Update sessions list with the new status
      });
    }
  }

  void _setSelectedItem(SessionType type, Session? session) {
    _selectedItem = session;
    _selectedItemMap[type] = session;
  }

  void _switchToChat(ChatSession session) async {
    Future.microtask(() {
      if (!mounted) {
        return;
      }
      Navigator.of(context).pushNamed(
        '/chat/${session.sessionID}',
        arguments: session.toJson(),
      );
    });
  }

  void moveSessionToTop(Session session, {bool rebuild = true}) {
    final index = sessions.indexOf(session);
    _moveSessionToTop(index, session, rebuild: rebuild);
  }

  void _moveSessionToTop(int index, Session session,
      {bool rebuild = true}) async {
    if (index <= 0) {
      return;
    }
    _deleteSession(index, session);
    _addSession(session);
    if (rebuild) {
      setState(() {});
    }
  }

  void _switchToSession(int index, Session session) {
    _moveSessionToTop(index, session);
    _clearSessionUnreadStatus(index, session);
    _switchToChat(session as ChatSession);
  }

  void deleteSession(Session session) {
    final notifier = context.read<DeleteSessionNotifier>();
    notifier.add(session);
  }

  void _deleteSession(int? index, Session session) async {
    final sessionID = session.sessionID;
    _logger.d("session with $sessionID deleted");
    if (session.status == SessionStatus.unread) {
      final notifier = context.read<BottomBarSessionNoticeCount>();
      notifier.add(-1);
    }
    int deleteIndex = 0;
    for (var item in _otherSessions) {
      if (item.equal(session)) {
        _otherSessions.removeAt(deleteIndex);
        break;
      }
      deleteIndex++;
    }
    setState(() {
      final selected = _selectedItem;
      if (selected != null && selected.equal(session)) {
        _setSelectedItem(session.type, null);
      }
      if (index != null) {
        sessions.removeAt(index);
      } else {
        sessions.removeWhere((element) => element.equal(session));
      }
      sessionsMap[sessionID] = null;
      _logger.d("sessions is now at length: ${sessions.length}");
    });
    await _storage?.removeSession(session);
  }

  void _addSession(Session newSession) {
    // remove existing session
    Session? oldSession;
    int deleteIndex = 0;
    for (var item in _otherSessions) {
      if (item.equal(newSession)) {
        _otherSessions.removeAt(deleteIndex);
        oldSession = item;
        break;
      }
      deleteIndex++;
    }

    sessionsMap[newSession.sessionID] = newSession;
    if (oldSession != null) {
      if (newSession is ChatSession) {
        newSession == oldSession;
      }
    } else {
      if (newSession.status == SessionStatus.unread) {
        _logger.d("new session add to the notice");
        if (mounted) {
          final notifier = context.read<BottomBarSessionNoticeCount>();
          notifier.add(1);
        }
      }
      _saveSession(newSession);
    }
    // move or add the new session to the top
    _otherSessions.insert(0, newSession);
    sessions.clear();
    sessions.addAll(_deviceSessions);
    sessions.addAll(_otherSessions);
    final length = sessions.length;
    _logger.d("new session. sessions length: $length");
    _sessionTypeSelected(newSession.type);
  }

  UserProfile? get _selfUserChecked {
    final selfUser = Pst.selfUser;
    if (selfUser == null) {
      final tr = AppLocalizations.of(context);
      SnackbarWidget.e(tr.selfUserNotFoundError).show(context);
    }
    return selfUser;
  }

  Widget get _searchWidget {
    final tr = AppLocalizations.of(context);
    return SearchWidget(
      hintText: tr.searchHintText,
      onSearchChanged: _onSearchTextChanged,
      onSearchCleared: () => _onSearchTextChanged(''),
      editIcon: _isTV ? const Icon(Icons.search) : null,
    );
  }

  List<Session> get _filteredSessions {
    return (_filterText != null)
        ? sessions.where((s) => s.contains(_filterText!)).toList()
        : sessions;
  }

  Widget _buildSessionList({
    required void Function(int, Session) sessionSelectedCallback,
    required void Function(int, Session) sessionDeleteCallback,
  }) {
    return Column(
      children: <Widget>[
        Expanded(
          child: SessionList(
            itemSelectedCallback: sessionSelectedCallback,
            itemDeleteCallback: sessionDeleteCallback,
            sessions: _filteredSessions
                .where((e) => e.type == _selectedSessionType)
                .toList(),
            selectedItem: _showSideBySide ? _selectedItem : null,
            showPopupMenuOnTap: _selectToEdit,
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return _buildSessionList(
      sessionSelectedCallback: _switchToSession,
      sessionDeleteCallback: _deleteSession,
    );
  }

  Widget _getChatPanel(ChatSession selected) {
    final chatID = selected.sessionID;
    return ChatPage(
      key: Key(chatID),
      session: selected,
    );
  }

  Color get _appBarBackgroundColor {
    return Theme.of(context).canvasColor;
  }

  Widget _buildTabletLayout(Session? selected) {
    final listW = Container(
      //color: Theme.of(context).dividerColor,
      child: _buildSessionList(
        sessionSelectedCallback: (index, item) {
          _moveSessionToTop(index, item, rebuild: false);
          _clearSessionUnreadStatus(index, item);
          setState(() {
            _setSelectedItem(item.type, item);
          });
        },
        sessionDeleteCallback: _deleteSession,
      ),
    );

    ChatServer.clearActiveChatID();
    Widget sessionW = Container(color: Theme.of(context).canvasColor);
    if (selected != null) {
      ChatServer.setIsOnFront(selected.sessionID, true);
      sessionW = _getChatPanel(selected as ChatSession);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final listWidth = _flex * constraints.maxWidth / 100;
        return Row(
          children: [
            if (listWidth >= 350 || _flex >= _defaultFlex)
              Flexible(flex: _flex, child: listW),
            SliderWidget(
              color: _appBarBackgroundColor,
              width: constraints.maxHeight,
              initialFlex: 30,
              flexScale: 100,
              onFlexChanged: (flex) {
                setState(() {
                  _flex = flex;
                });
              },
            ),
            Flexible(flex: 100 - _flex, child: sessionW),
          ],
        );
      },
    );
  }

  void onLoading(bool loading) {
    if (mounted) {
      setState(() {
        isLoading = loading;
      });
    }
  }

  void _sessionTypeSelected(SessionType sessionType) {
    _selectedSessionType = sessionType;
    _selectedItem = _selectedItemMap[sessionType];
    if (mounted) {
      setState(() {});
    }
  }

  Widget get _selectToEditOnOff {
    final tr = AppLocalizations.of(context);
    return IconButtonWidget(
      focusZoom: 1.5,
      icon: Icon(_selectToEdit ? Icons.edit_off : Icons.edit),
      onPressed: () {
        setState(() {
          _selectToEdit = !_selectToEdit;
        });
      },
      tooltip: tr.openToEditText,
    );
  }

  List<Widget>? get _appBarActions {
    return [
      if (!_showAppBar)
        Container(
          constraints: const BoxConstraints(maxWidth: 320),
          child: _searchWidget,
        ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: _addSessionsButton,
      ),
      if (_isTV && !_showAppBar) _selectToEditOnOff,
      if (_isTV || _showAppBar)
        StatusWidget(
          compact: true,
        ),
      if (_isTV && !_showAppBar) tv.EndDrawerButton(context: context),
    ];
  }

  PreferredSizeWidget get _appBar {
    return MainAppBar(
      title: "Chats",
      trailing: _appBarActions,
    );
  }

  Widget _buildSessionsWidget(Session? selected) {
    if (_showSideBySide) {
      return _buildTabletLayout(selected);
    }
    return _buildMobileLayout();
  }

  Widget get _sessionsWidget {
    return Column(children: [
      const SizedBox(height: 8),
      if (!_showAppBar)
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: _appBarActions ?? [],
        ),
      Expanded(
        child: _buildSessionsWidget(_selectedItem),
      ),
    ]);
  }

  String? _validateGroupName(String groupName) {
    final sessionID = ChatID.fromGroupName(groupName).id;
    final oldSession = sessionsMap[sessionID];
    if (oldSession != null) {
      return "Group $groupName already exits";
    }
    return null;
  }

  void _handleNewChat(ChatSession newSession) {
    _addSession(newSession);
    if (_showSideBySide) {
      setState(() {
        _setSelectedItem(newSession.type, newSession);
      });
    } else {
      Navigator.of(context).pushNamed(
        '/chat/${newSession.sessionID}',
        arguments: newSession.toJson(),
      );
    }
  }

  Widget get _addSessionsButton {
    if (_selectedSessionType == SessionType.chat) {
      return AddSessionWidget(
        onNewChat: _handleNewChat,
        validateGroupName: _validateGroupName,
        showAsLeftSide: false,
        iconSize: _isTV ? 48 : null,
      );
    }
    return Container();
  }

  Widget get _body {
    return StackWith(
      bottom: [
        if (_isTV) Background(context),
        _sessionsWidget,
      ],
      top: loadingWidget(),
      toStackOn: isLoading,
    );
  }

  bool get _showSideBySide {
    return showSideBySide(context) && !_isTV;
  }

  bool get _showAppBar {
    return !useNavigationRail(context);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final size = MediaQuery.of(context).size;
    Pst.saveWindowSize(size);

    return Scaffold(
      body: _showAppBar ? _body : SafeArea(left: false, child: _body),
      key: _scaffoldKey,
      appBar: _showAppBar ? _appBar : null,
      drawer: widget.showDrawer ? const MainDrawer() : null,
      endDrawer: _isTV ? const MainDrawer() : null,
    );
  }

  /// Only support searching on the text in sessions list right now instead of
  /// the full details of the sessions.
  void _onSearchTextChanged(String text) {
    setState(() {
      _filterText = text;
    });
  }
}
