// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'dart:async';
import 'dart:io';
import 'package:desktop_window/desktop_window.dart';
import 'package:event_bus/event_bus.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import "package:flutter_logger/flutter_logger.dart" as log_console;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:screen_retriever/screen_retriever.dart';
import '../api/config.dart';
import '../gen/l10n/app_localizations.dart';
import 'utils.dart' as utils;

class Global {
  static late Directory _directory;
  static late File _logFile;
  static final _consoleLogger = Logger(
    filter: ProductionFilter(), // log is wanted even in production
    printer: PrettyPrinter(
      noBoxingByDefault: true,
      methodCount: 2,
      errorMethodCount: 8, // number of method calls for stacktrace
      lineLength: 20,
      colors: true,
      printEmojis: true,
      printTime: true,
    ),
    level: Level.debug,
    output: ConsoleOutput(),
  );
  static Logger logger = _consoleLogger;
  static Logger wrappedLogger = _consoleLogger;
  static late Logger loggerNoStack;
  static final _themeEventBus = EventBus();
  static const _defaultLogBufferSize = 512; // number of logs not the bytes
  static final _appOutput = MemoryOutput(bufferSize: _defaultLogBufferSize);
  static final navigatorKey = GlobalKey<NavigatorState>();
  static bool isAndroidTV = false;
  static bool isARDevice = false;
  static bool isDarkModeARDevice = false;
  static String? deviceDetails;

  static List<String> getAppBufferLogs() {
    var logs = <String>[];
    for (var event in _appOutput.buffer) {
      logs.addAll(event.lines);
    }
    return logs;
  }

  static EventBus getThemeEventBus() {
    return _themeEventBus;
  }

  static const _rotateLogInterval = 6; // hours
  static void _loggerPeriodical() {
    Timer.periodic(const Duration(hours: _rotateLogInterval), (timer) async {
      await _rotateLogFile(_directory);
    });
    logger.d("logger timer started");
  }

  /// Rotate log file to a new one and keep only the last 10 files.
  static const maxLogFileSize = 100000; // 100KB
  static const maxLogFileDays = 1; // number of days for log files outstanding
  static Future<void> _rotateLogFile(Directory dir) async {
    final currentLogFileName = path.join(dir.path, "cylonix_log.txt");
    final current = File(currentLogFileName);
    try {
      final size = await current.length();
      logger.d("rotate log file size $size bytes max $maxLogFileSize bytes");
      if (size > maxLogFileSize) {
        final now = DateTime.now().toLocal().toIso8601String();
        final logDirName = path.join(dir.path, "cylonix-logs");
        final logDir = await Directory(logDirName).create();
        // Check if the log file numbers exceed the limit
        logger.d("log dir ${logDir.path}, date $now");
        final entities = await logDir.list().toList();
        for (var entity in entities) {
          if (entity is File) {
            final lastMod = await entity.lastModified();
            logger.d("log file ${entity.path} last modified $lastMod");
            if (DateTime.now().difference(lastMod).inDays > maxLogFileDays) {
              logger.d("delete log file ${entity.path}");
              entity.delete();
            }
          }
        }
        final nowFixed = now.replaceAll(":", "_");
        final newName = path.join(logDir.path, "cylonix_log_$nowFixed.txt");
        logger.d("move current log file to $newName");
        await current.rename(newName);
      }
    } catch (e) {
      logger.e("log file rotation failed: $e");
    }
  }

  /// TODO: move logfile back to private storage with
  /// getExternalStorageDirectory.
  static Future<void> getDirectoryForLogRecord() async {
    //_directory = await getExternalStorageDirectory();
    _directory = await getApplicationDocumentsDirectory();
  }

  static void setLogConsoleLocalTexts(BuildContext context) {
    final tr = AppLocalizations.of(context);
    log_console.LogConsole.setLocalTexts(
      titleText: tr.logConsoleTitleText,
      filterText: tr.logConsoleFilterText,
      debugText: tr.debugText,
      verboseText: tr.verboseText,
      infoText: tr.infoText,
      warningText: tr.warningText,
      errorText: tr.errorText,
      wtfText: tr.wtfText,
      refreshText: tr.refreshText,
      saveText: tr.saveText,
      shareText: tr.shareText,
    );
  }

  // initialize the loggers
  static Future<void> init() async {
    log_console.LogConsole.init(bufferSize: _defaultLogBufferSize);
    log_console.LogConsole.setLogOutput(_appOutput);

    isAndroidTV = await utils.isAndroidTV();
    deviceDetails = await utils.deviceInfoDetail();
    isARDevice = await utils.isARDevice();
    isDarkModeARDevice = utils.isDartModeARDevice();

    await getDirectoryForLogRecord();
    final consoleOutput = ConsoleOutput();
    final multiOutput = MultiOutput([consoleOutput, _appOutput]);
    const lineLength = 20;
    final debugPrinter = PrettyPrinter(
      noBoxingByDefault: true,
      methodCount: 2,
      errorMethodCount: 8, // number of method calls for stacktrace
      lineLength: lineLength, // width of the output
      colors: true, // colorful log messages
      printEmojis: true, // print an emoji for each log message
      printTime: true, // print each log with a timestamp
    ); // use pretty printer to format and print log
    final debugLogger = Logger(
      filter: ProductionFilter(), // log is wanted even in production
      printer: debugPrinter,
      level: Level.debug, // we want all the logs for now
      output: multiOutput, // log to both file and console
    );
    loggerNoStack = debugLogger;
    logger = debugLogger;

    logger.d("rotate log files");
    await _rotateLogFile(_directory);
    logger.d("log file rotation done");
    _loggerPeriodical();
    _logFile = File(path.join(_directory.path, "cylonix_log.txt"));
    final fileOutput = FileOutput(file: _logFile);
    final multiOutputWithFile = MultiOutput([
      fileOutput,
      consoleOutput,
      _appOutput,
    ]);
    final debugLoggerWithFile = Logger(
      filter: ProductionFilter(),
      printer: debugPrinter,
      level: Level.debug,
      output: multiOutputWithFile,
    );

    final alphaLogger = Logger(
      filter: ProductionFilter(),
      printer: PrettyPrinter(
        noBoxingByDefault: true,
        methodCount: 1,
        errorMethodCount: 8,
        lineLength: lineLength,
        printTime: true,
      ),
      level: Level.debug,
      output: multiOutputWithFile,
    );
    final cleanLogger = Logger(
      filter: ProductionFilter(),
      printer: PrettyPrinter(
        noBoxingByDefault: true,
        methodCount: 0,
        errorMethodCount: 4,
        lineLength: lineLength,
        printTime: true,
      ),
      level: Level.warning,
      output: fileOutput,
    );

    const bool isDebug = bool.fromEnvironment('DEBUG');
    const bool verbose = bool.fromEnvironment('VERBOSE', defaultValue: true);
    if (isDebug) {
      logger = debugLoggerWithFile;
      loggerNoStack = debugLoggerWithFile;
    } else if (verbose) {
      logger = alphaLogger;
      loggerNoStack = alphaLogger;
    } else {
      logger = cleanLogger;
      loggerNoStack = cleanLogger;
    }
    wrappedLogger = Logger(
      filter: ProductionFilter(),
      printer: PrettyPrinter(
        stackTraceBeginIndex: 1,
        noBoxingByDefault: true,
        methodCount: 0,
        errorMethodCount: 4,
        lineLength: lineLength,
        printTime: true,
      ),
      level: Level.debug,
      output: multiOutputWithFile,
    );

    logger.d("Global init done");
  }

  /// Initialize desktop window size.
  static void initDesktopWindowSize() async {
    if (utils.isDesktop()) {
      final display = await screenRetriever.getPrimaryDisplay();
      final size = display.size;
      var h = Pst.windowSize?.height ?? 0;
      var w = Pst.windowSize?.width ?? 0;
      final dh = size.height;
      final mh = dh * 0.75;
      final dw = size.width;
      final mw = dw * 0.75;
      if (h < mh || w < mw) {
        h = h < mh ? mh : h;
        w = w < mw ? mw : w;
        DesktopWindow.setWindowSize(Size(w, h));
      }
    }
  }

  static final routeObserver = RouteObserver<Route<dynamic>>();
}
