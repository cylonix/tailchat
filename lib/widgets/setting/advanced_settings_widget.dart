// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'dart:collection';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_logger/flutter_logger.dart' as log;
import 'package:logger/logger.dart';
import '../../api/chat_service.dart';
import '../../gen/l10n/app_localizations.dart';
import '../../models/log_file.dart';
import '../../utils/global.dart';
import '../../utils/logger.dart' as log;
import '../../utils/utils.dart';
import '../common_widgets.dart';
import '../snackbar_widget.dart';
import 'setting_app_bar.dart';

class AdvancedSettingsWidget extends StatefulWidget {
  final bool expanded;
  final bool showAppBar;
  const AdvancedSettingsWidget({
    super.key,
    this.expanded = false,
    this.showAppBar = true,
  });
  @override
  State<AdvancedSettingsWidget> createState() => _AdvancedSettingsWidgetState();
}

class _AdvancedSettingsWidgetState extends State<AdvancedSettingsWidget> {
  static final _logger = log.Logger(tag: "AdvancedSetting");
  List<String> _serviceLogs = [];

  LogFile get _appLogFile {
    return LogFile.appLogFile;
  }

  LogFile get _serviceLogFile {
    return LogFile(logs: _serviceLogs, name: "tailchat_service.log");
  }

  void _save(LogFile logFile) async {
    final tr = AppLocalizations.of(context);
    final status = await logFile.save();
    if (status.success) {
      if (status.msg.isNotEmpty) {
        // Empty message means action is cancelled.
        if (mounted) {
          SnackbarWidget.s("${tr.fileSavedToText} ${status.msg}").show(context);
        }
      }
    } else {
      if (mounted) {
        await showAlertDialog(
          context,
          "${tr.saveText} ${tr.failedText}",
          status.msg,
        );
      }
    }
  }

  void _share(LogFile logFile) async {
    final err = await logFile.share(context);
    if (err != null && mounted) {
      final tr = AppLocalizations.of(context);
      await showAlertDialog(context, "${tr.shareText} ${tr.failedText}", err);
    }
  }

  bool get _isDarkTheme {
    return Theme.of(context).brightness == Brightness.dark;
  }

  bool get _canShareFile {
    return !Platform.isWindows && !Platform.isLinux;
  }

  void _openFlutterLogConsole() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) {
        return log.LogConsole(
          dark: _isDarkTheme,
          showRefreshButton: true,
          saveFile: () => _save(_appLogFile),
          shareFile: _canShareFile ? () => _share(_appLogFile) : null,
        );
      }),
    );
  }

  Widget get _flutterLogConsole {
    final tr = AppLocalizations.of(context);
    Global.setLogConsoleLocalTexts(context);
    if (isApple()) {
      return CupertinoListTile(
        leading: getIcon(CupertinoIcons.doc, darkTheme: isDarkMode(context)),
        title: const Text("Show app diagnostic logs"),
        trailing: CupertinoListTileChevron(),
        onTap: _openFlutterLogConsole,
      );
    }
    return ListTile(
      title: Text(tr.showLog),
      subtitle: const Text("Show app diagnostic logs"),
      leading: getIcon(Icons.wysiwyg_rounded, darkTheme: isDarkMode(context)),
      trailing: _arrowForward,
      onTap: _openFlutterLogConsole,
    );
  }

  Widget get _arrowForward {
    return const Icon(Icons.arrow_forward_ios, size: 16);
  }

  void _openServiceLogConsole() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) {
        return log.LogConsole(
          dark: _isDarkTheme,
          title: "Service",
          subtitle: "Tailchat service log",
          showRefreshButton: true,
          getLogOutputEvents: _getChatServiceLogs,
          saveFile: () => _save(_serviceLogFile),
          shareFile: _canShareFile ? () => _share(_serviceLogFile) : null,
        );
      }),
    );
  }

  Widget get _serviceLogConsole {
    final tr = AppLocalizations.of(context);
    Global.setLogConsoleLocalTexts(context);
    if (isApple()) {
      return CupertinoListTile(
        title: Text(tr.showDaemonLog),
        subtitle: const Text("Show chat service diagnostic logs"),
        leading: getIcon(
          CupertinoIcons.doc_fill,
          darkTheme: isDarkMode(context),
        ),
        trailing: _arrowForward,
        onTap: _openServiceLogConsole,
      );
    }
    return ListTile(
      title: Text(tr.showDaemonLog),
      subtitle: const Text("Show chat service diagnostic logs"),
      leading: getIcon(Icons.terminal_rounded, darkTheme: isDarkMode(context)),
      trailing: _arrowForward,
      onTap: _openServiceLogConsole,
    );
  }

  Future<ListQueue<OutputEvent>> _getChatServiceLogs() async {
    ListQueue<OutputEvent> events = ListQueue();
    final timestampRegex = RegExp(r'^\[([\d\-]+T[\d:\.]+Z)\]');

    try {
      final logs = await ChatService.getLogs();
      _serviceLogs = logs.split('\n');

      LogEvent? currentLogEvent;
      List<String> currentLines = [];

      for (var line in _serviceLogs) {
        line = line.trim();
        if (line.isEmpty) continue;

        final timestampMatch = timestampRegex.firstMatch(line);

        if (Platform.isLinux || timestampMatch != null) {
          // New log entry starts
          if (currentLogEvent != null) {
            // Add previous log entry
            events.add(OutputEvent(currentLogEvent, currentLines));
            currentLines = [];
          }

          // Extract timestamp
          final timestamp = timestampMatch?.group(1)!;
          //line = line.substring(timestampMatch.end).trim();

          // Determine log level and clean up line
          var level = Level.info;
          if (line.contains("[FATAL]")) {
            level = Level.fatal;
            line = line.replaceAll("[FATAL]", "");
          } else if (line.contains("[ERROR]")) {
            level = Level.error;
            line = line.replaceAll("[ERROR]", "");
          } else if (line.contains("[WARNING]")) {
            level = Level.warning;
            line = line.replaceAll("[WARNING]", "");
          } else if (line.contains("[DEBUG]")) {
            level = Level.debug;
            line = line.replaceAll("[DEBUG]", "");
          } else {
            line = line.replaceAll("[INFO]", "");
          }

          // Create new log event
          currentLogEvent = LogEvent(
            level,
            "",
            time: timestamp != null ? DateTime.parse(timestamp) : null,
          );
          currentLines.add(line.trim());
        } else if (currentLogEvent != null) {
          // Continue previous log entry
          currentLines.add(line);
        }
      }

      // Add the last log entry
      if (currentLogEvent != null && currentLines.isNotEmpty) {
        events.add(OutputEvent(currentLogEvent, currentLines));
      }
    } catch (e) {
      _logger.e("Failed to get logs: $e");
    }
    return events;
  }

  List<Widget> get _settingsList {
    return [
      Card(
        child: Column(children: [
          _flutterLogConsole,
          _serviceLogConsole,
        ]),
      ),
    ];
  }

  Widget get _settingsListView {
    if (isApple()) {
      return CupertinoListSection.insetGrouped(
        margin: EdgeInsets.all(16),
        header: const Text("Inspect logs"),
        children: [
          _flutterLogConsole,
          _serviceLogConsole,
        ],
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(8),
      controller: ScrollController(),
      itemCount: _settingsList.length,
      itemBuilder: (_, index) => _settingsList[index],
      separatorBuilder: (context, index) => const SizedBox(height: 8),
    );
  }

  PreferredSizeWidget? get _appBar {
    if (!widget.showAppBar) {
      return null;
    }
    final tr = AppLocalizations.of(context);
    return SettingAppBar(context, tr.advancedSettingsTitle);
  }

  @override
  Widget build(BuildContext context) {
    if (isApple()) {
      final tr = AppLocalizations.of(context);
      return CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(
          middle: Text(tr.advancedSettingsTitle),
        ),
        child: Container(
          padding: const EdgeInsets.only(
            top: 80,
            right: 16,
            left: 16,
            bottom: 32,
          ),
          child: _settingsListView,
        ),
      );
    }
    return Scaffold(
      appBar: _appBar,
      body: Container(
        alignment: Alignment.topLeft,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800),
          child: _settingsListView,
        ),
      ),
    );
  }
}
