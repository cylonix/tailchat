// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'dart:convert';
import 'package:flutter/material.dart';
import 'chat_id.dart';
import '../contacts/contacts_repository.dart';
import '../session.dart';

class ChatSession extends Session {
  final String? peerUserID;
  final String? peerDeviceID;
  final String? groupName;
  DateTime? lastChatTime; // local time
  String? lastChat;
  int? messageExpireInMs;
  String? peerDeviceName;
  String? peerIP;
  String? peerName;
  ChatSession({
    required super.sessionID,
    required super.selfUserID,
    super.createdAt,
    this.peerUserID,
    this.peerDeviceID,
    this.groupName,
    this.lastChat,
    this.lastChatTime,
    this.messageExpireInMs,
    this.peerDeviceName,
    this.peerIP,
    this.peerName,
    super.status,
    bool notificationOn = true,
  }) : super(
          type: SessionType.chat,
          name: groupName,
          isNotificationOn: notificationOn,
        );

  factory ChatSession.fromJson(Map<String, dynamic> json) {
    var selfUserID = json['self_user_id'];
    var peerUserID = json['peer_user_id'];
    var peerDeviceID = json['peer_device_id'];
    DateTime? lastChatTime, createdAt;
    if (json['last_chat_time'] != null) {
      final ms = json['last_chat_time'];
      lastChatTime = DateTime.fromMillisecondsSinceEpoch(ms);
    }
    if (json['created_at'] != null) {
      final ms = json['created_at'];
      createdAt = DateTime.fromMillisecondsSinceEpoch(ms);
    }

    return ChatSession(
      sessionID: json['session_id'],
      status: sessionStatusFromString(json['status']),
      createdAt: createdAt,
      notificationOn: json['is_notification_on'] ?? true,
      selfUserID: selfUserID,
      peerUserID: peerUserID,
      peerDeviceID: peerDeviceID,
      groupName: json['group_name'],
      lastChat: json['last_chat'],
      lastChatTime: lastChatTime,
      messageExpireInMs: json['message_expire_in_ms'],
      peerDeviceName: json['peer_device_name'],
      peerIP: json['peer_ip'],
      peerName: json['peer_name'],
    );
  }

  String get titleSync {
    final user = groupName ?? peerName;
    return '${user ?? ""} ${peerDeviceName ?? ""}';
  }

  @override
  bool contains(String text) {
    if (super.contains(text)) {
      return true;
    }
    return titleSync.contains(text);
  }

  @override
  Map<String, dynamic> toJson() {
    final m = {
      "peer_user_id": peerUserID,
      "peer_device_id": peerDeviceID,
      'group_name': groupName,
      "last_chat": lastChat,
      "last_chat_time": lastChatTime?.millisecondsSinceEpoch,
      "message_expire_in_ms": messageExpireInMs,
      "peer_device_name": peerDeviceName,
      "peer_ip": peerIP,
      "peer_name": peerName,
    };
    m.removeWhere((key, value) => value == null);
    m.addAll(super.toJson());
    return m;
  }

  @override

  /// Use toJson to encode into string for store et al. Keep toString() to be
  /// protected from leaking privacy or data like last chat.
  String toString() {
    final savedLastChat = lastChat;
    lastChat = "";
    // Don't show last chat in logs et al. where toString() is most likely
    // called.
    final str = jsonEncode(this);
    lastChat = savedLastChat;
    return str;
  }

  @override
  bool equal(Session? other) {
    if (other is ChatSession) {
      if (peerUserID != other.peerUserID) {
        return false;
      }
      return super.equal(other);
    }
    return false;
  }

  @override
  DateTime? get lastActionTime {
    return lastChatTime;
  }

  @override
  String? get idShortString {
    return ChatID(id: sessionID).shortString;
  }

  @override
  Widget? get sessionTypeIcon {
    return const Icon(Icons.chat_outlined, color: Colors.blue);
  }

  @override
  Future<String?> get title async {
    final chatID = ChatID(id: sessionID);
    if (chatID.isGroup) {
      final userCount = await chatID.groupChatUserCount;
      return "$groupName ($userCount)";
    }
    final contactsRepo = await ContactsRepository.getInstance();
    return (await contactsRepo.getContact(peerUserID))?.name ?? peerName;
  }
}
