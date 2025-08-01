// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import '../../api/chat_service.dart';

class ChatEvent {
  final String chatID;
  final types.Message message;

  ChatEvent({
    required this.chatID,
    required this.message,
  });
}

class ChatAddEvent extends ChatEvent {
  String? originalPath;
  ChatAddEvent({
    required super.chatID,
    required super.message,
    this.originalPath,
  });
}

class ChatReceiveEvent extends ChatEvent {
  final String machine;

  ChatReceiveEvent({
    required super.chatID,
    required this.machine,
    required super.message,
  });
}

class ChatSendEvent extends ChatEvent {
  ChatSendEvent({
    required super.chatID,
    required super.message,
  });
}

class ChatRoomEvent {
  final String chatID;
  types.Room? room;

  ChatRoomEvent({
    required this.chatID,
    this.room,
  });
}

class ChatReceiveRoomEvent extends ChatRoomEvent {
  ChatReceiveRoomEvent({
    required super.chatID,
    super.room,
  });
}

class ChatReceiveNewRoomEvent extends ChatReceiveRoomEvent {
  final String machine;
  ChatReceiveNewRoomEvent({
    required super.chatID,
    required this.machine,
    required super.room,
  });
}

class ChatReceiveUpdateRoomEvent extends ChatReceiveRoomEvent {
  String? machine;
  ChatReceiveUpdateRoomEvent({
    required super.chatID,
    this.machine,
    required super.room,
  });
}

class ChatSimpleUISettingChangeEvent {
  final bool enable;
  ChatSimpleUISettingChangeEvent({required this.enable});
}

abstract class ChatReceiveNetworkEvent {}

class ChatReceiveNetworkConfigEvent extends ChatReceiveNetworkEvent {
  final String? address;
  final String? hostname;
  final int? port;
  final int? subscriberPort;
  final bool isPhysical;
  ChatReceiveNetworkConfigEvent({
    this.address,
    this.hostname,
    this.port,
    this.subscriberPort,
    this.isPhysical = false,
  });

  @override
  String toString() {
    return "hostname=$hostname port=$port";
  }
}

class ChatReceiveNetworkAvailableEvent extends ChatReceiveNetworkEvent {
  final bool available;
  ChatReceiveNetworkAvailableEvent(this.available);

  @override
  String toString() {
    return "available=$available";
  }
}

enum ChatServiceState {
  connected,
  connecting,
  disconnected,
}

class ChatServiceStateEvent {
  final ChatServiceSender? from;
  final String? userID;
  final String? deviceID;
  final ChatServiceState state;
  final String? error;
  final bool isSelfDevice;
  ChatServiceStateEvent({
    this.from,
    this.userID,
    this.deviceID,
    this.error,
    this.state = ChatServiceState.disconnected,
    this.isSelfDevice = false,
  });

  @override
  String toString() {
    return "${from?.address}:${from?.port} -> ${state.name}";
  }
}

class ChatSocketReceiveDataEvent {
  final String line;
  ChatSocketReceiveDataEvent({required this.line});
}

class ChatSharingEvent {
  final String text;
  final List<String> urls;
  final List<String> files;
  const ChatSharingEvent({
    this.text = '',
    this.urls = const [],
    this.files = const [],
  });
}
