// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'package:event_bus/event_bus.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:uuid/uuid.dart';
import '../models/chat/chat_event.dart';
import '../utils/logger.dart';

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
  final int _maxRetries = 10;
  final Duration _initialRetryDelay = Duration(seconds: 1);
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

  static Completer<String>? logCompleter;
  static Future<String> getLogs() async {
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

  Future<void> sendMessage(String message) async {
    try {
      final id = Uuid().v4();
      _logger
          .d("send message: make sure socket is connected. message=$message");
      await _ensureSocketConnected();
      _socket?.write("TEXT:$id:$message\n");
      await _socket?.flush();
      _logger.d("wait for ack of $id");
      await _waitForAck(id);
      _logger.d("send message to peer service done: $message");
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
      _logger.d("sendFile: start");
      _socket?.write("FILE_START:$id:$filename:$fileSize\n");
      _logger.d("sendFile: sent file information to peer");
      await _socket?.flush();
      final inputStream = file.openRead();
      _logger.d("sendFile: read");
      _socket!.addStream(inputStream);
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

  Future<void> _connectSocketWithRetry() async {
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
      await _connectSocket();
      _retryCount = 0;
      _isConnecting = false;
    } catch (e) {
      _logger.e('Failed to connect to socket (retry count: $_retryCount): $e');
      _isConnecting = false;
      if (_retryCount < _maxRetries) {
        final delay = _initialRetryDelay * (1 << _retryCount);
        _retryCount++;
        _logger.i('Retrying connection in ${delay.inSeconds} seconds...');
        await Future.delayed(delay);
        await _connectSocketWithRetry();
      } else {
        _logger.e('Max retries reached. Connection failed permanently.');
        _closeSocket();
      }
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

  Future<void> _connectSocket() async {
    try {
      if (_socket != null) {
        throw Exception("Socket already exists");
      }
      _logger.d("Connecting to socket tcp://$serverAddress:$port");
      _socket = await Socket.connect(serverAddress, port);
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
    } else {
      _logger.e("Close socket is called on a socket that has been closed.");
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

  Future<void> _connectServiceSocketWithRetry() async {
    _logger.d("_connectServiceSocketWithRetry 1");
    if (_isServiceSocketConnecting) {
      return;
    }
    _logger.d("_connectServiceSocketWithRetry 2");
    _isServiceSocketConnecting = true;
    _eventBus.fire(ChatServiceStateEvent(
      from: this,
      state: ChatServiceState.connecting,
      isSelfDevice: true,
    ));
    try {
      _logger.d("_connectServiceSocketWithRetry 3");
      await _connectServiceSocket();
      _logger.d("_connectServiceSocketWithRetry 4");

      _serviceSocketRetryCount = 0;
      _isServiceSocketConnecting = false;
    } catch (e) {
      _logger.e(
          'Failed to connect to service port $port (retry $_serviceSocketRetryCount): $e');
      _isServiceSocketConnecting = false;
      if (_serviceSocketRetryCount < _maxRetries) {
        final delay = _initialRetryDelay * (1 << _serviceSocketRetryCount);
        _serviceSocketRetryCount++;
        _logger.i(
            'Retrying service socket connection in ${delay.inSeconds} seconds...');
        await Future.delayed(delay);
        await _connectServiceSocketWithRetry();
      } else {
        _logger.e(
            'Max service socket retries reached. Connection failed permanently.');
        _closeServiceSocket();
      }
    }
  }

  Future<void> _connectServiceSocket() async {
    try {
      _logger.d("Trying to connect to service socket");
      _serviceSocket = await Socket.connect("127.0.0.1", port);
      isServiceSocketConnected = true;
      _logger.i("Service socket connected");
      _eventBus.fire(ChatServiceStateEvent(
        from: this,
        state: ChatServiceState.connected,
        isSelfDevice: true,
      ));
    } catch (e) {
      _logger.e("Error connecting service socket $e");
      _closeServiceSocket();
      rethrow;
    }
  }

  void _closeServiceSocket() {
    if (_serviceSocket != null) {
      try {
        _serviceSocket?.close();
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
    try {
      final delay = _initialRetryDelay;
      if (_serviceSocket == null) {
        await _connectServiceSocketWithRetry();
      }
      if (_serviceSocket == null) {
        throw Exception("Failed to connect to service socket");
      }
      _logger.d("Listening to service at tcp://127.0.0.1:$port");
      _serviceSocket?.listen((event) {
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
        _logger.i("Service scoket connection closed");
        _closeServiceSocket();
        await Future.delayed(delay);
        startServiceStateMonitor();
      });
      _serviceSocket?.write("PING:PONG\n");
      await _serviceSocket?.flush();
      _logger.i("Started service port monitor.");
    } catch (e) {
      _logger.e('Failed to start service port monitor: $e');
      _closeServiceSocket();
    }
  }
}
