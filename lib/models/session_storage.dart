// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'dart:convert';
import 'dart:io';
import 'package:event_bus/event_bus.dart';
import 'package:mutex/mutex.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../utils/global.dart';
import 'chat/chat_session.dart';
import 'session.dart';
import 'session_event.dart';

class SessionStorage {
  final String userID;

  String? _localPathCached;
  static final _mutex = Mutex();
  static final eventBus = EventBus();

  SessionStorage({required this.userID});

  @override
  String toString() {
    return 'SessionStorage object: userID=$userID cachedPath=$_localPathCached';
  }

  Future<String> get localPath async {
    final localPath = _localPathCached;
    if (localPath != null) {
      return localPath;
    }
    late final Directory directory;
    if (Platform.isAndroid || Platform.isLinux || Platform.isWindows) {
      directory = await getApplicationSupportDirectory();
    } else {
      directory = await getLibraryDirectory();
    }
    return directory.path;
  }

  Future<File> localFile() async {
    final root = await localPath;
    String path;
    path = p.join(root, 'cylonix', 'sessions', userID, 'sessions');
    Global.logger.d("sessions path is $path");
    // TODO: encrypt the file.
    return File(path).create(recursive: true);
  }

  Session _decode(String line) {
    final json = jsonDecode(line);
    final session = Session.fromJson(json);
    switch (session.type) {
      case SessionType.chat:
        return ChatSession.fromJson(json);
    }
  }

  Future<List<Session>> readSessions() async {
    return await _mutex.protect(() async {
      return await _readSessionsLocked();
    });
  }

  Future<List<Session>> _readSessionsLocked() async {
    try {
      final file = await localFile();
      final lines = await file.readAsLines();
      var sessions = <Session>[];

      // Since we write the last message to the end, we need to reverse it
      // to show the last one as the 1st at the bottom.
      for (var line in lines.reversed) {
        late Session session;
        if (line.isEmpty) {
          continue;
        }
        try {
          session = _decode(line);
        } catch (e) {
          Global.logger.e("failed to decode session $line: $e");
          continue;
        }
        // Skip older entry of the same session
        var found = false;
        for (var s in sessions) {
          if (s.equal(session)) {
            found = true;
            break;
          }
        }
        if (!found) {
          sessions.add(session);
        }
      }
      Global.logger.d("sessions read: ${sessions.length}");
      return sessions;
    } catch (e) {
      Global.logger.e("reading sessions file failed: $e");
      return [];
    }
  }

  Future<bool> removeSession(Session sessionToRemove) async {
    return await _mutex.protect(() async {
      return await _removeSessionLocked(sessionToRemove);
    });
  }

  Future<bool> _removeSessionLocked(Session sessionToRemove) async {
    Global.logger.d("removing session ${sessionToRemove.sessionID}");
    final sessions = await _readSessionsLocked();
    var newSessions = <Session>[];
    var toUpdate = false;
    for (var session in sessions.reversed) {
      if (session.equal(sessionToRemove)) {
        Global.logger.d("removed session ${session.sessionID}");
        toUpdate = true;
      } else {
        newSessions.add(session);
      }
    }
    if (toUpdate) {
      final sessionsString = newSessions.map((s) => jsonEncode(s)).join("\n");
      final file = await localFile();
      await file.writeAsString("$sessionsString\n", flush: true);
      return true;
    }
    return false;
  }

  Future<File> writeSession(Session session) async {
    await removeSession(session);
    final file = await localFile();
    // Append the message to file as a single line
    return await _mutex.protect(() async {
      return await file.writeAsString(
        '${jsonEncode(session)}\n',
        mode: FileMode.append,
        flush: true,
      );
    });
  }

  Future<bool> updateSession(Session sessionToUpdate) async {
    return await _mutex.protect(() async {
      return await _updateSessionLocked(sessionToUpdate);
    });
  }

  Future<bool> _updateSessionLocked(Session sessionToUpdate) async {
    final sessions = await _readSessionsLocked();
    var newSessions = <Session>[];
    var toUpdate = false;
    for (var session in sessions.reversed) {
      if (session.equal(sessionToUpdate)) {
        toUpdate = true;
        newSessions.add(sessionToUpdate);
      } else {
        newSessions.add(session);
      }
    }
    if (toUpdate) {
      return _saveSessionsLocked(newSessions);
    }
    return false;
  }

  Future<bool> _saveSessionsLocked(List<Session> sessions) async {
    try {
      final sessionsString = sessions.map((s) => jsonEncode(s)).join("\n");
      final file = await localFile();
      await file.writeAsString("$sessionsString\n", flush: true);
      return true;
    } catch (e) {
      Global.logger.e("write sessions failed: $e");
    }
    return false;
  }

  Future<bool> saveSessions(List<Session> sessions) async {
    final result = await _mutex.protect(() async {
      // Reverse sessions to have the top at the end.
      return _saveSessionsLocked(sessions.reversed.toList());
    });
    eventBus.fire(SessionsSavedEvent());
    return result;
  }
}
