// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:downloadsfolder/downloadsfolder.dart' as sse;
import 'ext_date_time.dart';
import 'api/status.dart';
import '../utils/global.dart';

class LogFile {
  final List<String> logs;
  final String name;
  LogFile({required this.logs, required this.name});

  String get _fileName {
    final now = DateTime.now().toLocal().toFilenameString();
    return '${name}_$now.txt';
  }

  /// Save the logs to a file.
  /// Caller to make sure saveFile is supported on the platform.
  Future<Status> save() async {
    if (logs.isEmpty) {
      return Status(false, "Log is empty. Skip saving to a file.");
    }

    // Save to document folder that's shared to other Apps for iOS.
    if (Platform.isIOS) {
      return _saveIOS();
    }
    if (Platform.isAndroid) {
      return _saveAndroid();
    }
    final result = await FilePicker.platform.saveFile(
      dialogTitle: "Choose the file to be saved",
      type: FileType.custom,
      fileName: _fileName,
      allowedExtensions: ["txt"],
    );

    if (result == null) {
      return Status.ok;
    }
    return _saveToPath(result);
  }

  Future<Status> _saveToPath(String path) async {
    final file = await File(path).create(recursive: true);
    await file.writeAsString(logs.join("\n"));
    return Status(true, path);
  }

  Future<Status> _saveIOS() async {
    final fileName = _fileName;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final path = p.join(dir.path, 'tailchat-logs', fileName);
      return _saveToPath(path);
    } catch (e) {
      return Status(false, '$e');
    }
  }

  Future<Status> _saveAndroid() async {
    final fileName = _fileName;
    try {
      final dir = await sse.getDownloadDirectory();
      final path = p.join(dir.path, 'Cylonix', 'cylonix-logs', fileName);
      return await _saveToPath(path);
    } catch (e) {
      return Status(false, '$e');
    }
  }

  Rect? _sharePositionOrigin(Size size) {
    if (!Platform.isIOS) {
      return null;
    }
    return Rect.fromLTWH(0, 0, size.width, size.height / 2);
  }

  /// Share the logs as a file.
  Future<String?> share(BuildContext context) async {
    if (logs.isEmpty) {
      return "Log is empty. Skip saving to a file.";
    }
    try {
      final size = MediaQuery.of(context).size;
      final status = await _saveIOS();
      if (!status.success) {
        throw Exception(status.msg);
      }
      Share.shareXFiles(
        [XFile(status.msg)],
        sharePositionOrigin: _sharePositionOrigin(size),
      );
    } catch (e) {
      return ('$e');
    }
    return null;
  }

  static get appLogFile {
    return LogFile(logs: Global.getAppBufferLogs(), name: "tailchat_app");
  }
}
