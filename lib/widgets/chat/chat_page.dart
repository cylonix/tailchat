// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:downloadsfolder/downloadsfolder.dart' as sse;
import 'package:duration/duration.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:open_file/open_file.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart' as pp;
import 'package:share_plus/share_plus.dart';
import '../../api/chat_service.dart';
import '../../api/chat_server.dart';
import '../../api/config.dart';
import '../../api/contacts.dart';
import '../../api/send_chat.dart';
import '../../gen/l10n/app_localizations.dart';
import '../../models/alert.dart';
import '../../models/chat/chat_event.dart';
import '../../models/chat/chat_id.dart';
import '../../models/chat/chat_message.dart';
import '../../models/chat/chat_send_peers_result.dart';
import '../../models/chat/chat_session.dart';
import '../../models/chat/chat_storage.dart';
import '../../models/config/config_change_event.dart';
import '../../models/contacts/device.dart';
import '../../models/progress_change_event.dart';
import '../../models/session_event.dart';
import '../../models/session_storage.dart';
import '../../models/contacts/contact.dart';
import '../../models/contacts/user_profile.dart';
import '../../receive_share_page.dart';
import '../../utils/global.dart';
import '../../utils/logger.dart';
import '../../utils/utils.dart' as utils;
import '../alert_chip.dart';
import '../alert_dialog_widget.dart';
import '../common_widgets.dart';
import '../snackbar_widget.dart';
import '../tv/return_button.dart';
import 'app_bar.dart';
import 'attachments.dart';
import 'chat_group_management_page.dart';
import 'custom_message.dart';
import 'file_manager_page.dart';
import 'voice_recording.dart';

class ChatPage extends StatefulWidget {
  final ChatSession session;
  const ChatPage({
    super.key,
    required this.session,
  });

  static Future<void> addNewGroupChat(
    String chatID,
    String name,
    UserProfile selfUser,
    List<UserProfile> groupUsers,
  ) async {
    List<types.User> users = [];
    for (var up in groupUsers) {
      final user = ChatMessage.toAuthor(
        up,
        role: up.id == selfUser.id ? types.Role.admin : null,
      );
      users.add(user);
    }
    final room = types.Room(
      id: chatID,
      name: name,
      createdAt: DateTime.now().microsecondsSinceEpoch,
      type: types.RoomType.group,
      users: users,
    );
    await ChatStorage(chatID: chatID).saveRoom(room);
    // Don't wait for the sending to complete so that chat page can show up
    // right away.
    //Cylonixd.sendRoom(room, groupUsers, isUpdate: false);
  }

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage>
    with AutomaticKeepAliveClientMixin, RouteAware {
  List<types.Message> _messages = [];
  StreamSubscription<ChatEvent>? _chatAddEventSub;
  StreamSubscription<ChatEvent>? _chatRxEventSub;
  StreamSubscription<ChatRoomEvent>? _chatRoomEventSub;
  StreamSubscription<ChatSimpleUISettingChangeEvent>? _chatSimpleUISub;
  StreamSubscription<ProgressChangeEvent>? _progressEventSub;
  StreamSubscription<SelfUserChangeEvent>? _selfUserChangeSub;
  StreamSubscription<ChatServiceStateEvent>? _chatServiceStateSub;
  StreamSubscription<ContactsEvent>? _contactsEventSub;
  types.Message? _replyMessage;
  types.Room? _room;
  types.User? _user;
  Alert? _alert;
  bool _initDone = false;
  bool _canReceive = false;
  bool _showSendResult = true;
  bool _hasPeersReady = false;
  bool _simpleUI = Pst.chatSimpleUI ?? false;
  int _onlineUsers = 0;
  late Timer _timer;
  late ChatID _chatID;
  late ChatSession _session;
  late ChatStorage _storage;
  final Map<String, types.Status> _statusMap = {};
  final _isTV = Pst.enableTV ?? false;
  Contact? _peerContact;
  Device? _peerDevice;
  bool _canSendChecking = false;
  bool _isActive = true;
  Timer? _tryToConnectPeersTimer;
  int _tryToConnectAttempts = 0;
  final _initalTryToConnectBackoff = 1; // seconds
  final _maxTryToConnectBackoff = 1800; // 30 mins in seconds

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _session = widget.session;
    _chatID = ChatID(id: _session.sessionID);
    _storage = ChatStorage(chatID: _chatID.id);
    _user = ChatMessage.selfToAuthor();
    _canReceive = ChatServer.isServiceSocketConnected;
    ChatServer.startServer();
    _pingPeers();
    _registerChatServerEvent();
    _registerSelfUserChangeEvent();
    _loadMessages();
    _getRoom();
    _updateChatPeersStatus();
    _registerChatServiceEvent();
    _registerContactsEvent();
    _getPeerContact();
    _getPeerDevice();
    _timer = _startTimer();
    _initDone = true;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    Global.routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void didPush() {
    _onAcive();
  }

  @override
  void didPopNext() {
    _onAcive();
  }

  @override
  void didPop() {
    _onInactive();
  }

  @override
  void didPushNext() {
    _onInactive();
  }

  @override
  void dispose() {
    _cancelSubs();
    ChatServer.setIsOnFront(_chatID.id, false);
    super.dispose();
  }

  Logger get _logger {
    return Logger(tag: "Chat $_title $_subTitle");
  }

  void _onAcive() {
    _logger.d("-> Active");
    _isActive = true;
    _tryToConnectAttempts = 0;
    _onTryToConnect();
    ChatServer.setIsOnFront(_chatID.id, true);
  }

  void _onInactive() {
    _logger.d("-> Inactive");
    _isActive = false;
    _tryToConnectPeersTimer?.cancel();
    _tryToConnectAttempts = 0;
    ChatServer.setIsOnFront(_chatID.id, false);
  }

  void _cancelSubs() {
    _chatAddEventSub?.cancel();
    _chatRxEventSub?.cancel();
    _chatRoomEventSub?.cancel();
    _chatSimpleUISub?.cancel();
    _contactsEventSub?.cancel();
    _progressEventSub?.cancel();
    _selfUserChangeSub?.cancel();
    _chatServiceStateSub?.cancel();
    _timer.cancel();
    Global.routeObserver.unsubscribe(this);
  }

  void _registerChatServiceEvent() {
    final eventBus = ChatService.eventBus;
    _chatServiceStateSub = eventBus.on<ChatServiceStateEvent>().listen((event) {
      if (event.deviceID == null) {
        if (mounted) {
          setState(() {
            _logger.i("Chat receive state changed: ${event.state.name}");
            _canReceive = (event.state == ChatServiceState.connected);
          });
        }
      } else {
        _logger.d("Chat send state changed: -> ${event.state}");
        _updateChatPeersStatus();
      }
    });
  }

  void _registerContactsEvent() {
    final eventBus = contactsEventBus;
    _contactsEventSub = eventBus.on<ContactsEvent>().listen((event) {
      _logger.d("Contacts event received. Update check peers status.");
      _updateChatPeersStatus();
    });
  }

  void _getRoom() async {
    if (_isGroupChat) {
      final room = await _storage.getRoom();
      if (room != null) {
        setState(() {
          _room = room;
        });
      }
    }
  }

  void _getPeerDevice() async {
    if (_isGroupChat) {
      return;
    }
    final peer = await getDevice(_session.peerDeviceID);
    if (peer != null && mounted) {
      setState(() {
        _peerDevice = peer;
      });
    }
  }

  void _getPeerContact() async {
    if (_isGroupChat) {
      return;
    }
    final c = await getContact(_session.peerUserID);
    if (c != null && mounted) {
      setState(() {
        _peerContact = c;
      });
    }
  }

  bool get _isGroupChat {
    return _chatID.isGroup;
  }

  /// Once a chat page is loaded, this may mean user is trying to connect with
  /// peers. To save traffic, only do this for user chat for now. We can check
  /// this again if we need to exclude mobile OR move this to be when sending
  /// the first message to the peer(s).
  void _pingPeers() {}

  void _registerSelfUserChangeEvent() {
    final eventBus = Pst.eventBus;
    _selfUserChangeSub = eventBus.on<SelfUserChangeEvent>().listen((onData) {
      final selfUser = Pst.selfUser;
      if (selfUser != null) {
        _user = ChatMessage.toAuthor(selfUser);
        if (mounted) {
          setState(() {});
        }
      }
    });
  }

  void _registerChatServerEvent() {
    final myChatID = _session.sessionID;
    final eventBus = ChatServer.getChatEventBus();
    _chatAddEventSub = eventBus.on<ChatAddEvent>().listen((chatEvent) {
      final chatID = chatEvent.chatID;
      final isForMe = chatID == myChatID;
      final id = chatEvent.message.id;
      _logger.d("msg=$id chat=$chatID my=$myChatID for-me=$isForMe");
      if (isForMe) {
        // Notify-message sender should have saved it already.
        final path = chatEvent.originalPath;
        _addMessage(chatEvent.message, save: false, path: path);
      }
    });
    _chatRxEventSub = eventBus.on<ChatReceiveEvent>().listen((chatEvent) {
      final chatID = chatEvent.chatID;
      final isForMe = chatID == myChatID;
      _logger.d("received chat to $chatID my: $myChatID for me $isForMe");
      if (isForMe) {
        _receiveMessage(chatEvent.message);
      }
    });
    _chatRoomEventSub = eventBus.on<ChatRoomEvent>().listen((chatRoomEvent) {
      final chatID = chatRoomEvent.chatID;
      final isForMe = chatID == myChatID;
      _logger.d("received room $chatID my: $myChatID for me $isForMe");
      if (isForMe) {
        _receiveChatRoomEvent(chatRoomEvent);
      }
    });
    _chatSimpleUISub =
        Pst.eventBus.on<ChatSimpleUISettingChangeEvent>().listen((event) {
      if (mounted) {
        setState(() {
          _simpleUI = event.enable;
        });
      }
    });
    // TODO: has only one listner so that we don't have to check isMyMessageID.
    _progressEventSub = eventBus.on<ProgressChangeEvent>().listen((event) {
      final messageID = event.messageID;
      _logger.i("Progress event $event");
      if (event.chatID == myChatID ||
          (event.chatID == "" &&
              messageID != "" &&
              _isMyMessageID(messageID))) {
        final percent = event.bytes / event.total;
        final bytes = formatBytes(event.bytes, 2);
        final total = formatBytes(event.total, 2);
        final time = Duration(milliseconds: event.time).pretty();
        final progress =
            percent < 1 ? "$bytes/$total in $time" : "$total in $time";
        // don't persist in-progress updates as there are multiple sending
        // happening at the same time.
        _logger.d("Update progress: '$percent' '$progress'");
        _updateMessageSent(
          messageID,
          persist: false,
          updateMetadata: (message) {
            var metadata = message.metadata;
            if (progress.isEmpty) {
              if (metadata == null || metadata["progress"] == null) {
                return message;
              }
              metadata["progress"] = null;
              return message.copyWith(metadata: metadata);
            }
            if (metadata == null) {
              metadata = <String, dynamic>{
                "progress": {event.peer: progress},
              };
            } else if (metadata["progress"] == null) {
              metadata["progress"] = {event.peer: progress};
            } else {
              metadata["progress"][event.peer] = progress;
            }
            return message.copyWith(metadata: metadata);
          },
        );
      }
    });
  }

  /// Check if a message ID is ours.
  /// TODO: to be optimized once moving to sqflite for message storage.
  bool _isMyMessageID(String messageID) {
    return _messages.any((m) => m.id == messageID);
  }

  Timer _startTimer() {
    return Timer.periodic(const Duration(seconds: 15), (timer) async {
      await _checkExpired();
      if (await _updateChatPeersStatus()) {
        _retryPendingMessage();
      }
    });
  }

  Future<void> _checkExpired() async {
    final now = DateTime.now();
    final toRemove = _messages
        .where((m) {
          final expireAt = m.expireAt;
          if (expireAt != null) {
            if (DateTime.fromMillisecondsSinceEpoch(expireAt).isBefore(now)) {
              return true;
            }
          }
          return false;
        })
        .map((m) => m.id)
        .toList();
    if (toRemove.isNotEmpty) {
      _messages = await _storage.removeMessages(toRemove) ?? [];
      if (mounted) {
        setState(() {});
      }
    }
  }

  void _receiveChatRoomEvent(ChatRoomEvent event) {
    _room = event.room;
    if (mounted) {
      setState(() {});
    }
  }

  void _receiveMessage(types.Message message) async {
    if (message is types.DeleteMessage) {
      if (message.deleteAll) {
        var removed = false;
        _logger.i("delete all from ${message.author.id} mine is ${_user?.id}");
        if (message.author.id == _user?.id) {
          // Skip handling as the file has been deleted by chat server and
          // the session is also going to be deleted by the sessions page.
          return;
        } else {
          // Remove all messages sent by the author if delete-all is sent from
          // a different user. Keep message sent by others and myself.
          final toRemove = _messages
              .where((m) => m.author.id == message.author.id)
              .map((m) => m.id)
              .toList();
          if (toRemove.isNotEmpty) {
            removed = true;
            _messages = await _storage.removeMessages(toRemove) ?? [];
          }
        }
        if (removed && mounted) {
          setState(() {});
        }
      } else {
        await _deleteMessage(message);
      }
      return;
    }
    _messages.insert(0, message);
    if (mounted) {
      setState(() {});
    }
  }

  types.Message _updateMessageStatus(
    types.Message message,
    types.Status s, {
    bool copy = true,
  }) {
    if (copy) {
      message = message.copyWith(status: s);
    }
    _statusMap[message.id] = s;
    return message;
  }

  types.Status? _getStatusFromMap(String id) {
    return _statusMap[id];
  }

  Future<bool> _updateChatPeersStatus() async {
    final self = Pst.selfDevice;
    if (self == null) {
      return false;
    }
    //_logger.d("Updating chat peer status...");
    final peers = await _getChatPeers();
    final hasPeersReady = peers.any((p) => p.isOnline);
    var onlineUsersMap = <String, bool>{};
    if (self.isAvailable) {
      onlineUsersMap[self.id] = true;
    }
    for (var peer in peers) {
      if (peer.isOnline) {
        onlineUsersMap[peer.userID] = true;
      }
    }
    final onlineUsers = onlineUsersMap.length;
    if (_hasPeersReady != hasPeersReady || _onlineUsers != onlineUsers) {
      _logger.d(
        "Update chat peer status: $_hasPeersReady -> $hasPeersReady "
        "online [$_onlineUsers] -> [$onlineUsers]",
      );
      if (mounted) {
        setState(() {
          _hasPeersReady = hasPeersReady;
          _onlineUsers = onlineUsers;
        });
      }
    }
    return hasPeersReady;
  }

  Future<void> _addMessage(
    types.Message message, {
    bool save = true,
    String? path,
  }) async {
    if (!mounted) {
      return;
    }
    if (save) {
      // By default, always retry a message that's not yet sent.
      message = _updateMessageStatus(message, types.Status.toretry);
      await _storage.appendMessage(message);
    }

    // Avoid race conditions of loading messages and notifying messages.
    // The map can be cost for memory.
    var skipSending = _getStatusFromMap(message.id) == types.Status.sending;
    if (skipSending) {
      _logger.d("${message.id} is already sending. skip...");
    } else {
      // Change to sending status once we start sending
      message = _updateMessageStatus(message, types.Status.sending);
      _messages.insert(0, message);
      if (mounted) {
        setState(() {
          _logger.d("rebuild with add messages[${_messages.length}]");
        });
      }

      _logger.d("${message.id} send from addMessage");
      message = await _sendMessage(message, path: path) ?? message;
    }
    _notifyMessageSent(message);
  }

  void _notifyMessageSent(types.Message message) {
    final eventBus = ChatServer.getChatEventBus();
    eventBus.fire(ChatSendEvent(
      chatID: _session.sessionID,
      message: message,
    ));
  }

  Future<types.Message?> _updateMessageSent(
    String messageID, {
    types.Message? message,
    types.Message Function(types.Message)? updateMetadata,
    types.Status? status,
    bool persist = false,
  }) async {
    final index = _messages.indexWhere((element) => element.id == messageID);
    if (index < 0) {
      return message;
    }
    message ??= _messages[index];
    if (updateMetadata != null) {
      message = updateMetadata(message);
    }
    if (status != null) {
      message = message.copyWith(metadata: message.metadata, status: status);
      _updateMessageStatus(message, status, copy: false);
    }
    _messages[index] = message;
    if (mounted) {
      _logger.d("update UI for the change in message");
      setState(() {});
    }

    if (persist) {
      final messages = await _storage.updateMessage(message);
      if (messages != null) {
        _logger.d("messages${messages.length} old[${_messages.length}]");
        //_messages = messages;
      }
    }
    return message;
  }

  Future<void> _deleteMessage(
    types.Message message, {
    bool forAll = false,
  }) async {
    final index = _messages.indexWhere((element) => element.id == message.id);
    if (index < 0) {
      return;
    }
    _messages.removeAt(index);
    if (mounted) {
      setState(() {
        //_messages = messages;
      });
    }

    final messages = await _storage.removeMessage(message.id);
    if (messages != null) {
      _logger.d("messages[${messages.length}] old[${_messages.length}]");
    }
    if (forAll) {
      final m = types.DeleteMessage.fromMessage(message);
      await _addMessage(m);
    }
  }

  Future<bool?> _showSendResultDialog(
    ChatSendPeersResult? r, {
    String? additionalAskTitle,
    void Function()? onAdditionalAskPressed,
    Widget? otherActions,
  }) async {
    if (!mounted) {
      return null;
    }
    final tr = AppLocalizations.of(context);
    String? st;
    String? ft;
    if (r != null) {
      final s = r.successCnt;
      final f = r.failureCnt;
      st = r.successMsg != null
          ? "${tr.successDeviceCountText} ($s):"
          : r.success
              ? "${tr.successText}: ${r.successUserCnt} (${tr.userText})"
              : null;
      ft = r.failureMsg != null ? "${tr.failureDeviceCountText} ($f):" : null;
    }

    return AlertDialogWidget(
      title: tr.messageSendResultsText,
      additionalAskTitle: additionalAskTitle,
      successSubtitle: st,
      failureSubtitle: ft,
      successMsg: r?.successMsg,
      failureMsg: r?.failureMsg,
      onAdditionalAskPressed: onAdditionalAskPressed,
      otherActions: otherActions,
    ).show(context);
  }

  Future<List<Device>> _getChatPeers({
    bool alertUser = true,
  }) async {
    if (!mounted) {
      return [];
    }
    final peers = await _chatID.chatPeers;
    if (!mounted) {
      return [];
    }
    if (peers == null) {
      if (alertUser) {
        final tr = AppLocalizations.of(context);
        SnackbarWidget.e(tr.noDeviceAvailableToChatMessageText).show(context);
      }
      return [];
    }
    return peers;
  }

  Future<String?> _getPath(String? uri) async {
    if (uri == null) {
      return null;
    }
    if (ChatMessage.needToCopyFile) {
      return await ChatStorage.getAbsolutePath(uri);
    }
    return uri;
  }

  List<Device> _filterRetryPeers(
    types.Message message,
    List<Device> peers,
  ) {
    List<Device> filteredPeers = peers;
    var metadata = message.metadata;
    if (metadata != null && metadata["sendResult"] != null) {
      try {
        final json = jsonDecode(metadata["sendResult"]);
        final r = ChatSendPeersResult.fromJson(json);
        final statusMap = r.statusMap ?? {};
        filteredPeers = [];
        for (var peer in peers) {
          final pid = peer.id;
          final sent = statusMap[pid.toString()] ?? false;
          if (!sent) {
            filteredPeers.add(peer);
          }
        }
      } catch (e) {
        _logger.e("failed to filter retrying peers: $e");
      }
    }
    return filteredPeers;
  }

  bool get _allUsersOnline {
    return (_isGroupChat && _onlineUsers == _room?.users.length) ||
        _onlineUsers == 1;
  }

  Future<types.Message?> _sendMessage(
    types.Message message, {
    bool isRetry = false,
    String? path,
  }) async {
    if (!mounted) {
      return message;
    }
    final tr = AppLocalizations.of(context);
    String? name = message.name;
    path ??= await _getPath(message.uri);
    final self = Pst.selfDevice;
    if (self == null) {
      _logger.e("failed to find self status");
      return await _updateMessageSent(
        message.id,
        message: message,
        status: types.Status.toretry,
      );
    }
    var peers = await _getChatPeers();
    if (isRetry) {
      peers = _filterRetryPeers(message, peers);
    }
    if (peers.isEmpty) {
      _logger.e("failed to get chat peers");
      return await _updateMessageSent(
        message.id,
        message: message,
        status: types.Status.toretry,
      );
    }
    if (message.expireAt == null &&
        message.createdAt != null &&
        _session.messageExpireInMs != null) {
      message = message.copyWith(
        expireAt: message.createdAt! + _session.messageExpireInMs!,
      );
    }
    final r = await sendPeersMessage(
      _session.sessionID,
      jsonEncode(message),
      path,
      name,
      peers,
      message,
    );
    _logger.d("send result: $r");
    late types.Status status;
    if (r.success) {
      status = types.Status.sent;
      if (message is types.DeleteMessage) {
        await _deleteMessage(message);
        if (mounted) {
          Toast.s(tr.deleteFromAllPeersSuccessText).show(context);
        }
        return null;
      }
    } else {
      if (_showSendResult && mounted) {
        await _showSendResultDialog(
          r,
          additionalAskTitle: tr.dontShowAgainText,
          onAdditionalAskPressed: () {
            _showSendResult = false;
          },
        );
      }
      final sent = r.failureCnt <= 0;
      final fStatus = message.retry ? types.Status.toretry : types.Status.error;
      status = sent ? types.Status.sent : fStatus;
      _logger.d("update message status to $status");
    }
    final newMessage = await _updateMessageSent(
      message.id,
      message: message,
      status: status,
      persist: true,
      updateMetadata: (message) {
        final sendResult = (r.success && _allUsersOnline)
            ? r.toStatsOnlyString()
            : r.toString();
        var metadata = message.metadata;
        if (metadata == null) {
          metadata = <String, dynamic>{"sendResult": sendResult};
        } else {
          metadata["sendResult"] = sendResult;
        }
        return message.copyWith(metadata: metadata);
      },
    );
    return newMessage!;
  }

  void _handleAttachmentPressed() {
    showModalBottomSheet<void>(
      context: context,
      constraints: const BoxConstraints(minWidth: double.infinity),
      builder: (BuildContext context) {
        return Attachments(
          onMediaSelected: _handleMediaSelection,
          onFileSelected: _handleFileSelection,
        );
      },
    );
  }

  /// Add a new file/image message. It will try to show and send message asap
  /// and then copy the file over to the chat folder for mobile/macos due to
  /// file permission issue. This is to prioritize sending/showing the message,
  /// however, if it is not that much an improvement compared to just copy first
  /// and then send, then we probably should just copy first.
  Future<void> _addNewFileMessage(ChatMessage m, String path) async {
    await _addMessage(m.message, path: path);
    m.copyFile(path);
  }

  void _handleFileSelection() async {
    if (_isTV) {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (context) => FileManagerPage(onFileSelected: (file) {
          Navigator.of(context).pop();
          _handleFilePathAdded(file.path, null);
        }),
      ));
      return;
    }
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: true,
    );
    for (var file in result?.files ?? []) {
      await _handleFilePathAdded(file.path, file.size);
    }
  }

  Future<void> _handleFilePathAdded(String? path, int? size) async {
    if (path == null) {
      return;
    }
    try {
      size ??= await File(path).length();
    } catch (e) {
      _logger.e("$e");
      if (mounted) {
        final tr = AppLocalizations.of(context);
        utils.showAlertDialog(context, tr.prompt, '$e');
      }
      return;
    }
    final m = ChatMessage.fromFile(
      _chatID.id,
      path,
      size,
      user: _user,
      replyId: _replyMessage?.id,
    );
    setState(() {
      _replyMessage = null;
    });
    await _addNewFileMessage(m, path);
  }

  void _forwardMessage(types.Message message) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (context) => ReceiveSharePage(
        messages: [message],
        showSideBySide: utils.showSideBySide(context),
      ),
    ));
  }

  Future<String?> _getMobileDownloadFilePath(String filename) async {
    if (Platform.isAndroid) {
      const type = pp.StorageDirectory.downloads;
      final dir = (await pp.getExternalStorageDirectories(type: type))?.first;
      if (dir != null) {
        return p.join(dir.path, filename);
      }
    }
    if (Platform.isIOS) {
      final dir = await pp.getApplicationDocumentsDirectory();
      return p.join(dir.path, filename);
    }
    return null;
  }

  Future<String?> _getAndroidSharedDownloadFilePath(String? name) async {
    if (name == null) {
      return null;
    }
    final dir = await sse.getDownloadDirectory();
    return p.join(dir.path, "Cylonix", name);
  }

  Future<String?> _getSaveFilePath(String? name, bool sharedStorage) async {
    if (utils.isMobile()) {
      if (sharedStorage) {
        if (Platform.isAndroid) {
          return _getAndroidSharedDownloadFilePath(name);
        } else {
          _logger.e("public storage is not supported on iOS yet");
          return null;
        }
      }
      return _getMobileDownloadFilePath(name ?? "tmp");
    }
    return FilePicker.platform.saveFile(fileName: name);
  }

  void _saveToGallery(types.Message message) async {
    final tr = AppLocalizations.of(context);
    final uri = message.uri;
    if (uri != null) {
      try {
        var success = false;
        final path = await ChatStorage.getAbsolutePath(uri);
        if (utils.isImage(path) || utils.isVideo(path)) {
          success = await ImageGallerySaverPlus.saveFile(path) ?? false;
        } else {
          _logger.e(tr.unsupportedMediaText);
          if (mounted) {
            utils.showAlertDialog(context, tr.prompt, tr.unsupportedMediaText);
          }
          return;
        }
        if (mounted) {
          success
              ? SnackbarWidget.s(tr.imageSavedToGalleryText).show(context)
              : SnackbarWidget.e(tr.errSavingImageText).show(context);
        }
      } catch (e) {
        _logger.e("image/video save error $e");
        if (mounted) {
          utils.showAlertDialog(context, tr.prompt, '$e');
        }
      }
    }
  }

  void _saveFile(types.Message message, {bool sharedStorage = true}) async {
    final tr = AppLocalizations.of(context);
    String? name = message.name;
    String? uri = await _getPath(message.uri);
    var result = await _getSaveFilePath(name, sharedStorage);

    if (result != null && uri != null) {
      try {
        result = await utils.makeSureFileNotExists(result);
        final src = File(uri);
        final dst = File(result);
        await dst.create(recursive: true);
        await src.copy(result);
        _logger.d("success to save file @ $result");
        if (mounted) {
          SnackbarWidget.s("${tr.fileSavedToText}: $result").show(context);
        }
      } catch (e) {
        _logger.e("failed to save file @ $result: $e");
        if (mounted) {
          utils.showAlertDialog(
            context,
            tr.failedToSaveFileText,
            "${tr.failedToSaveFileText} $result: $e",
          );
        }
      }
    }
  }

  Future<void> _shareMessage(types.Message message) async {
    String? uri = message.uri;
    if (uri != null) {
      try {
        var path = await ChatStorage.getAbsolutePath(uri);
        await Share.shareXFiles(
          [XFile(path)],
        );
      } catch (e) {
        _logger.e("file share error $e");
      }
    } else {
      if (message is types.TextMessage) {
        try {
          await Share.share(message.text);
        } catch (e) {
          _logger.e("share error $e");
        }
      }
    }
  }

  void _copyMessageText(types.Message message) async {
    if (message is types.TextMessage) {
      await Clipboard.setData(ClipboardData(text: message.text));
      if (mounted) {
        Toast.s("Message copied to clipboard").show(context);
      }
    }
  }

  void _setReplyMessage(types.Message message) {
    setState(() {
      _replyMessage = message;
    });
  }

  void _handleVideoSelection(bool fromCamera) async {
    String? path;
    int? size;
    if (utils.isMobile()) {
      final result = await ImagePicker().pickVideo(
        source: fromCamera ? ImageSource.camera : ImageSource.gallery,
      );
      path = result?.path;
      _handleFilePathAdded(path, size);
    } else {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: true,
      );
      for (var file in result?.files ?? []) {
        _handleFilePathAdded(file.path, file.size);
      }
    }
  }

  void _handleImageSelection(bool fromCamera) async {
    String? path;
    if (utils.isMobile()) {
      if (fromCamera) {
        final result = await ImagePicker().pickImage(
          source: ImageSource.camera,
        );
        path = result?.path;
        _handleImagePathAdded(path);
        return;
      }
      final result = await ImagePicker().pickMultiImage(limit: 64);
      for (var r in result) {
        _handleImagePathAdded(r.path);
      }
    } else {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: true,
      );
      for (var file in result?.files ?? []) {
        await _handleImagePathAdded(file.path);
      }
    }
  }

  Future<void> _handleImagePathAdded(String? path,
      {bool isEmoji = false}) async {
    if (path != null) {
      final bytes = await File(path).readAsBytes();
      final image = await decodeImageFromList(bytes);
      final m = ChatMessage.fromFile(
        _chatID.id,
        path,
        bytes.length,
        image: image,
        user: _user,
        isEmoji: isEmoji,
        replyId: _replyMessage?.replyId,
      );
      setState(() {
        _replyMessage = null;
      });
      await _addNewFileMessage(m, path);
    }
  }

  void _handleMediaSelection({bool? isVideo, bool? fromCamera}) {
    isVideo ??= false;
    fromCamera ??= false;
    isVideo
        ? _handleVideoSelection(fromCamera)
        : _handleImageSelection(fromCamera);
  }

  /// On mobile platforms, we enable gallery view of all the image files for
  /// swiping support. Hence no need to support message tap. On Desktop due
  /// to an issue with click device not supporting drag swiping behavior by
  /// default and we will need to use back/forward control buttons, we opt to
  /// disable the gallery view for now. The photo view package also has an
  /// issue that needs to be released first before we can add the control
  /// buttons:
  ///   https://github.com/bluefireteam/photo_view/issues/502
  void _handleMessageTap(
    types.Message message,
    Offset? savedTapPosition,
  ) async {
    if (message is types.ImageMessage && utils.isMobile()) {
      return;
    }

    final uri = message.uri;
    String path = "";
    if (uri != null) {
      try {
        path = await ChatStorage.getAbsolutePath(uri);
        final result = await OpenFile.open(path /*, linuxByProcess: true*/);
        if (result.type != ResultType.done) {
          throw Exception('${result.type}: ${result.message}');
        }
      } catch (e) {
        final msg = "Failed to open $path: $e";
        _logger.e(msg);
        if (mounted) {
          final tr = AppLocalizations.of(context);
          utils.showAlertDialog(context, tr.prompt, msg);
        }
      }
    } else {
      _handleMessageLongPressed(message, savedTapPosition);
    }
  }

  PopupMenuItem get _shareMessageMenuItem {
    final tr = AppLocalizations.of(context);
    return PopupMenuItem(
      value: "share",
      child: _getMenuItem(Icons.share_rounded, tr.shareText),
    );
  }

  PopupMenuItem get _saveMessageMenuItem {
    final tr = AppLocalizations.of(context);
    return PopupMenuItem(
      value: "save",
      child: _getMenuItem(Icons.save_alt_rounded, tr.saveText),
    );
  }

  PopupMenuItem get _saveToAppStorageMenuItem {
    final tr = AppLocalizations.of(context);
    return PopupMenuItem(
      value: "save",
      child: _getMenuItem(Icons.save_alt_rounded, tr.saveToAppStorageText),
    );
  }

  PopupMenuItem get _saveToSharedStorageMenuItem {
    final tr = AppLocalizations.of(context);
    return PopupMenuItem(
      value: "save-to-shared-storage",
      child: _getMenuItem(Icons.save_alt_rounded, tr.saveToSharedStorageText),
    );
  }

  Widget _getMenuItem(IconData icon, String menu) {
    return ListTile(leading: Icon(icon), title: Text(menu));
  }

  PopupMenuItem get _saveToGalleryMenuItem {
    final tr = AppLocalizations.of(context);
    return PopupMenuItem(
      value: "save-to-gallery",
      child: _getMenuItem(Icons.save_alt_rounded, tr.saveToGalleryText),
    );
  }

  PopupMenuItem get _forwardMessageMenuItem {
    final tr = AppLocalizations.of(context);
    return PopupMenuItem(
      value: "forward",
      child: _getMenuItem(Icons.forward_rounded, tr.forwardText),
    );
  }

  PopupMenuItem get _deleteMessageMenuItem {
    final tr = AppLocalizations.of(context);
    return PopupMenuItem(
      value: "delete",
      child: _getMenuItem(Icons.delete_rounded, tr.deleteText),
    );
  }

  PopupMenuItem get _deleteMessageForAllMenuItem {
    final tr = AppLocalizations.of(context);
    return PopupMenuItem(
      value: "delete-all",
      child: _getMenuItem(
        Icons.delete_forever_rounded,
        tr.deleteFromAllPeersText,
      ),
    );
  }

  PopupMenuItem get _copyMessageTextMenuItem {
    final tr = AppLocalizations.of(context);
    return PopupMenuItem(
      value: "copy",
      child: _getMenuItem(Icons.copy_rounded, tr.copyText),
    );
  }

  PopupMenuItem get _replyMessageMenuItem {
    final tr = AppLocalizations.of(context);
    return PopupMenuItem(
      value: "reply",
      child: _getMenuItem(Icons.reply_rounded, tr.replyText),
    );
  }

  PopupMenuItem _sendMessageAgainMenuItem(bool fromMe) {
    final tr = AppLocalizations.of(context);
    return PopupMenuItem(
      value: "send-again",
      child: _getMenuItem(
        fromMe ? Icons.send_rounded : Icons.loop_rounded,
        fromMe ? tr.sendAgainText : tr.sendText,
      ),
    );
  }

  /// Exception will be thrown if retry fails.
  void _handleMessageLongPressedRetry(
    types.Message message,
    ChatSendPeersResult result,
  ) async {
    final tr = AppLocalizations.of(context);
    await _showSendResultDialog(
      result,
      additionalAskTitle: result.success
          ? tr.sendAgainText
          : tr.retrySendingToFailedDevicesText,
      onAdditionalAskPressed: () async {
        if (result.success) {
          _addMessage(message.copyWith(id: ChatMessage.newMessageID()));
          return;
        }
        message = message.copyWith(status: types.Status.sending);
        _logger.d("${message.id} send from long pressed retry");
        await _sendMessage(message);
      },
      otherActions: TextButton(
        onPressed: () async {
          Navigator.of(context).pop(true);
          await _deleteMessage(message);
        },
        child: Text(tr.deleteText),
      ),
    );
  }

  void _handleMessageLongPressedOthers(
    types.Message message,
    Offset? savedTapPosition,
  ) async {
    late RelativeRect position;
    try {
      final overlay = Overlay.of(context).context.findRenderObject();
      position = RelativeRect.fromRect(
        savedTapPosition! & const Size(40, 40),
        Offset.zero & overlay!.semanticBounds.size,
      );
    } catch (e) {
      _logger.e("failed to find position");
      return;
    }
    final canCopy = message is types.TextMessage;
    final canSave = message.canSave;
    final canShare = canSave && (utils.isMobile() || Platform.isMacOS);
    final canDeleteForAll = message.status == types.Status.sent;
    final received = message.status == types.Status.received;
    final fromMe = message.author.id == _user!.id && !received;
    final action = await showMenu(
      shape: commonShapeBorder(),
      context: context,
      position: position,
      items: <PopupMenuEntry>[
        if (canCopy) _copyMessageTextMenuItem,
        _forwardMessageMenuItem,
        _deleteMessageMenuItem,
        if (canDeleteForAll) _deleteMessageForAllMenuItem,
        _replyMessageMenuItem,
        if (canShare) _shareMessageMenuItem,
        if (canSave && utils.isMobile()) _saveToGalleryMenuItem,
        if (canSave && utils.isMobile()) _saveToAppStorageMenuItem,
        if (canSave && Platform.isAndroid) _saveToSharedStorageMenuItem,
        if (canSave && utils.isDesktop()) _saveMessageMenuItem,
        _sendMessageAgainMenuItem(fromMe),
      ],
    );
    switch (action) {
      case "copy":
        _copyMessageText(message);
        break;
      case "delete":
        _deleteMessage(message);
        break;
      case "delete-all":
        _deleteMessage(message, forAll: true);
        break;
      case "forward":
        _forwardMessage(message);
        break;
      case "reply":
        _setReplyMessage(message);
        break;
      case "share":
        _shareMessage(message);
        break;
      case "save":
        _saveFile(message, sharedStorage: false);
        break;
      case "save-to-gallery":
        _saveToGallery(message);
        break;
      case "save-to-shared-storage":
        _saveFile(message, sharedStorage: true);
        break;
      case "send-again":
        final m = ChatMessage.copyFrom(_chatID.id, message, user: _user);
        _addMessage(m.message);
        break;
      case null:
        // Silently return as user decided not to do anything.
        return;
      default:
        _logger.e("$action is not an expected menu item");
    }
  }

  void _handleCloseReplyMessagePressed() {
    setState(() {
      _replyMessage = null;
    });
  }

  void _handleMessageLongPressed(
    types.Message message,
    Offset? savedTapPosition,
  ) async {
    final metadata = message.metadata;
    final resultMap = metadata?['sendResult'];
    if (resultMap != null) {
      try {
        final r = ChatSendPeersResult.fromJson(jsonDecode(resultMap));
        if (!r.success) {
          _handleMessageLongPressedRetry(message, r);
          return;
        }
      } catch (e) {
        _logger.d("failed to show send result: $e");
      }
    }
    _handleMessageLongPressedOthers(message, savedTapPosition);
  }

  void _handlePreviewDataFetched(
    types.TextMessage message,
    types.PreviewData previewData,
  ) {
    final index = _messages.indexWhere((element) => element.id == message.id);
    final updatedMessage = _messages[index].copyWith(
      metadata: _messages[index].metadata,
      previewData: previewData,
    );

    _messages[index] = updatedMessage;
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {});
      });
    }
  }

  void _handleSendPressed(types.PartialText message) async {
    final m = ChatMessage.fromText(
      _chatID.id,
      message.text,
      user: _user,
      replyId: _replyMessage?.id,
    );
    setState(() {
      _replyMessage = null;
    });
    _addMessage(m.message);
  }

  /// re-try the messages that failed to send.
  void _retryPendingMessage() async {
    int count = 0;
    for (var i = 0; i < _messages.length; i++) {
      if (!mounted) {
        return;
      }
      var message = _messages[i];
      if (message.status == types.Status.toretry) {
        if (_getStatusFromMap(message.id) == types.Status.sending) {
          _logger.d("${message.id} is already sending. skip retry...");
          continue;
        }
        message = _updateMessageStatus(message, types.Status.sending);
        _messages[i] = message;
        _logger.d("[$i] ${message.id} send from retry pending message");
        await _sendMessage(message, isRetry: true);
        count++;
        if (count >= 10) {
          return;
        }
      }
    }
  }

  void _loadMessages() async {
    final messages = await _storage.readMessages();
    _logger.d("loaded messages[${messages.length}]");
    if (messages.isNotEmpty) {
      _messages = messages;
      _retryPendingMessage();
      if (mounted) {
        setState(() {});
      }
      final eventBus = ChatServer.getChatEventBus();
      eventBus.fire(ChatEvent(
        chatID: _session.sessionID,
        message: messages[0],
      ));
    }
  }

  String get _title {
    if (_isGroupChat) {
      final room = _room;
      return "${_session.groupName} ($_onlineUsers/${room?.users.length})";
    }
    if (_peerContact?.name != null) {
      return _peerContact!.name;
    }
    if (_initDone && mounted) {
      final tr = AppLocalizations.of(context);
      return tr.chatText;
    }
    return "";
  }

  String? get _subTitle {
    if (_isGroupChat) {
      return null;
    }
    return _peerDevice?.hostname.split('.')[0];
  }

  ChatL10n get _chatL10n {
    final locale = Localizations.localeOf(context);
    late ChatL10n l10n;
    switch (locale.languageCode) {
      case "zh":
        l10n = locale.scriptCode == "Hant"
            ? const ChatL10nZhHant()
            : const ChatL10nZhCN();
        break;
      default:
        l10n = const ChatL10nEn();
    }
    return l10n;
  }

  ChatTheme get _chatTheme {
    final darkTheme = CylonixDarkChatTheme(
      inputTextColor: const DarkChatTheme().inputTextColor,
    );
    final defaultTheme = CylonixDefaultChatTheme(
      inputTextColor: const DefaultChatTheme().inputTextColor,
    );
    return utils.isDarkMode(context) ? darkTheme : defaultTheme;
  }

  void _updateRoom(types.Room room) async {
    _room = room;
    List<UserProfile> users = [];
    for (var u in room.users) {
      final user = await getUser(u.id);
      if (user == null) {
        _logger.e("failed to get user for ${u.firstName} ${u.id}");
        continue;
      }
      users.add(user);
    }

    await _storage.saveRoom(room);
    await sendRoom(room, users, isUpdate: true);
    final eventBus = ChatServer.getChatEventBus();
    eventBus.fire(ChatReceiveUpdateRoomEvent(
      chatID: _session.sessionID,
      room: room,
    ));

    if (mounted) setState(() {});
  }

  void _updateSession(ChatSession session) {
    _session = session;
    if (mounted) setState(() {});
  }

  /// Manage group chat.
  void _onGroupChatManagementPressed() {
    final tr = AppLocalizations.of(context);
    final room = _room;
    if (room == null) {
      SnackbarWidget.e(tr.groupChatInfoMissingErrorText).show(context);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ChatGroupManagementPage(
          key: Key(_session.sessionID),
          session: _session,
          room: room,
          onRoomUpdate: _updateRoom,
          onSessionUpdate: _updateSession,
        ),
      ),
    );
  }

  /// Handle delete all.
  void _onDeleteAllMessagesPressed(bool deleteForAllPeers) async {
    var result = await _storage.deleteMessagesFile();
    _messages = [];
    if (result.success && deleteForAllPeers) {
      final m = types.DeleteMessage.deleteAll(
        _user!,
        ChatMessage.newMessageID(),
      );
      _addMessage(m);
    }
    if (mounted) {
      final tr = AppLocalizations.of(context);
      if (result.success) {
        SnackbarWidget.s(tr.deleteAllChatMessagesSucceededText).show(context);
      } else {
        utils.showAlertDialog(
          context,
          tr.prompt,
          '${tr.deleteAllChatMessagesFailedText}: ${result.error(context)}',
          showCancel: false,
        );
      }
      // Make an empty message to clear the last chats.
      final message = ChatMessage.fromText(
        _chatID.id,
        "",
        user: _user,
      );
      _notifyMessageSent(message.message);
      setState(() {
        // Re-flesh UI.
      });
    }
  }

  /// Set message expiration time for new messages from now on.
  void _onSetMessageExpirationTime(Duration? duration) async {
    if (_session.messageExpireInMs != duration?.inMilliseconds) {
      _session.messageExpireInMs = duration?.inMilliseconds;
      setState(() {});
      final userID = Pst.selfUser?.id;
      if (userID != null) {
        await SessionStorage(userID: userID).updateSession(_session);
      }
      SessionStorage.eventBus.fire(SessionUpdateEvent(_session));
    }
  }

  // Send emoji as emoji message to peer.
  void _handleEmojiSelected(String code, String asset) async {
    final m = ChatMessage.fromEmoji(
      _chatID.id,
      code,
      user: _user,
      replyId: _replyMessage?.id,
    );
    setState(() {
      _replyMessage = null;
    });
    _addMessage(m.message);
  }

  VoiceRecording? _voiceRecording;
  void _handleVoiceInput(bool start) async {
    if (start) {
      _voiceRecording = VoiceRecording(await ChatStorage.chatFilesDir);
      final msg = await _voiceRecording?.start();
      if (msg != null) {
        if (mounted) {
          final tr = AppLocalizations.of(context);
          await utils.showAlertDialog(context, tr.prompt, msg);
          if (mounted) {
            Navigator.of(context).pop();
          }
        }
        _voiceRecording = null;
      }
    } else {
      final record = _voiceRecording;
      if (record != null) {
        final file = await record.stop();
        _handleFilePathAdded(file, null);
      }
    }
  }

  Widget _customMessageBuilder(
    types.CustomMessage message, {
    required int messageWidth,
  }) {
    return CustomMessage(
      message: message,
      messageWidth: messageWidth,
    );
  }

  Widget get _chatWidget {
    final user = _user;
    if (user == null) {
      return Container();
    }
    final bool canRecord = !(Platform.isLinux || Platform.isWindows);
    //_logger.d("rebuild with messages[${_messages.length}]");
    return Chat(
      key: widget.key, // Force a chat widget rebuild
      customMessageBuilder: _customMessageBuilder,
      detailStatusBuilder: _detailStatusBuilder,
      isTV: _isTV,
      inputLeading: _inputLeading,
      messages: _messages,
      onAttachmentPressed: _handleAttachmentPressed,
      onCloseReplyMessagePressed: _handleCloseReplyMessagePressed,
      onMessageTap: _handleMessageTap,
      onMessageLongPress: _handleMessageLongPressed,
      onPreviewDataFetched: _handlePreviewDataFetched,
      onSendPressed: _handleSendPressed,
      onEmojiSelected: _handleEmojiSelected,
      onVoiceInput: canRecord ? _handleVoiceInput : null,
      replyMessage: _replyMessage,
      showUserAvatars: true,
      showUserNames: true,
      simpleUI: _isTV || _simpleUI,
      textSelectable: utils.isDesktop(),
      user: user,
      l10n: _chatL10n,
      theme: _chatTheme,
      disableImageGallery: utils.isDesktop(), // see _handleMessageTap.
      uriFixup: (String? uri) async {
        if (uri == null) {
          return null;
        }
        return await ChatStorage.getAbsolutePath(uri);
      },
      logger: _chatLogger,
      //bubbleBuilder: _bubbleBuilder,
    );
  }

  Widget? get _inputLeading {
    if (!_isTV) {
      return null;
    }
    final tr = AppLocalizations.of(context);
    return Column(
      children: [
        const SizedBox(height: 16),
        if (!Global.isAndroidTV) const ReturnButton(),
        const SizedBox(height: 16),
        OnlineStatusIcon(_hasPeersReady),
        Text(_title),
        const SizedBox(height: 16),
        if (_subTitle != null) Text(_subTitle!, textAlign: TextAlign.center),
        const SizedBox(height: 16),
        ChatAppBarPopupMenuButton(
          icon: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(tr.settingsTitle),
              ),
            ],
          ),
          messageExpireInMs: _session.messageExpireInMs,
          onDeleteAllPressed: _isGroupChat ? null : _onDeleteAllMessagesPressed,
          onGroupChatManagementPressed:
              _isGroupChat ? _onGroupChatManagementPressed : null,
          onSettingMessageExpirationTime:
              _isGroupChat ? null : _onSetMessageExpirationTime,
        ),
      ],
    );
  }

  Widget _detailStatusBuilder(types.Message message) {
    final room = _room;
    if (room != null) {
      final result = message.metadata?["sendResult"];
      if (result != null) {
        try {
          final r = ChatSendPeersResult.fromJson(jsonDecode(result));
          return Text('${r.successUserCnt}/${room.users.length}');
        } catch (e) {
          _logger.e("failed to parse send result: $e");
        }
      }
    }
    return const SizedBox();
  }

  void _onTryToConnect() async {
    _tryToConnectPeersTimer?.cancel();
    if (_hasPeersReady) {
      _logger.d("Already can send. Skip trying to connect.");
      return;
    }
    if (!_isActive || !mounted) {
      _logger.d("Not yet mounted or inactive. Skip trying to connect.");
      return;
    }
    if (_canSendChecking) {
      _logger.d("Already checking. Stop trying to connect.");
      setState(() {
        _tryToConnectAttempts = 0;
        _tryToConnectPeersTimer?.cancel();
        _tryToConnectPeersTimer = null;
        _canSendChecking = false;
      });
      return;
    }
    _logger.d("Trying to connect...");
    setState(() {
      _canSendChecking = true;
    });

    final peers = await _chatID.chatPeers ?? [];
    final result = await tryConnectToPeers(peers);
    if (mounted) {
      setState(() {
        _canSendChecking = false;
      });
    }

    if (result.success) {
      if (mounted) {
        if (_alert?.setter == 'onTryToConnect') {
          setState(() {
            _alert = null;
          });
        }
      }
      return;
    }
    _logger.d("Failed to connect to peers: ${result.failureMsg}");
    _tryToConnectAttempts++;
    var backoff = _initalTryToConnectBackoff << _tryToConnectAttempts;
    if (backoff >= _maxTryToConnectBackoff) {
      backoff = _maxTryToConnectBackoff;
    }
    _tryToConnectPeersTimer = Timer(
      Duration(seconds: backoff),
      _onTryToConnect,
    );
    if (mounted) {
      setState(() {
        _alert = Alert(
          'Failed to connect to peers: ${result.failureMsg}. '
          'Retry in $backoff seconds.',
          setter: 'onTryToConnect',
        );
      });
    }
  }

  void _chatLogger({String? d, String? i, String? w, String? e}) {
    if (d != null) _logger.d(d);
    if (i != null) _logger.i(i);
    if (w != null) _logger.w(w);
    if (e != null) _logger.e(e);
  }

  PreferredSizeWidget? get _appBar {
    if (_isTV) {
      return null;
    }
    _logger.d("Update appbar _canSendChecking=$_canSendChecking");
    return ChatAppBar(
      title: _title,
      canReceive: _canReceive,
      canSend: _hasPeersReady,
      canSendChecking: _canSendChecking,
      subtitle: _subTitle,
      messageExpireInMs: _session.messageExpireInMs,
      onTryToConnect: _onTryToConnect,
      onDeleteAllPressed: _isGroupChat ? null : _onDeleteAllMessagesPressed,
      onGroupChatManagementPressed:
          _isGroupChat ? _onGroupChatManagementPressed : null,
      onSettingMessageExpirationTime:
          _isGroupChat ? null : _onSetMessageExpirationTime,
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      appBar: _appBar,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            if (_alert != null)
              AlertChip(
                _alert!,
                width: double.infinity,
                onDeleted: () {
                  setState(() {
                    _alert = null;
                  });
                },
              ),
            Expanded(child: _chatWidget),
          ],
        ),
      ),
    );
  }
}

class CylonixDefaultChatTheme extends DefaultChatTheme {
  CylonixDefaultChatTheme({Color? inputTextColor})
      : super(
          attachmentButtonIcon: Icon(
            Icons.attach_file_rounded,
            color: inputTextColor,
          ),
        );
}

class CylonixDarkChatTheme extends DarkChatTheme {
  CylonixDarkChatTheme({Color? inputTextColor})
      : super(
          attachmentButtonIcon: Icon(
            Icons.attach_file_rounded,
            color: inputTextColor,
          ),
        );
}
