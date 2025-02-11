// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'dart:io';
import 'dart:ui';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import '../../api/config.dart';
import '../../api/chat_server.dart';
import '../../utils/global.dart';
import '../contacts/user_profile.dart';
import 'chat_event.dart';
import 'chat_storage.dart';

/// Encapsulate flutter chat message
class ChatMessage {
  String chatID;
  String? originalPath;
  types.Message message;
  ChatMessage({required this.chatID, required this.message, this.originalPath});

  static types.User toAuthor(UserProfile up, {types.Role? role}) {
    return types.User(
      id: up.id,
      firstName: up.name,
      imageUrl: up.profileUrl,
      createdAt: up.createdAt,
      role: role,
    );
  }

  static types.User? selfToAuthor({types.Role? role}) {
    final selfUser = Pst.selfUser;
    if (selfUser != null) {
      return toAuthor(selfUser);
    }
    return null;
  }

  static String newMessageID() {
    return const Uuid().v4();
  }

  factory ChatMessage.fromFile(
    String chatID,
    String path,
    int size, {
    Image? image,
    UserProfile? up,
    types.User? user,
    String? caption,
    String? replyId,
    double? height,
    double? width,
    bool isEmoji = false,
  }) {
    late types.Message message;
    final messageID = newMessageID();
    final name = p.basename(path);
    final newPath = _fixFilePath(chatID, messageID, name);
    user ??= toAuthor(up!);
    if (image != null) {
      message = types.ImageMessage(
        author: user,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        height: height ?? image.height.toDouble(),
        width: width ?? image.width.toDouble(),
        id: messageID,
        name: name,
        size: size,
        caption: caption,
        replyId: replyId,
        uri: newPath ?? path,
        status: types.Status.toretry,
        isEmoji: isEmoji,
      );
    } else {
      message = types.FileMessage(
        author: user,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        id: messageID,
        name: name,
        size: size,
        caption: caption,
        replyId: replyId,
        mimeType: lookupMimeType(path),
        uri: newPath ?? path,
        status: types.Status.toretry,
      );
    }
    return ChatMessage(chatID: chatID, message: message, originalPath: path);
  }

  factory ChatMessage.fromText(
    String chatID,
    String text, {
    UserProfile? up,
    types.User? user,
    String? caption,
    String? replyId,
  }) {
    final message = types.TextMessage(
      author: user ?? toAuthor(up!),
      createdAt: DateTime.now().millisecondsSinceEpoch,
      id: newMessageID(),
      caption: caption,
      replyId: replyId,
      text: text,
      status: types.Status.toretry,
    );
    return ChatMessage(chatID: chatID, message: message);
  }

  factory ChatMessage.fromEmoji(
    String chatID,
    String text, {
    UserProfile? up,
    types.User? user,
    String? caption,
    String? replyId,
  }) {
    final message = types.EmojiMessage(
      author: user ?? toAuthor(up!),
      createdAt: DateTime.now().millisecondsSinceEpoch,
      id: newMessageID(),
      caption: caption,
      replyId: replyId,
      text: text,
      status: types.Status.toretry,
    );
    return ChatMessage(chatID: chatID, message: message);
  }

  factory ChatMessage.copyFrom(
    String chatID,
    types.Message fromMessage, {
    UserProfile? up,
    types.User? user,
  }) {
    final messageID = newMessageID();
    var message = fromMessage.copyWith(
      id: messageID,
      status: types.Status.toretry,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
      author: user ?? toAuthor(up!),
    );
    return ChatMessage(chatID: chatID, message: message);
  }

  factory ChatMessage.videoCall(
    String chatID,
    UserProfile from,
    int peerUserID,
    String server,
    String room, {
    String command = "dial",
    bool accept = false,
    String? bookTime,
    String? note,
  }) {
    final message = types.CustomMessage(
      author: toAuthor(from),
      createdAt: DateTime.now().millisecondsSinceEpoch,
      id: newMessageID(),
      metadata: {
        "sub_type": "Video Call",
        "server": server,
        "room": room,
        "from": from.id,
        "from_user": from.name,
        "peer": peerUserID,
        "command": command,
        "accept": accept,
        "book_time": bookTime,
        "notes": note,
      },
      status: types.Status.toretry,
    );
    return ChatMessage(chatID: chatID, message: message);
  }

  Future<void> save() async {
    await ChatStorage(chatID: chatID).appendMessage(message);
  }

  void notify() {
    Global.logger.d("notifying message ${message.id}");
    ChatServer.getChatEventBus().fire(ChatAddEvent(
      chatID: chatID,
      message: message,
      originalPath: originalPath,
    ));
  }

  static bool get needToCopyFile {
    return (Platform.isIOS || Platform.isMacOS);
  }

  static String? _fixFilePath(String chatID, String messageID, String name) {
    if (!needToCopyFile) {
      return null;
    }
    return ChatStorage.getMessageFileRelativeUri(messageID, name);
  }

  /// Exception will be thrown if file copy fails.
  /// Returns false if there is no file copy needed.
  Future<bool> copyFile(String path) async {
    if (!needToCopyFile) {
      return false;
    }
    final newPath = message.uri;
    if (newPath != null && newPath != path) {
      final file = File(path);
      final absolutePath = await ChatStorage.getAbsolutePath(newPath);
      if (absolutePath == path) {
        return false;
      }
      await File(absolutePath).create(recursive: true);
      await file.copy(absolutePath);
      Global.logger.d("File has been copied from $path to $newPath");
      return true;
    }
    return false;
  }
}
