// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'dart:convert';
import 'dart:io';

import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:mutex/mutex.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/parsing.dart';
import 'package:uuid/uuid.dart';
import '../../utils/global.dart';
import '../../utils/utils.dart';
import '../../api/config.dart';
import '../api/status.dart';
import 'chat_message.dart';

/// todo:
///   Use SQLite for storage. Please refer to the following:
///   https://pub.dev/packages/sqflite_common_ffi
class ChatStorage {
  final String chatID;

  static String? _appDocPathCached;
  static String? _appExternalPathCached;
  String? _chatPathCached;
  types.Room? _room;
  static final _mutexMap = <String, Mutex>{};

  Mutex get _mutex {
    var m = _mutexMap[chatID];
    if (m == null) {
      m = Mutex();
      _mutexMap[chatID] = m;
    }
    return m;
  }

  ChatStorage({required this.chatID});

  static Future<String> get _appDocPath async {
    var appDocPath = _appDocPathCached;
    if (appDocPath != null) {
      return appDocPath;
    }
    late final Directory directory;
    directory = await getApplicationDocumentsDirectory();
    appDocPath = directory.path;
    _appDocPathCached = appDocPath;
    return appDocPath;
  }

  Future<String> get _chatPath async {
    var chatPath = _chatPathCached;
    if (chatPath != null) {
      return chatPath;
    }
    chatPath = path.join(await _appDocPath, _chatRelativePath);
    _chatPathCached = chatPath;
    return chatPath;
  }

  /// For android use external storage that the application can access without
  /// requesting the grant of the external storage management permission.
  static Future<String> get _appExternalPath async {
    if (!Platform.isAndroid) {
      return _appDocPath;
    }
    var appExternalPath = _appExternalPathCached;
    if (appExternalPath != null) {
      return appExternalPath;
    }
    appExternalPath = (await getExternalStorageDirectory())!.path;
    _appExternalPathCached = appExternalPath;
    return appExternalPath;
  }

  static String get _chatFilesRelativePath {
    final userID = Pst.selfUser!.id;
    return path.join("tailchat", userID, 'files');
  }

  String get _chatRelativePath {
    final id = const Uuid().v5(Namespace.nil.value, chatID);
    final userID = Pst.selfUser!.id;
    return path.join("tailchat", userID, 'c$id');
  }

  Future<File> get _messagesFile async {
    final chatPath = await _chatPath;
    final filePath = path.join(chatPath, "messages");
    // todo: encrypt the file.
    return File(filePath).create(recursive: true);
  }

  Future<String> get messagesFilePath async {
    final chatPath = await _chatPath;
    return path.join(chatPath, "messages");
  }

  Future<File> get _roomInfoFile async {
    final chatPath = await _chatPath;
    final filePath = path.join(chatPath, "room");
    return File(filePath).create(recursive: true);
  }

  Future<types.Room?> getRoom() async {
    if (_room != null) {
      return _room;
    }
    final file = await _roomInfoFile;
    try {
      final roomStr = await file.readAsString();
      _room = types.Room.fromJson(json.decode(roomStr));
    } catch (e) {
      Global.logger.e("failed to read room info from storage ${file.path}");
    }
    return _room;
  }

  Future<void> saveRoom(types.Room room) async {
    _room = room;
    final file = await _roomInfoFile;
    final roomStr = jsonEncode(room);
    await file.writeAsString(roomStr, flush: true);
  }

  static String getFileRelativeUri(String filename) {
    return path.join("tailchat", filename);
    //return path.join(_chatFilesRelativePath, filename);
  }

  static Future<String> get chatFilesDir async {
    return path.join(await _appExternalPath, _chatFilesRelativePath);
  }

  static Future<String> getFileAbsolutePath(String filename) async {
    return getAbsolutePath(getFileRelativeUri(filename));
  }

  static Future<String?> getFileMessageUri(String? filename) async {
    if (filename == null) {
      return null;
    }
    if (ChatMessage.needToCopyFile) {
      return getFileRelativeUri(filename);
    }
    return getFileAbsolutePath(filename);
  }

  static const String messageIDDelimiterInFilename = "..";
  static String filenameWithMessageID(String messageID, String filename) {
    if (filename.startsWith(messageID)) {
      return filename;
    }
    return '$messageID$messageIDDelimiterInFilename$filename';
  }

  static String? getMessageIDFromFilename(String filename) {
    final l = filename.split(messageIDDelimiterInFilename);
    if (l.length > 1) {
      final id = l[0];
      try {
        UuidParsing.parse(id);
        // Valid UUID as a message ID.
        return id;
      } catch (_) {
        // ignore.
      }
    }
    return null;
  }

  /// Relative URI from the app doc directory for the file of a message.
  /// This is used for platform like iOS where the absolute path changes with
  /// every launch/installation.
  static String getMessageFileRelativeUri(String messageID, String filename) {
    final f = filenameWithMessageID(messageID, filename);
    return path.join(_chatFilesRelativePath, f);
  }

  /// Get the absolute path from relative path.
  static Future<String> getAbsolutePath(String relativePath) async {
    if (Platform.isLinux) {
      // TODO: move file to user doc dir so that it can be modified by user.
      return path.join("/var/lib/tailchat", relativePath);
    }

    return path.join(await _appDocPath, relativePath);
    //return path.join(await _appExternalPath, relativePath);
  }

  Future<List<types.Message>> readMessages() async {
    return await _mutex.protect(() async {
      return await _readMessagesLocked(await _messagesFile);
    });
  }

  Future<List<types.Message>> _readMessagesLocked(File file) async {
    late final List<String> lines;
    try {
      lines = await file.readAsLines();
    } catch (e) {
      // Delete the file if it fails to read.
      Global.logger.e("failed to read message file: $e");
      await file.delete();
      return [];
    }
    try {
      var messages = <types.Message>[];
      Map<String, bool> idMap = {};

      // Since we write the last message to the end, we need to reverse it
      // for chat plugin to show the last one as the 1st at the bottom
      // (twisting eh;)
      for (var line in lines.reversed) {
        try {
          final message = types.Message.fromJson(jsonDecode(line));
          final id = message.id;
          if (idMap[id] ?? false) {
            Global.logger
                .w("duplicate message $id ${message.summary.shortRunes(5)}");
            continue;
          }
          idMap[id] = true;
          messages.add(message);
        } catch (e) {
          Global.logger.e("failed to decode message $line: $e");
        }
      }
      return messages;
    } catch (e) {
      Global.logger.e("reading message file ${file.path} failed: $e");
      return [];
    }
  }

  Future<File?> appendMessage(types.Message message) async {
    final file = await _messagesFile;
    return await _mutex.protect(() async {
      try {
        // Append the message to file as a single line
        return await file.writeAsString(
          '${jsonEncode(message)}\n',
          mode: FileMode.append,
          flush: true,
        );
      } catch (e) {
        Global.logger.e("failed to append message: $e");
      }
      return null;
    });
  }

  /// To avoid race conditions of wiping out the whole message file. DO NOT
  /// make this method public.
  Future<File?> _writeMessagesLocked(List<types.Message> messages) async {
    var file = await _messagesFile;
    file = await file.writeAsString("", flush: true);
    try {
      for (var message in messages.reversed) {
        file = await file.writeAsString(
          '${jsonEncode(message)}\n',
          mode: FileMode.append,
          flush: true,
        );
      }
      return file;
    } catch (e) {
      Global.logger.e("failed to write message: $e");
      return null;
    }
  }

  /// Updates a message in the file base on its message id.
  /// Probably should use a sqlite db instead. Otherwise this update is going
  /// to be very costly and error prone.
  Future<List<types.Message>?> updateMessage(types.Message message) async {
    return await _mutex.protect(() async {
      return await _updateMessageLocked(message);
    });
  }

  Future<List<types.Message>?> _updateMessageLocked(
    types.Message message,
  ) async {
    List<types.Message> messages = [];
    final file = await _messagesFile;
    var updated = false;

    try {
      messages = await _readMessagesLocked(file);
      for (int i = 0; i < messages.length; i++) {
        if (messages[i].id == message.id) {
          messages[i] = message;
          updated = true;
          break;
        }
      }
      if (updated) {
        await _writeMessagesLocked(messages);
      }
    } catch (e) {
      Global.logger.e("failed to update messages: $e");
    }
    Global.logger.d("update=$updated messages[${messages.length}]");
    return updated ? messages : null;
  }

  /// Removes a message in the file base on its message id.
  /// Probably should use a sqlite db instead. Otherwise this is going
  /// to be very costly and error prone.
  Future<List<types.Message>?> removeMessage(String messageID) async {
    return await _mutex.protect(() async {
      return await _removeMessagesLocked([messageID]);
    });
  }

  Future<List<types.Message>?> _removeMessagesLocked(
    List<String> messageIDs,
  ) async {
    final file = await _messagesFile;
    List<types.Message> messages = [];
    var updated = false;
    try {
      messages = await _readMessagesLocked(file);
      messages.removeWhere((element) {
        final ret = messageIDs.contains(element.id);
        if (ret) {
          updated = true;
        }
        return ret;
      });
      if (updated) {
        await _writeMessagesLocked(messages);
      }
    } catch (e) {
      Global.logger.e("failed to remove: $e");
    }
    Global.logger.d("update=$updated messages[${messages.length}]");
    return updated ? messages : null;
  }

  Future<Status> deleteMessagesFile({bool deleteFiles = true}) async {
    return await _mutex.protect(() async {
      try {
        final file = await _messagesFile;
        await file.delete();
        if (deleteFiles) {
          final filesDir = Directory(await chatFilesDir);
          if (await filesDir.exists()) {
            await filesDir.delete(recursive: true);
          }
        }
        return Status.ok;
      } catch (e) {
        return Status(false, '$e');
      }
    });
  }

  Future<List<types.Message>?> removeMessages(List<String> messageIDs) async {
    return await _mutex.protect(() async {
      return await _removeMessagesLocked(messageIDs);
    });
  }
}
