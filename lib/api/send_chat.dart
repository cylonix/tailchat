// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;

import '../models/api/status.dart';
import '../models/chat/chat_send_peers_result.dart';
import '../models/chat/chat_storage.dart';
import '../models/contacts/device.dart';
import '../models/chat/chat_event.dart';
import '../models/contacts/user_profile.dart';
import '../models/progress_change_event.dart';
import '../utils/logger.dart';
import 'chat_server.dart';
import 'chat_service.dart';
import 'config.dart';
import 'contacts.dart';

final _logger = Logger(tag: "send_chat");
final _chatServiceMap = <String, ChatService>{};

ChatService _getChatServiceForDevice(Device device) {
  final id = device.id;
  if (id == "") {
    throw Exception("invalid null peer id");
  }
  var s = _chatServiceMap[id];
  if (s == null) {
    s = ChatService(
      serverAddress: device.hostname,
      userID: device.userID,
      deviceID: device.id,
    );
    _chatServiceMap[id] = s;
  }
  return s;
}

Future<Status> sendPingToPeer(Device peer) async {
  try {
    final s = _getChatServiceForDevice(peer);
    await s.sendPing();
    return Status.ok;
  } catch (e) {
    return Status.fail(msg: "Failed to send ping to peer: $e");
  }
}

Future<ChatSendPeersResult> tryConnectToPeers(List<Device> peers) async {
  var futures = <Future<Status>>[];
  for (var peer in peers) {
    futures.add(sendPingToPeer(peer));
  }
  _logger.d("sent ping out to peers. waiting for responses...");
  final statusList = await Future.wait(futures);
  _logger.d("got results back. now analyze...");
  return _toChatSendPeersResult(statusList, peers);
}

/// Send message to the listening socket on peer directly.
Future<Status> sendPeerMessage({
  required Device peer,
  required String? chatID,
  required String message,
  int? timeoutSeconds,
}) async {
  try {
    final self = Pst.selfDevice;
    if (self == null) {
      throw Exception("invalid self device");
    }
    final s = _getChatServiceForDevice(peer);
    await s.sendMessage(jsonEncode({
      'chat_id': chatID,
      'machine': self.id,
      'message': message,
    }));
  } catch (e) {
    _logger.e("Failed to send peer message: $e");
    return Status.fail(msg: "Failed to send peer message: $e");
  }
  _logger.d("send peer message to chat service success!");
  return Status.ok;
}

/// Send a file as a raw stream (not multipart) to peer.
Future<Status> sendPeerFile({
  required Device peer,
  required String chatID,
  required String uri,
  required String filename,
  required types.Message messageObj,
  int? timeoutSeconds, // Not yet supported.
}) async {
  try {
    final f = ChatStorage.filenameWithMessageID(messageObj.id, filename);
    final s = _getChatServiceForDevice(peer);
    final eventBus = ChatServer.getChatEventBus();
    final start = DateTime.now();
    await s.sendFile(File(uri),
        filename: f,
        onProgress: ((bytes, total) => eventBus.fire(ProgressChangeEvent(
              chatID: chatID,
              messageID: messageObj.id,
              peer: peer.hostname,
              bytes: bytes,
              total: total,
              time: DateTime.now().difference(start).inMilliseconds,
            ))));
  } catch (e) {
    _logger.e("Failed to send peer message: $e");
    return Status.fail(msg: "Failed to send peer message: $e");
  }
  return Status.ok;
}

/// Send peer file first and then message
Future<Status> sendPeerMessageWithFile({
  required Device peer,
  required String chatID,
  required String message,
  String? fileUri,
  String? filename,
  required types.Message messageObj,
  int? timeoutSeconds,
}) async {
  var status = await sendPeerMessage(
    peer: peer,
    chatID: chatID,
    message: message,
    timeoutSeconds: timeoutSeconds,
  );
  if (!status.success) {
    return status;
  }
  if (fileUri != null) {
    status = await sendPeerFile(
      peer: peer,
      chatID: chatID,
      uri: fileUri,
      filename: filename!,
      messageObj: messageObj,
      timeoutSeconds: timeoutSeconds,
    );
  }
  return status;
}

/// Collect the list send peer failures.
ChatSendPeersResult _toChatSendPeersResult(
  List<Status> statusList,
  List<Device> peers,
) {
  int i = 0;
  int s = 0;
  int f = 0;
  var failurePeersInfo = <String>[];
  var successPeersInfo = <String>[];
  var statusMap = <String, bool>{};
  var successUserMap = <String, bool>{};
  for (var status in statusList) {
    final peer = peers[i];
    final addr = peer.address;
    final msg = status.msg;
    final idx = status.success ? s + 1 : f + 1;
    final info = '$idx. $addr ${peer.hostname}: $msg';
    statusMap[peer.id] = status.success;
    if (status.success) {
      successPeersInfo.add(info);
      successUserMap[peer.userID] = true;
      s++;
    } else {
      failurePeersInfo.add(info);
      f++;
    }
    i++;
  }
  final successMsg = s > 0 ? successPeersInfo.join("\n") : null;
  final failureMsg = f > 0 ? failurePeersInfo.join("\n") : null;
  return ChatSendPeersResult(
    success: f == 0,
    successCnt: s,
    failureCnt: f,
    successUserCnt: successUserMap.length,
    statusMap: statusMap.isNotEmpty ? statusMap : null,
    successMsg: successMsg,
    failureMsg: failureMsg,
  );
}

/// Send message to peers
Future<ChatSendPeersResult> sendPeersMessage(
  String chatID,
  String message,
  String? fileUri,
  String? filename,
  List<Device> peers,
  types.Message messageObj, {
  int? timeoutSeconds,
}) async {
  var futures = <Future<Status>>[];
  for (var peer in peers) {
    futures.add(sendPeerMessageWithFile(
      peer: peer,
      chatID: chatID,
      message: message,
      fileUri: fileUri,
      filename: filename,
      messageObj: messageObj,
      timeoutSeconds: timeoutSeconds,
    ));
  }
  _logger.d("sent message out to peers. waiting for responses...");
  final statusList = await Future.wait(futures);
  _logger.d("got results back. now analyze...");
  return _toChatSendPeersResult(statusList, peers);
}

/// Send new or update room information to peers
Future<Status> sendPeerRoom({
  required Device peer,
  required String chatID,
  String method = "POST",
  types.Room? room,
}) async {
  try {
    final body = jsonEncode({
      "room_request": true,
      "chat_id": chatID,
      'method': method,
      "room": room,
    });
    _logger.i('send room message to ${peer.hostname}: $body');
    final status = await sendPeerMessage(
      peer: peer,
      chatID: chatID,
      message: body,
    );
    if (!status.success) {
      throw Exception(status.toString());
    }
    return status;
  } catch (e) {
    _logger.e("send peer room failed with err: $e");
    return Status(false, "exception: $e");
  }
}

/// Get room information from peer
Future<types.Room?> getRoom(
  String chatID,
  Device peer,
) async {
  final selfUser = Pst.selfUser;
  final selfStatus = Pst.selfDevice;
  if (selfStatus == null || selfUser == null) {
    _logger.e("self user or device does not exit");
    return null;
  }
  final completer = Completer<types.Room?>();
  final sub = ChatServer.getChatEventBus()
      .on<ChatReceiveRoomEvent>()
      .listen((event) => completer.complete(event.room));
  try {
    final status =
        await sendPeerRoom(peer: peer, chatID: chatID, method: "GET");
    if (!status.success) {
      return null;
    }
    return await completer.future.timeout(const Duration(seconds: 5));
  } catch (e) {
    _logger.e("failed to get room: $e");
  } finally {
    sub.cancel();
  }
  return null;
}

/// Send new or updated room information to peers
Future<ChatSendPeersResult> sendRoom(
  types.Room room,
  List<UserProfile> users, {
  bool isUpdate = false,
}) async {
  final selfStatus = Pst.selfDevice;
  if (selfStatus == null) {
    return ChatSendPeersResult(
      success: false,
      failureMsg: "self status does not exist",
    );
  }
  var futures = <Future<Status>>[];
  var peers = <Device>[selfStatus]; // Need one copy for self.
  for (var user in users) {
    final userPeers = await getUserDevices(user.id);
    if (userPeers == null) {
      _logger.d("user ${user.name} has no peer");
      continue;
    }
    var sent = false;
    for (var peer in userPeers) {
      if (peer.isAvailable) {
        sent = true;
        peers.add(peer);
      }
    }
    if (!sent) {
      _logger.d("user ${user.name} has no chat available peer");
    }
  }
  for (var peer in peers) {
    futures.add(sendPeerRoom(
      chatID: room.id,
      method: isUpdate ? "PATCH" : "POST",
      peer: peer,
      room: room,
    ));
  }
  _logger.d("sent room out to peers. wating for resonses...");
  final statusList = await Future.wait(futures);
  _logger.d("got results back. now analyze... $statusList");
  return _toChatSendPeersResult(statusList, peers);
}
