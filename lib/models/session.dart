// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'dart:convert';

import 'package:flutter/material.dart';
import '../gen/l10n/app_localizations.dart';

enum SessionType {
  chat,
}

String sessionTypeToString(SessionType? type) {
  final strList = type.toString().split('.');
  if (strList.length <= 1) {
    return SessionType.chat.toString().split('.')[1];
  }
  return strList[1];
}

SessionType sessionTypeFromString(String? value) {
  return SessionType.values
      .firstWhere((e) => e.name == value, orElse: () => SessionType.chat);
}

String? sessionTypeToLocalizedString(
  SessionType sessionType,
  AppLocalizations tr,
) {
  switch (sessionType) {
    case SessionType.chat:
      return tr.chatText;
  }
}

IconData? sessionTypeToIcon(SessionType sessionType) {
  switch (sessionType) {
    case SessionType.chat:
      return Icons.chat_bubble_rounded;
  }
}

enum SessionStatus {
  read,
  unread,
}

String sessionStatusToString(SessionStatus? status) {
  final strList = status.toString().split('.');
  if (strList.length <= 1) {
    return SessionStatus.read.toString().split('.')[1];
  }
  return strList[1];
}

SessionStatus sessionStatusFromString(String? value) {
  return SessionStatus.values
      .firstWhere((e) => e.name == value, orElse: () => SessionStatus.read);
}

class Session {
  final String sessionID;
  final String selfUserID;
  final String? name;
  final SessionType type;
  final DateTime? createdAt; // local time
  SessionStatus? status;
  bool isNotificationOn;
  Session({
    required this.sessionID,
    required this.type,
    required this.selfUserID,
    this.name,
    this.createdAt,
    this.status,
    this.isNotificationOn = true,
  });

  factory Session.fromJson(Map<String, dynamic> json) {
    var selfUserID = json['self_user_id'];
    DateTime? createdAt;
    if (json['created_at'] != null) {
      final ms = json['created_at'];
      createdAt = DateTime.fromMillisecondsSinceEpoch(ms);
    }

    return Session(
      selfUserID: selfUserID,
      type: sessionTypeFromString(json["type"]),
      sessionID: json['session_id'],
      status: sessionStatusFromString(json['status']),
      createdAt: createdAt,
      isNotificationOn: json['is_notification_on'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    final m = {
      "session_id": sessionID,
      "self_user_id": selfUserID,
      "type": sessionTypeToString(type),
      "name": name,
      "status": sessionStatusToString(status),
      "created_at": createdAt?.millisecondsSinceEpoch,
      "is_notification_on": isNotificationOn,
    };
    return m;
  }

  @override
  String toString() {
    return jsonEncode(this);
  }

  bool contains(String text) {
    return toString().toLowerCase().contains(text.toLowerCase());
  }

  bool equal(Session? other) {
    return sessionID == other?.sessionID && selfUserID == other?.selfUserID;
  }

  DateTime? get lastActionTime {
    return null;
  }

  String? get idShortString {
    return null;
  }

  IconData? get defaultIcon {
    return null;
  }

  Widget? get sessionTypeIcon {
    return null;
  }

  Future<String?> get title async {
    return null;
  }

  String? localizedSessionType(AppLocalizations tr) {
    return null;
  }

  @override
  int get hashCode => Object.hash(sessionID, selfUserID);

  @override
  bool operator ==(Object other) {
    if (other is Session) {
      return equal(other);
    }
    return false;
  }
}
