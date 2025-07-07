// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:uuid/uuid.dart';
import 'chat_storage.dart';
import '../contacts/device.dart';
import '../../api/config.dart';
import '../../api/contacts.dart';

class UserIDNotExistsException implements Exception {
  final String id;
  const UserIDNotExistsException(this.id);

  @override
  String toString() {
    return "User with ID '$id' does not exist";
  }
}

class DeviceIDNotExistsException implements Exception {
  final String id;
  const DeviceIDNotExistsException(this.id);

  @override
  String toString() {
    return "Device with ID '$id' does not exist";
  }
}

class ChatTypeNotSupportedException implements Exception {
  final String id;
  const ChatTypeNotSupportedException(this.id);

  @override
  String toString() {
    return "Chat type not supported. ID=$id";
  }
}

class ChatID {
  static const chatUser = "USER_CHAT";
  static const chatGroup = "GROUP_CHAT";

  final String id;
  ChatID({required this.id});
  factory ChatID.fromGroupName(String groupName) {
    // Allow id to be random so that group name can be edited.
    // To be able to show the different IDs of the same group name, we will
    // generate a V5 hash based ID so that we can do a shortString of it.
    final name = const Uuid().v4();
    final id = const Uuid().v5(Namespace.nil.value, name);
    return ChatID(id: '$chatGroup$id');
  }
  factory ChatID.fromTwoUserIDs({
    required String user1,
    required String user2,
    String? machine1,
    String? machine2,
  }) {
    var ids = [user1, user2];
    ids.sort();
    if (machine1 != null && machine2 != null) {
      final machines = [machine1, machine2];
      machines.sort();
      ids.addAll(machines);
    }
    final id = '$chatUser${ids.join("_")}';
    return ChatID(id: id);
  }

  String? get shortString {
    if (isGroup) {
      const start = chatGroup.length;
      return '[G${id.substring(start, start + 8)}]';
    }
    // Other chats don't have a short string
    return null;
  }

  List<String>? get userIDs {
    if (id.startsWith(chatUser)) {
      final userIDs = id.replaceFirst(chatUser, "").split('_');
      if (userIDs.length == 2 || userIDs.length == 4) {
        return userIDs.sublist(0, 2);
      }
    }
    return null;
  }

  Future<types.Room?> get room async {
    if (isNotGroup) return null;
    return ChatStorage(chatID: id).getRoom();
  }

  Future<String?> get chatGroupName async {
    return (await room)?.name;
  }

  Future<int?> get groupChatUserCount async {
    if (isNotGroup) return null;
    final room = await ChatStorage(chatID: id).getRoom();
    return room?.users.length;
  }

  bool get isGroup {
    return id.startsWith(chatGroup);
  }

  bool get isNotGroup {
    return !isGroup;
  }

  List<String>? get machines {
    if (id.startsWith(chatUser)) {
      final userIDs = id.replaceFirst(chatUser, "").split('_');
      if (userIDs.length == 4) {
        return userIDs.sublist(2);
      }
    }
    return null;
  }

  bool get isFromCurrentDevice {
    if (machines == null || userIDs == null) {
      return false;
    }
    final selfDevice = Pst.selfDevice?.id;
    return machines!.contains(selfDevice);
  }

  /// Null result means error
  Future<List<Device>?> get chatPeers async {
    var peers = <Device>[];
    List<String>? peerUserIDs;

    if (isGroup) {
      final r = await room;
      if (r == null) {
        return null;
      }
      peerUserIDs = r.users.map((u) => u.id).toList();
    } else {
      if (userIDs == null || userIDs?.length != 2) {
        return null;
      }
      final index = Pst.isSelfUser(userIDs![0]) ? 1 : 0;
      peerUserIDs = [userIDs![index]];
    }

    // Group chat or user chat
    if (machines == null) {
      for (var userID in peerUserIDs) {
        final user = await getContact(userID);
        if (user != null) {
          peers.addAll(user.devices);
        } else {
          throw UserIDNotExistsException(userID);
        }
      }
      return peers;
    }

    // Single device chat
    final devices = machines;
    if (devices != null &&
        userIDs != null &&
        devices.length == 2 &&
        userIDs?.length == 2) {
      for (var deviceID in devices) {
        if (Pst.isSelfDevice(deviceID)) {
          continue;
        }
        final peer = await getDevice(deviceID);
        if (peer != null) {
          peers.add(peer);
        } else {
          throw DeviceIDNotExistsException(deviceID);
        }
        return peers;
      }
    }
    throw ChatTypeNotSupportedException(id);
  }
}
