// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:event_bus/event_bus.dart';
import 'package:flutter/services.dart';
import 'package:tailchat/utils/utils.dart';
import 'package:uuid/uuid.dart';
import '../models/chat/chat_event.dart';
import '../utils/logger.dart';
import 'chat_server.dart';

class ChatService {
  static final _logger = Logger(tag: "ChatService");
  static final _eventBus = EventBus();

  // Single static receiving service.
  static const platform = MethodChannel('io.cylonix.tailchat/chat_service');
  static const _eventChannel = EventChannel('io.cylonix.tailchat/events');
  static const _chatMessageChannel =
      EventChannel('io.cylonix.tailchat/chat_messages');
  static Stream<dynamic>? _messageStream;
  static Stream<dynamic>? _eventStream;

  // Per-chat session send service.
  final String serverAddress;
  final int port, subscriberPort;
  final int _maxRetries = 3;
  final Duration _initialRetryDelay = Duration(seconds: 2);
  final String? deviceID;
  final String? userID;
  Socket? _socket;
  bool _isConnecting = false;
  int _retryCount = 0;
  Socket? _subscriberSocket;
  bool _isSubscriberConnecting = false;
  int _subscriberRetryCount = 0;

  ChatService({
    this.deviceID,
    this.userID,
    this.serverAddress = "127.0.0.1",
    this.port = 50311,
    this.subscriberPort = 50312,
  });

  static EventBus get eventBus {
    return _eventBus;
  }

  static Future<void> startService() async {
    try {
      await platform.invokeMethod('startService');
      _logger.i("Service started");
    } on PlatformException catch (e) {
      _logger.e("Failed to start service: '${e.message}'.");
    }
  }

  static Future<void> stopService() async {
    try {
      await platform.invokeMethod('stopService');
      _logger.i("Service stopped");
    } on PlatformException catch (e) {
      _logger.e("Failed to stop service: '${e.message}'.");
    }
  }

  static void initMethodChannelHandlers() {
    platform.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'handleOpenFile':
          final String filePath = call.arguments as String;
          _logger.d("Sharing file $filePath");
          _eventBus.fire(ChatSharingEvent(files: [filePath]));
          break;
        case 'handleOpenFiles':
          final List<String> filePaths = List<String>.from(call.arguments);
          _logger.d("Sharing files $filePaths");
          _eventBus.fire(ChatSharingEvent(files: filePaths));
          break;
        case 'handleOpenText':
          final String text = call.arguments;
          _logger.d("Sharing text ${text.shortString(100)}");
          _eventBus.fire(ChatSharingEvent(text: text));
          break;
        case 'handleOpenURLs':
          final List<String> urls = List<String>.from(call.arguments);
          _logger.d("Sharing urls: $urls");
          _eventBus.fire(ChatSharingEvent(urls: urls));
          break;
        default:
          _logger.e("Unknow method: ${call.method}");
          break;
      }
    });
  }

  static Completer<String>? logCompleter;
  static Future<String> getLogs() async {
    if (Platform.isLinux) {
      try {
        _logger.d("Starting shell cmd");
        final result = await Process.run(
          'sh',
          ['-c', 'grep tailchatd /var/log/syslog | tail -n 1000'],
          stdoutEncoding: utf8,
          stderrEncoding: utf8,
        );
        if (result.exitCode != 0) {
          throw "${result.stderr}";
        }
        _logger.d("Got results from shell: ${result.stdout.length} bytes");
        return result.stdout;
      } catch (e) {
        final msg = "Failed to get logs: $e";
        _logger.e(msg);
        return msg;
      }
    }
    if (Platform.isAndroid) {
      return await platform.invokeMethod('logs');
    }
    logCompleter = Completer<String>();
    await platform.invokeMethod('logs');
    return await logCompleter!.future.timeout(Duration(seconds: 5));
  }

  static void handleLogs(String? logs) {
    if (logs != null) {
      logCompleter?.complete(logs);
    }
  }

  String get _socketName {
    return "tcp://:${_socket?.port} -> $serverAddress:$port";
  }

  String get _subscriberSocketName {
    return "tcp://127.0.0.1:${_subscriberSocket?.port} -> :$subscriberPort";
  }

  EventBus onDataBus = EventBus();

  Future<String> _waitForAck(String id) async {
    _logger.i("Waiting for ack on $id");
    for (var line in _lines.reversed) {
      if (line.startsWith("ACK:$id")) {
        _logger.i("ACK for $id received.");
        _lines.remove(line);
        return line;
      }
    }
    final completer = Completer<String>();
    final sub = onDataBus.on<ChatSocketReceiveDataEvent>().listen((_) {
      _logger.i("got lines. look for $id.");
      for (var line in _lines.reversed) {
        if (line.startsWith("ACK:$id")) {
          _logger.i("ACK for $id received.");
          _lines.remove(line);
          completer.complete(line);
          return;
        }
      }
    });
    try {
      return await completer.future.timeout(Duration(seconds: 5));
    } catch (e) {
      rethrow;
    } finally {
      sub.cancel();
    }
  }

  bool get isConnected {
    return _socket != null;
  }

  Future<void> sendMessage(String message) async {
    try {
      final id = Uuid().v4();
      final start = DateTime.now();
      _logger.d(
        "send message: make sure socket is connected. "
        "message=${message.shortString(256)}...",
      );
      await _ensureSocketConnected();
      if (_socket == null) {
        throw Exception("Socket is not connected.");
      }
      final delay = DateTime.now().difference(start).inSeconds;
      _logger.d("Sending a message stored since $start, after $delay seconds");
      _socket?.write("TEXT:$id:$message\n");
      await _socket?.flush();
      _logger.d("wait for ack of $id");
      await _waitForAck(id);
      _logger.d(
        "send message to peer service done: ${message.shortString(256)}...",
      );
    } catch (e) {
      _logger.e('Error sending message: $e');
      _closeSocket();
      rethrow;
    }
  }

  Future<void> _waitForFileDone(
    String id,
    int fileSize,
    Function(int, int)? onProgress,
  ) async {
    for (var line in _lines.reversed) {
      if (line.startsWith("ACK:$id")) {
        if (line.startsWith("ACK:$id:DONE")) {
          _lines.removeWhere((element) => element.startsWith("ACK:$id"));
          _logger.i("ACK DONE received.");
          return;
        }
        final parts = line.split(":");
        if (parts.length >= 3) {
          final n = int.tryParse(parts[2]);
          if (n != null) {
            _logger.i("progress=$n");
            onProgress?.call(n, fileSize);
          } else {
            _logger.e('parts[2]="${parts[2]}"');
          }
        }
        break;
      }
    }
    _lines.removeWhere((element) => element.startsWith("ACK:$id"));

    // Not done yet. Wait for more ACKs.
    var completer = Completer<String>();
    _logger.i("Subscribe to onData bus");
    final sub = onDataBus.on<ChatSocketReceiveDataEvent>().listen((event) {
      _logger.d("got line");
      var found = false;
      for (var line in _lines.reversed) {
        if (line.startsWith("ACK:$id")) {
          _logger.d("complete the future");
          completer.complete(line);
          completer = Completer<String>();
          found = true;
          break;
        }
      }
      if (found) {
        _lines.removeWhere((element) => element.startsWith("ACK:$id"));
      }
    });
    try {
      while (true) {
        final s = await completer.future.timeout(Duration(seconds: 5));
        if (s.startsWith("ACK:$id:DONE")) {
          _logger.i("sendFile: ACK DONE!");
          return;
        }
        _logger.d("sendFile: got ACK $s");
        final parts = s.split(":");
        if (parts.length >= 3) {
          final n = int.tryParse(parts[2]);
          if (n != null) {
            onProgress?.call(n, fileSize);
          }
        }
      }
    } catch (e) {
      rethrow;
    } finally {
      sub.cancel();
    }
  }

  Future<void> sendFile(
    File file, {
    String? filename,
    Function(int, int)? onProgress,
  }) async {
    filename ??= file.path.split(Platform.pathSeparator).last;
    final fileSize = file.lengthSync();
    try {
      final id = Uuid().v4();
      await _ensureSocketConnected();
      final socket = _socket;
      if (socket == null) {
        throw Exception("failed to connect to peer");
      }
      _logger.d("sendFile: start");
      socket.write("FILE_START:$id:$filename:$fileSize\n");
      _logger.d("sendFile: sent file information to peer");
      await socket.flush();
      final inputStream = file.openRead();
      _logger.d("sendFile: read");
      socket.addStream(inputStream);
      _logger.d("sendFile: pipe");
      await _waitForFileDone(id, fileSize, onProgress);
    } catch (e) {
      _logger.e('Error sending file: $e');
      _closeSocket();
      rethrow;
    }
  }

  Future<void> sendPing() async {
    try {
      _logger.d("Ping $serverAddress:$port: Ensure socket is connected.");
      await _ensureSocketConnected();
      _logger.d("Ping $serverAddress:$port: Socket is connected.");
      _socket!.write("PING:PONG\n");
      _logger.d("Ping $serverAddress:$port: Ping sent.");
      await _socket!.flush();
      await _waitForAck("PONG");
    } catch (e) {
      _logger.e('Error sending ping: $e');
      _closeSocket();
      rethrow;
    }
  }

  static Stream<dynamic> subscribeToMessages() {
    _messageStream ??=
        _chatMessageChannel.receiveBroadcastStream("chat_messages");
    return _messageStream!;
  }

  static Stream<dynamic> subscribeToEvents() {
    _eventStream ??= _eventChannel.receiveBroadcastStream("events");
    return _eventStream!;
  }

  Future<void> _ensureSocketConnected() async {
    if (_socket == null) {
      if (!_isConnecting) {
        _logger.d("Connecting to remote $serverAddress:$port");
        await _connectSocketWithRetry();
      } else {
        _logger.d("Socket is being reconnected. Wait a bit");
        for (var i = 0; i < 50; i++) {
          final ok =
              await Future<bool>.delayed(Duration(milliseconds: 100), () {
            if (_socket != null) {
              _logger.d("Socket is connected. OK.");
              return true;
            }
            return false;
          });
          if (ok) {
            return;
          }
        }
        throw Exception("Failed to ensure socket is connected");
      }
    }
  }

  Future<void> tryConnect() async {
    _logger.d("Try connecting to socket $_socketName");
    await _connectSocketWithRetry(
      oneShot: true,
      timeout: Duration(seconds: 1),
    );
  }

  Future<void> _connectSocketWithRetry({
    bool oneShot = false,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    if (_isConnecting) {
      return;
    }
    _isConnecting = true;
    _eventBus.fire(ChatServiceStateEvent(
      from: this,
      userID: userID,
      deviceID: deviceID,
      state: ChatServiceState.connecting,
    ));
    try {
      await _connectSocket(timeout: timeout);
      _logger.d("Socket $_socketName is now connected");
      _retryCount = 0;
      _isConnecting = false;
    } catch (e) {
      if (oneShot) {
        throw Exception("Failed to connect to $_socketName: $e");
      }
      _logger.e('Failed to connect to socket (retry count: $_retryCount): $e');
      if (_retryCount < _maxRetries) {
        final delay = _initialRetryDelay * (1 << _retryCount);
        _retryCount++;
        _logger.i('Retrying connection in ${delay.inSeconds} seconds...');
        _isConnecting = false;
        await Future.delayed(delay);
        await _connectSocketWithRetry();
      } else {
        _logger.e('Max retries reached. Connection failed permanently.');
        _closeSocket();
        throw Exception("Failed to connect to socket after $_maxRetries tries");
      }
    } finally {
      _isConnecting = false;
    }
  }

  /// _socket is unidirectional meaning we only use it to send messages.
  /// The other side does the same so that we can send while the other side
  /// is paused.
  var _lines = <String>[];
  var _buf = <int>[];
  void _monitorSocket() {
    _socket?.listen((onData) async {
      _buf.addAll(onData);
      var i = 0;
      while (true) {
        final index = _buf.indexOf(10); // Look for newline '\n'.
        if (index < 0) {
          break;
        }
        final line = _buf.sublist(0, index);
        _buf = _buf.sublist(index + 1);
        var s = utf8.decode(line);
        if (s.startsWith("TEXT:")) {
          final parts = s.split(":");
          if (parts.length < 3) {
            _logger.e("Invalid TEXT message: $s");
            continue;
          }
          final id = parts[1];
          ChatServer.handleReceiveChatMessage(s.replaceFirst("TEXT:$id:", ""));
          continue;
        }
        _lines.add(s);
        i++;
      }
      _logger.d("Received $i lines");
      onDataBus.fire(ChatSocketReceiveDataEvent(line: ""));
    }, onDone: () {
      _logger.i("Socket is now closed onDone.");
      _closeSocket();
    }, onError: (e) {
      _logger.e("Socket error: $e");
      _eventBus.fire(ChatServiceStateEvent(
        from: this,
        userID: userID,
        deviceID: deviceID,
        error: "$e",
      ));
      _closeSocket();
    });
  }

  void listenToSubscriberSocket(void Function(String) dataHandler) async {
    if (_subscriberSocket == null) {
      _logger.d("Connecting to $_subscriberSocketName");
      await _connectSubscriberSocketWithRetry();
    }

    _logger.d("Listening to $_subscriberSocketName");
    _subscriberSocket?.listen((onData) {
      var s = utf8.decode(onData);
      dataHandler(s);
    }, onDone: () {
      _logger.i("Subscriber socket is now closed.");
      _closeSubscriberSocket();
      // Re-start listening.
      listenToSubscriberSocket(dataHandler);
    }, onError: (e) {
      _logger.e("Subscriber socket error: $e");
      _closeSubscriberSocket();
      listenToSubscriberSocket(dataHandler);
    });
  }

  bool _isSocketConnecting = false;
  Future<void> _connectSocket({Duration? timeout}) async {
    if (_isSocketConnecting) {
      _logger.d("Socket is already connecting. Skip");
      return;
    }
    _isSocketConnecting = true;
    try {
      if (_socket != null) {
        throw Exception("Socket already exists");
      }
      _logger.d("Connecting to socket tcp://$serverAddress:$port");
      _socket = await Socket.connect(
        serverAddress,
        port,
        timeout: timeout ?? Duration(seconds: 5),
      );
      _monitorSocket();
      _logger.i("Socket Connected");
      _eventBus.fire(ChatServiceStateEvent(
        from: this,
        userID: userID,
        deviceID: deviceID,
        state: ChatServiceState.connected,
      ));
    } catch (e) {
      _logger.e("Error connecting to socket $e");
      _closeSocket();
      rethrow;
    } finally {
      _isSocketConnecting = false;
    }
  }

  void _closeSocket() {
    _lines = [];
    _buf = [];
    if (_socket != null) {
      _eventBus.fire(ChatServiceStateEvent(
        from: this,
        userID: userID,
        deviceID: deviceID,
        state: ChatServiceState.disconnected,
      ));
      try {
        _socket?.close();
        _logger.i("Socket $_socketName is now closed");
      } catch (e) {
        _logger.e("Failed to close socket: $e");
      } finally {
        _socket = null;
      }
    }
  }

  Future<void> _connectSubscriberSocketWithRetry() async {
    _logger.d("_connectSubscriberSocketWithRetry 1");
    if (_isSubscriberConnecting) {
      return;
    }
    _logger.d("_connectSubscriberSocketWithRetry 2");
    _isSubscriberConnecting = true;
    try {
      _logger.d("_connectSubscriberSocketWithRetry 3");
      await _connectSubscriberSocket();
      _logger.d("_connectSubscriberSocketWithRetry 4");

      _subscriberRetryCount = 0;
      _isSubscriberConnecting = false;
    } catch (e) {
      _logger.e(
          'Failed to connect to subscriber port $subscriberPort (retry $_subscriberRetryCount): $e');
      _isSubscriberConnecting = false;
      if (_subscriberRetryCount < _maxRetries) {
        final delay = _initialRetryDelay * (1 << _subscriberRetryCount);
        _subscriberRetryCount++;
        _logger.i(
            'Retrying subscriber connection in ${delay.inSeconds} seconds...');
        await Future.delayed(delay);
        await _connectSubscriberSocketWithRetry();
      } else {
        _logger.e(
            'Max subscriber retries reached. Connection failed permanently.');
        _closeSubscriberSocket();
      }
    }
  }

  Future<void> _connectSubscriberSocket() async {
    try {
      _logger.d("Trying to connect to Subscriber Socket");
      _subscriberSocket = await Socket.connect("127.0.0.1", subscriberPort);
      _logger.i("Subscriber socket connected");
    } catch (e) {
      _logger.e("Error connecting subscriber socket $e");
      _closeSubscriberSocket();
      rethrow;
    }
  }

  void _closeSubscriberSocket() {
    if (_subscriberSocket != null) {
      try {
        _subscriberSocket?.close();
        _logger.i("Subscriber socket $_subscriberSocketName is now closed");
      } catch (e) {
        _logger.e("Failed to close subscriber socket: $e");
      } finally {
        _subscriberSocket = null;
      }
    }
  }

  Socket? _serviceSocket;
  bool isServiceSocketConnected = false;
  bool _isServiceSocketConnecting = false;
  int _serviceSocketRetryCount = 0;
  StreamSubscription<Uint8List>? _serviceSocketSub;

  Future<void> _connectServiceSocketWithRetry() async {
    if (_isServiceSocketConnecting) {
      _logger.d("Service socket is connecting. Skip.");
      return;
    }
    _isServiceSocketConnecting = true;
    _logger.d("Connecting to service socket");
    _eventBus.fire(ChatServiceStateEvent(
      from: this,
      state: ChatServiceState.connecting,
      isSelfDevice: true,
    ));
    try {
      await _connectServiceSocket();
      _serviceSocketRetryCount = 0;
      _isServiceSocketConnecting = false;
    } catch (e) {
      _logger.e(
        'Failed to connect to service socket port $port '
        '(retry $_serviceSocketRetryCount): $e',
      );
      if (_serviceSocketRetryCount < _maxRetries) {
        final delay = _initialRetryDelay * (1 << _serviceSocketRetryCount);
        _serviceSocketRetryCount++;
        _logger.i(
          'Retrying service socket connection in ${delay.inSeconds} '
          'seconds...',
        );
        await Future.delayed(delay);
        _isServiceSocketConnecting = false;
        await _connectServiceSocketWithRetry();
      } else {
        _isServiceSocketConnecting = false;
        _logger.e(
          'Max service socket retries reached. '
          'Connection failed.',
        );
        _closeServiceSocket();
      }
    }
  }

  Future<void> restartServer() async {
    await platform.invokeMethod("restartService");
  }

  Future<void> _connectServiceSocket() async {
    try {
      _logger.d("Trying to connect to service socket port $port");
      _serviceSocket = await Socket.connect("127.0.0.1", port);
      isServiceSocketConnected = true;
      _logger.i("Service socket is now connected");
      _eventBus.fire(ChatServiceStateEvent(
        from: this,
        state: ChatServiceState.connected,
        isSelfDevice: true,
      ));
    } catch (e) {
      _logger.e("Error connecting service socket: $e");
      _closeServiceSocket();
      rethrow;
    }
  }

  void _closeServiceSocket({bool destory = false}) {
    _serviceSocketSub?.cancel();
    _serviceSocketSub = null;
    if (_serviceSocket != null) {
      try {
        if (destory) {
          _serviceSocket?.destroy();
        } else {
          _serviceSocket?.close();
        }
        _logger.i("Service socket is now closed");
        _eventBus.fire(ChatServiceStateEvent(
          from: this,
          state: ChatServiceState.disconnected,
          isSelfDevice: true,
        ));
      } catch (e) {
        _logger.e("Failed to close service socket: $e");
      } finally {
        isServiceSocketConnected = false;
        _serviceSocket = null;
      }
    }
  }

  Future<void> startServiceStateMonitor() async {
    if (isServiceSocketConnected) {
      _logger.d("Service is already connected and being monitored.");
      return;
    }
    try {
      final delay = _initialRetryDelay;
      if (_serviceSocket == null) {
        await _connectServiceSocketWithRetry();
      }
      if (_serviceSocket == null) {
        throw Exception("Failed to connect to service socket");
      }
      _logger.d("Listening to service at tcp://127.0.0.1:$port");
      _serviceSocketSub?.cancel();
      _serviceSocketSub = _serviceSocket?.listen((event) {
        _logger.i("Message from service socket: '${utf8.decode(event)}'");
      }, onError: (error) async {
        final msg = "Error from service socket connection : $error";
        _logger.e(msg);
        _eventBus.fire(ChatServiceStateEvent(
          from: this,
          error: msg,
          isSelfDevice: true,
        ));
        _closeServiceSocket();
        await Future.delayed(delay);
        startServiceStateMonitor();
      }, onDone: () async {
        _logger.i("Service socket connection closed");
        _closeServiceSocket();
        await Future.delayed(delay);
        startServiceStateMonitor();
      });
      _serviceSocket?.write("PING:PONG\n");
      await _serviceSocket?.flush();
      _logger.i("Started service port monitor.");
    } catch (e) {
      final msg = 'Failed to start service port monitor: $e';
      _logger.e(msg);
      _closeServiceSocket();
    }
  }

  Future<void> stopServiceStateMonitor() async {
    try {
      _closeServiceSocket(destory: true);
    } catch (e) {
      _logger.e("Failed to stop service state montior: $e");
    }
  }
}
