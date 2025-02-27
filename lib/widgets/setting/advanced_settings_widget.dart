// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'dart:collection';
import 'dart:io';

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

  LogFile get _appLogFile {
    return LogFile.appLogFile;
  }

  LogFile get _cylonixdLogFile {
    return LogFile.cylonixdLogFile;
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

  Widget get _flutterLogConsole {
    final tr = AppLocalizations.of(context);
    Global.setLogConsoleLocalTexts(context);
    return ListTile(
      title: Text(tr.showLog),
      subtitle: const Text("Show app diagnostic logs"),
      leading: getIcon(Icons.wysiwyg_rounded, darkTheme: isDarkMode(context)),
      trailing: _arrowForward,
      onTap: () {
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
      },
    );
  }

  Widget get _arrowForward {
    return const Icon(Icons.arrow_forward_ios, size: 16);
  }

  static const _isServiceLogConsoleSupported = true;
  Widget get _serviceLogConsole {
    final tr = AppLocalizations.of(context);
    Global.setLogConsoleLocalTexts(context);
    return ListTile(
      title: Text(tr.showDaemonLog),
      subtitle: const Text("Show chat service diagnostic logs"),
      leading: getIcon(Icons.terminal_rounded, darkTheme: isDarkMode(context)),
      trailing: _isServiceLogConsoleSupported
          ? _arrowForward
          : Text("Not supported yet"),
      onTap: _isServiceLogConsoleSupported
          ? () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) {
                  return log.LogConsole(
                    dark: _isDarkTheme,
                    title: tr.daemonLogConsoleTitleText,
                    showRefreshButton: true,
                    getLogOutputEvents: _getChatServiceLogs,
                    saveFile: () => _save(_cylonixdLogFile),
                    shareFile:
                        _canShareFile ? () => _share(_cylonixdLogFile) : null,
                  );
                }),
              );
            }
          : null,
    );
  }

  Future<ListQueue<OutputEvent>> _getChatServiceLogs() async {
    ListQueue<OutputEvent> events = ListQueue();
    try {
      final logs = await ChatService.getLogs();
      for (var line in logs.split('\n')) {
        final event = OutputEvent(LogEvent(Level.info, ""), [line]);
        events.add(event);
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
