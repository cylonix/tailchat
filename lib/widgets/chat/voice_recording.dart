// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:record/record.dart';

class VoiceRecording {
  final _record = AudioRecorder();
  late final String _path;
  VoiceRecording(String dir) {
    final ts = DateTime.now().microsecondsSinceEpoch;
    final name = '__voice_$ts.m4a';
    _path = p.join(dir, name);
  }

  Future<String?> start() async {
    try {
      if (await _record.hasPermission()) {
        final file = File(_path);
        await file.create(recursive: true);
        await _record.start(const RecordConfig(), path: _path);
      } else {
        return "No permission to record voice.";
      }
      return null;
    } catch (e) {
      return '$e';
    }
  }

  Future<String> stop() async {
    await _record.stop();
    return _path;
  }

  Future<bool> get isRecording async {
    return _record.isRecording();
  }
}
