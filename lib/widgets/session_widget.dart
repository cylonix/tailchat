// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import '../api/chat_server.dart';
import '../api/config.dart';
import '../api/contacts.dart';
import '../gen/l10n/app_localizations.dart';
import '../models/chat/chat_event.dart';
import '../models/chat/chat_id.dart';
import '../models/chat/chat_session.dart';
import '../models/session.dart';
import '../models/contacts/user_profile.dart';
import '../utils/utils.dart';
import 'common_widgets.dart';
import 'chat/last_chat.dart';
import 'snackbar_widget.dart';
import 'time_text.dart';
import 'user/user_avatar.dart';

class SessionWidget extends StatefulWidget {
  final Session session;
  final void Function()? onDelete;
  final void Function()? onEdit;
  final void Function()? onTap;
  final void Function()? onLongPress;
  final void Function(TapDownDetails)? onTapDown;
  final Color? color;
  final Color? shadowColor;
  final BoxDecoration? decoration;
  final EdgeInsetsGeometry? margin;
  final bool narrow;
  final bool relaxFit;
  final bool veryTightFit;
  final bool showAvatar;
  final EdgeInsetsGeometry? padding;
  final ShapeBorder? shape;
  final bool showEditButton;
  final bool showPopupMenuOnLongPressed;
  final bool showPopupMenuOnTap;
  final Size? size;
  const SessionWidget({
    super.key,
    required this.session,
    this.onDelete,
    this.onEdit,
    this.onTap,
    this.onLongPress,
    this.onTapDown,
    this.color,
    this.decoration,
    this.margin,
    this.narrow = false,
    this.relaxFit = true,
    this.veryTightFit = false,
    this.showAvatar = true,
    this.padding,
    this.shadowColor,
    this.shape,
    this.showEditButton = true,
    this.showPopupMenuOnLongPressed = true,
    this.showPopupMenuOnTap = false,
    this.size,
  });

  @override
  SessionWidgetState createState() => SessionWidgetState();
}

class SessionWidgetState extends State<SessionWidget> {
  StreamSubscription<ChatRoomEvent>? _chatSub;
  StreamSubscription<ContactsEvent>? _contactSub;
  Offset? _savedTapPosition;
  String _titleText = "";
  late final FocusNode _focus;
  late final Session _session;
  late final bool _isTV;
  bool _hasPeersReady = false;
  UserProfile? _peerUser;

  @override
  void initState() {
    super.initState();
    _isTV = Pst.enableTV ?? false;
    _session = widget.session;
    _focus = FocusNode(debugLabel: "session-${_session.sessionID}");
    _focus.addListener(() {
      setState(() {});
    });
    _updateChatPeersStatus();
    _setTitleText();
    _setPeerUser();
    _registerChatEvent();
    _registerContactsEvent();
  }

  @override
  void dispose() {
    _chatSub?.cancel();
    _contactSub?.cancel();
    super.dispose();
  }

  void _updateChatPeersStatus() async {
    if (_session is ChatSession) {
      final chatID = ChatID(id: _session.sessionID);
      _hasPeersReady =
          (await chatID.chatPeers)?.any((p) => p.isOnline) ?? false;
    }
  }

  void _setPeerUser() async {
    final session = _session;
    if (session is ChatSession) {
      _peerUser = await getUser(session.peerUserID);
    }
  }

  void _setTitleText() async {
    final session = widget.session;
    var title = await session.title;
    title ??= session.name ?? "";
    if (_titleText != title) {
      _titleText = title;
      if (mounted) {
        setState(() {});
      }
    }
  }

  void _registerChatEvent() {
    final eventBus = ChatServer.getChatEventBus();
    _chatSub = eventBus.on<ChatReceiveUpdateRoomEvent>().listen((chatEvent) {
      _handleChatEvent(chatEvent);
    });
  }

  void _handleChatEvent(ChatReceiveUpdateRoomEvent event) {
    if (event.chatID == widget.session.sessionID) {
      _setTitleText();
    }
  }

  void _registerContactsEvent() {
    if (_session is ChatSession) {
      _contactSub = contactsEventBus.on<ContactsEvent>().listen((onData) {
        final device = onData.device;
        if ((onData.eventType == ContactsEventType.updateDevice ||
                onData.eventType == ContactsEventType.addDevice) &&
            onData.deviceID == _session.peerDeviceID &&
            device != null) {
          final updated = _session.peerIP != device.address ||
              _session.peerDeviceName != device.hostname;
          if (updated) {
            _session.peerDeviceName = device.hostname;
            _session.peerIP = device.address;
            if (mounted) {
              setState(() {
                // Update UI
              });
            }
          }
        }
      });
    }
  }

  Widget _peerDetail(ChatSession session, {bool withColumn = false}) {
    final peerIP = session.peerIP;
    final hostname = session.peerDeviceName;
    if (hostname == null) {
      final s = session.idShortString;
      return s != null ? Text(s, style: _small) : Container();
    }
    if (hostname == peerIP) {
      return Text(hostname, style: _small);
    }
    if (withColumn) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(hostname, style: _small),
          if (peerIP?.isNotEmpty ?? false) Text(peerIP!, style: _small),
        ],
      );
    }

    return Row(children: [
      Expanded(child: Text(peerIP ?? "", style: _small)),
      Text(hostname, style: _small),
    ]);
  }

  Widget get _userAvatar {
    final peerUser = _peerUser;
    return peerUser != null
        ? UserAvatar(
            key: Key(peerUser.name),
            size: 32,
            username: peerUser.name,
            userID: peerUser.id,
            enableUpdate: false,
          )
        : UserAvatar(
            size: 32,
            child: Icon(
              _session.defaultIcon ?? Icons.groups_rounded,
              size: 24,
            ),
          );
  }

  Widget get _userAvatarWithStatus {
    if (widget.session.status == SessionStatus.read) {
      return _userAvatar;
    }
    return Stack(
      children: <Widget>[
        _userAvatar,
        Positioned(
          right: 0,
          child: Container(
            padding: const EdgeInsets.all(1),
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(6),
            ),
            constraints: const BoxConstraints(minWidth: 12, minHeight: 12),
          ),
        ),
      ],
    );
  }

  Widget get _sessionTypeIcon {
    final icon = _session.sessionTypeIcon;
    return icon ?? Container();
  }

  Widget get _onlineStatus {
    final session = _session;
    if (session is ChatSession && _hasPeersReady) {
      return const Icon(
        Icons.online_prediction_rounded,
        color: Colors.green,
      );
    }
    return Container();
  }

  TextStyle? get _small {
    return smallTextStyle(context);
  }

  Widget get _firstRow {
    final tr = AppLocalizations.of(context);
    final session = _session;
    final style = Theme.of(context).textTheme.bodyMedium?.apply(
          fontWeightDelta: 3,
        );
    var title = _titleText;
    var type = session.localizedSessionType(tr);
    if (type != null) {
      title = _titleText.isNotEmpty ? '$type: $_titleText' : type;
    }
    final lastActionTime = session.lastActionTime;
    return Row(children: [
      Expanded(child: Text(title, style: style)),
      if (widget.size == null && lastActionTime != null)
        TimeText(time: lastActionTime, style: _small),
      if (session is ChatSession) _onlineStatus,
      if (session is! ChatSession) _sessionTypeIcon,
    ]);
  }

  Widget _subtitle({bool withColumn = false}) {
    final session = _session;
    if (session is ChatSession) {
      return _peerDetail(session, withColumn: withColumn);
    }
    return Container();
  }

  Widget? get _lastAction {
    final session = _session;
    if (session is ChatSession && session.lastChat != null) {
      return LastChat(
        key: Key(session.sessionID),
        session: session,
        onUpdate: () {
          setState(() {});
        },
      );
    }
    return null;
  }

  void _storePosition(TapDownDetails details) {
    _savedTapPosition = details.globalPosition;
  }

  void _longPressed() {
    if (widget.onLongPress != null) {
      widget.onLongPress?.call();
      return;
    }
    if (!widget.showPopupMenuOnLongPressed) {
      return;
    }
    _showPopupMenu();
  }

  PopupMenuItem<String> _menuItem(String value, IconData icon, String label) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: <Widget>[
          Icon(icon, size: 16),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }

  Widget _dialogMenuItem(String value, IconData icon, String label) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label, textAlign: TextAlign.center),
      onTap: () => Navigator.of(context).pop(value),
    );
  }

  Widget _popupMenuDialog(BuildContext context) {
    final tr = AppLocalizations.of(context);
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        alignment: Alignment.center,
        height: 200,
        width: 200,
        child: ListView(
          controller: ScrollController(),
          shrinkWrap: true,
          children: [
            if (widget.onEdit != null)
              _dialogMenuItem("edit", Icons.edit, tr.editText),
            _dialogMenuItem("delete", Icons.delete, tr.deleteText),
            _dialogMenuItem("json", Icons.code, "Show session data"),
          ],
        ),
      ),
    );
  }

  void _showPopupMenu() async {
    final tr = AppLocalizations.of(context);
    String? action;
    if (preferPopupMenuItemExpanded()) {
      action = await showDialog<String>(
        context: context,
        builder: _popupMenuDialog,
      );
    } else {
      action = await showMenu(
        context: context,
        position: getShowMenuPosition(
          context,
          _savedTapPosition,
          offset: getPopupMenuOffset(),
        )!,
        items: <PopupMenuEntry<String>>[
          if (widget.onEdit != null) _menuItem("edit", Icons.edit, tr.editText),
          _menuItem("delete", Icons.delete, tr.deleteText),
          //_menuItem("pin", Icons.push_pin, tr.pinText),
          _menuItem("json", Icons.code, "Show session data"),
        ],
      );
    }
    switch (action) {
      case "delete":
        if (!mounted) {
          return;
        }
        if (!(await showAlertDialog(context, tr.confirmDialogTitle,
                tr.confirmSessionDeleteMessageText,
                okText: tr.yesButton) ??
            false)) {
          // User cancelled deletion
          return;
        }
        // Call the delete callback
        widget.onDelete?.call();
        break;
      case "edit":
        widget.onEdit?.call();
        break;
      case "json":
        const JsonEncoder encoder = JsonEncoder.withIndent('  ');
        final prettyJson = encoder.convert(_session.toJson());
        if (mounted) {
          final size = MediaQuery.of(context).size;
          await showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(_titleText),
              content: Container(
                constraints: BoxConstraints(maxHeight: size.height * 0.6),
                child: SingleChildScrollView(
                  controller: ScrollController(),
                  padding: const EdgeInsets.all(16.0),
                  child: SelectableText(
                    prettyJson,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text("OK"),
                ),
              ],
            ),
          );
        }
        break;
      case "pin":
        if (mounted) {
          SnackbarWidget.w(tr.notYetImplementedMessageText).show(context);
        }
      default:
        break;
    }
  }

  Widget get sessionDetails {
    return Row(
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, right: 8),
          child: _userAvatarWithStatus,
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              //final withColumn = (constraints.maxWidth < 400);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _firstRow,
                  const SizedBox(height: 4),
                  _subtitle(withColumn: true),
                  if (_lastAction != null) _lastAction!,
                ],
              );
            },
          ),
        )
      ],
    );
  }

  double? get _height {
    var h = widget.size?.height;
    h = (_isTV && h != null) ? focusAwareSize(context, _focus, h) : h;
    return h == double.infinity ? null : h;
  }

  double? get _width {
    var w = widget.size?.width;
    w = _isTV && w != null ? focusAwareSize(context, _focus, w) : w;
    return w == double.infinity ? null : w;
  }

  ShapeBorder? get _shape {
    return (_isTV && widget.shape != null)
        ? focusAwareShapeBorder(widget.shape!, _focus)
        : widget.shape;
  }

  BoxDecoration? get _decoration {
    return (_isTV && widget.decoration != null)
        ? focusAwareDecoration(widget.decoration!, _focus)
        : widget.decoration;
  }

  bool get _showPopupMenuOnTap {
    return widget.showPopupMenuOnTap;
  }

  @override
  Widget build(BuildContext context) {
    final card = Card(
      shadowColor: widget.shadowColor,
      color: widget.color ?? Theme.of(context).cardColor,
      margin: const EdgeInsets.only(left: 8, right: 8, top: 4),
      shape: _shape,
      child: Container(
        constraints: const BoxConstraints(minHeight: 72),
        margin: widget.margin,
        height: _height,
        width: _width,
        decoration: _decoration,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            focusNode: _focus,
            focusColor: focusColor(context),
            hoverColor:
                isDarkMode(context) ? Colors.blueAccent : Colors.tealAccent,
            onTap: _showPopupMenuOnTap ? _showPopupMenu : widget.onTap,
            onSecondaryTap: _longPressed,
            onSecondaryTapDown: _storePosition,
            onLongPress: _longPressed,
            onTapDown: (details) {
              _storePosition(details);
              widget.onTapDown?.call(details);
            },
            child: Padding(
              padding: widget.padding ?? const EdgeInsets.all(8),
              child: sessionDetails,
            ),
          ),
        ),
      ),
    );
    return card;
  }
}
