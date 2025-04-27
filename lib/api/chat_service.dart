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
  static final eventBus = EventBus();

  static const platform = MethodChannel('io.cylonix.tailchat/chat_service');
  static const _eventChannel = EventChannel('io.cylonix.tailchat/events');
  static const _chatMessageChannel =
      EventChannel('io.cylonix.tailchat/chat_messages');
  static Stream<dynamic>? _messageStream;
  static Stream<dynamic>? _eventStream;

  static SubscriberSocketListener? _subscriberSocketListener;
  static ServiceSocketListner? _serviceSocketListener;
  static bool _isSettingUpSubsciberSocket = false;
  static bool _isSettingUpServiceSocket = false;

  static Future<bool> isCylonixEnabled() async {
    if (Platform.isIOS) {
      _logger.i("Check if Cylonix service is enabled");
      final enabled = await platform.invokeMethod('isCylonixServiceActive');
      if (enabled) {
        return true;
      }
      _logger.i("Cylonix servive: enabled=$enabled");
    }
    return false;
  }

  static Future<String?> getCylonixSharedFolderPath() async {
    if (Platform.isIOS) {
      _logger.i("Cylonix service: get shared folder path");
      final path = await platform.invokeMethod('getCylonixSharedFolderPath');
      return path;
    }
    return null;
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

  static Stream<dynamic> subscribeToMessages() {
    _messageStream ??=
        _chatMessageChannel.receiveBroadcastStream("chat_messages");
    return _messageStream!;
  }

  static Stream<dynamic> subscribeToEvents() {
    _eventStream ??= _eventChannel.receiveBroadcastStream("events");
    return _eventStream!;
  }

  static Future<String?> _getLocalAddress(String? address) async {
    if (!Platform.isIOS) {
      return null;
    }
    _logger.i("listenToSubscriberSocket: check if Cylonix service is enabled");
    final enabled = await platform.invokeMethod('isCylonixServiceActive');
    if (!enabled) {
      _logger.i("Cylonix service is not enabled. Using default address");
      return null;
    }
    if (address == null) {
      _logger.e("Cylonix service requires address to be set");
      throw Exception("Cylonix service requires address to be set");
    }
    _logger.i("Cylonix service is enabled. Using address $address");
    return address;
  }

  static Future<void> listenToSubscriberSocket(
    void Function(String) dataHandler, {
    String? address,
    int? port,
    bool disconnectIfExists = false,
    Function(dynamic)? onError,
  }) async {
    if (_isSettingUpSubsciberSocket) {
      _logger.d("Subscriber socket is already being set up. Skip.");
      return;
    }
    _isSettingUpSubsciberSocket = true;
    try {
      if (_subscriberSocketListener != null) {
        if (disconnectIfExists) {
          _logger.d("Subscriber socket is already connected. Disconnecting.");
          _subscriberSocketListener?.close();
        } else {
          _logger.d("Subscriber socket is already connected. Skip.");
          throw Exception(
            "Subscriber socket is already connected and being monitored.",
          );
        }
      }
      retry() {
        try {
          listenToSubscriberSocket(
            dataHandler,
            address: address,
            port: port,
            disconnectIfExists: disconnectIfExists,
            onError: onError,
          );
        } catch (e) {
          _logger.e("Failed to re-listen to subscriber socket: $e");
          onError?.call(e);
        }
      }

      final listener = SubscriberSocketListener(
        address: await _getLocalAddress(address),
        port: port,
        onData: dataHandler,
        onDisconnected: () {
          _logger.i("Subscriber socket is now closed.");
          _subscriberSocketListener?.close();
          _subscriberSocketListener = null;
          retry();
        },
        onError: (e) {
          _logger.i("Subscriber socket is having an error: $e");
          _subscriberSocketListener?.close();
          _subscriberSocketListener = null;
          retry();
        },
      );
      await listener.connect();
      listener.listen();
      _subscriberSocketListener = listener;
    } finally {
      _isSettingUpSubsciberSocket = false;
    }
  }

  static Future<void> restartServer() async {
    await platform.invokeMethod("restartService");
  }

  static Future<void> startServiceStateMonitor({
    String? address,
    int? port,
    bool disconnectIfExists = false,
    Function(dynamic)? onError,
  }) async {
    final log = Logger(tag: "ChatService:ServiceStateMonitor");
    if (_isSettingUpServiceSocket) {
      log.d("Service socket is already being set up. Skip.");
      return;
    }
    retry() {
      try {
        startServiceStateMonitor(
          address: address,
          port: port,
          disconnectIfExists: disconnectIfExists,
          onError: onError,
        );
      } catch (e) {
        log.e("Failed to re-listen to service socket: $e");
        onError?.call(e);
      }
    }

    _isSettingUpServiceSocket = true;
    try {
      if (_serviceSocketListener != null) {
        if (disconnectIfExists) {
          log.d("Service is already connected. Disconnecting.");
          _serviceSocketListener?.close();
        } else {
          log.e("Service is already connected and being monitored.");
          throw Exception(
            "Service is already connected and being monitored.",
          );
        }
      }

      final listener = ServiceSocketListner(
        address: await _getLocalAddress(address),
        port: port,
        onData: (data) {
          log.d("Service socket data: $data");
          eventBus.fire(ChatServiceStateEvent(
            state: ChatServiceState.connected,
            isSelfDevice: true,
          ));
        },
        onConnected: () {
          log.d("Service socket connected.");
          eventBus.fire(ChatServiceStateEvent(
            state: ChatServiceState.connected,
            isSelfDevice: true,
          ));
        },
        onDisconnected: () {
          log.i("Service socket is disconnected. Trying to reconnect.");
          _serviceSocketListener?.close();
          _serviceSocketListener = null;
          eventBus.fire(ChatServiceStateEvent(
            state: ChatServiceState.disconnected,
            isSelfDevice: true,
          ));
          retry();
        },
        onError: (e) {
          log.i("Service socket is having an error: $e");
          _serviceSocketListener?.close();
          _serviceSocketListener = null;
          onError?.call(e);
          retry();
        },
      );
      await listener.connect();
      listener.listen();
      _serviceSocketListener = listener;
      _logger.i("Started service port monitor.");
    } catch (e) {
      final msg = 'Failed to start service port monitor: $e';
      _logger.e(msg);
      rethrow;
    } finally {
      _isSettingUpServiceSocket = false;
    }
  }

  static Future<void> stopServiceStateMonitor() async {
    try {
      _serviceSocketListener?.close();
    } catch (e) {
      _logger.e("Failed to stop service state montior: $e");
    }
  }

  static bool get isServiceSocketConnected {
    return _serviceSocketListener?.isConnected ?? false;
  }

  static bool get isSubscriberSocketConnected {
    return _subscriberSocketListener?.isConnected ?? false;
  }
}

class SocketListener {
  late final Logger _logger;
  final String address;
  final int port;
  final String name;
  final int maxRetries;
  final int socketConnectTimeout; // seconds
  final void Function(String)? onData;
  final void Function(dynamic)? onError;
  final void Function()? onConnecting;
  final void Function()? onConnected;
  final void Function()? onDisconnected;
  final _initialRetryDelay = const Duration(seconds: 2);
  int _retryCount = 0;
  bool isConnecting = false;
  Socket? _socket;
  StreamSubscription<Uint8List>? _socketSub;

  SocketListener({
    required this.address,
    required this.port,
    this.name = "",
    this.maxRetries = 3,
    this.socketConnectTimeout = 5,
    this.onData,
    this.onError,
    this.onConnecting,
    this.onConnected,
    this.onDisconnected,
  }) {
    _logger = Logger(tag: "SocketListner:$name");
  }

  @override
  String toString() {
    return "tcp://:${_socket?.port} -> $address:$port";
  }

  bool get isConnected {
    return _socket != null;
  }

  void close() {
    _logger.i("$this closing");
    _socketSub?.cancel();
    _socket?.close();
    _socketSub = null;
    _socket = null;
    _logger.i("$this closed");
  }

  Future<void> tryConnect() async {
    _logger.d("$this try connecting");
    await _connectSocketWithRetry(
      oneShot: true,
      timeout: 1,
    );
  }

  Future<void> _connectSocketWithRetry({
    bool oneShot = false,
    int? timeout,
  }) async {
    if (isConnecting) {
      return;
    }
    isConnecting = true;
    onConnecting?.call();
    try {
      await _connect(timeout: timeout);
      _logger.d("$this connected");
      _retryCount = 0;
      return;
    } catch (e) {
      if (oneShot) {
        throw Exception("$this failed to connect: $e");
      }
      _logger.e('$this: failed to connect (retry $_retryCount): $e');
      if (_retryCount < maxRetries) {
        final delay = _initialRetryDelay * (1 << _retryCount);
        _retryCount++;
        _logger.i('Retrying connection in ${delay.inSeconds} seconds...');
        isConnecting = false;
        await Future.delayed(delay);
        await _connectSocketWithRetry(timeout: timeout);
      } else {
        _logger.e('$this max retries reached. Connection failed permanently.');
        throw Exception("Failed to connect to socket after $maxRetries tries");
      }
    } finally {
      isConnecting = false;
    }
  }

  Future<void> connect() async {
    if (isConnecting) {
      _logger.d("$this is already connecting.");
      throw Exception("$this is already connecting.");
    }
    await _connectSocketWithRetry();
  }

  void listen() {
    if (_socket == null) {
      _logger.e("$this is not connected. Cannot listen.");
      throw Exception("$this is not connected. Cannot listen.");
    }
    if (_socketSub != null) {
      _logger.d("$this already listening");
      throw Exception("$this already listening");
    }
    _logger.d("$this listening");
    _socketSub = _socket!.listen((data) {
      onDataHandler(data);
    }, onDone: () {
      _logger.i("$this done");
      close();
      onDisconnectedHandler();
    }, onError: (e) {
      _logger.e("$this error: $e");
      close();
      onErrorHandler(e);
    });
  }

  void onErrorHandler(dynamic e) {
    onError?.call(e);
  }

  void onDataHandler(Uint8List data) {
    var s = utf8.decode(data);
    _logger.d("$this got data");
    onData?.call(s);
  }

  void onConnectedHandler() {
    onConnected?.call();
  }

  void onConnectingHandler() {
    onConnecting?.call();
  }

  void onDisconnectedHandler() {
    onDisconnected?.call();
  }

  Future<void> _connect({int? timeout}) async {
    try {
      if (_socket != null) {
        throw Exception("Socket already exists");
      }
      _logger.d("$this connecting");
      _socket = await Socket.connect(
        address,
        port,
        timeout: Duration(seconds: timeout ?? socketConnectTimeout),
      );
      _logger.i("$this connected");
    } catch (e) {
      _logger.e("$this connect error: $e");
      rethrow;
    }
  }

  void write(String data) {
    if (_socket == null) {
      _logger.e("$this is not connected. Cannot write.");
      throw Exception("$this is not connected. Cannot write.");
    }
    _socket?.write(data);
  }

  Future<void> flush() async {
    if (_socket == null) {
      _logger.e("$this is not connected. Cannot flush.");
      throw Exception("$this is not connected. Cannot flush.");
    }
    await _socket?.flush();
  }
}

class SubscriberSocketListener extends SocketListener {
  SubscriberSocketListener({
    String? address,
    int? port = 50312,
    super.onData,
    super.onError,
    super.onConnecting,
    super.onConnected,
    super.onDisconnected,
  }) : super(
          address: address ?? "127.0.0.1",
          port: port ?? 50312,
          name: "Subscriber",
        );
}

class ServiceSocketListner extends SocketListener {
  ServiceSocketListner({
    String? address,
    int? port = 50311,
    super.onData,
    super.onError,
    super.onConnecting,
    super.onConnected,
    super.onDisconnected,
  }) : super(
          address: address ?? "127.0.0.1",
          port: port ?? 50311,
          name: "Service",
        );

  @override
  Future<void> connect() async {
    await super.connect();
    write("PING:PONG\n");
    await flush();
  }
}

class ChatServiceSender extends SocketListener {
  final String? deviceID;
  final String? userID;
  final EventBus _onDataBus = EventBus();
  final _lines = <String>[];
  var _buf = <int>[];

  ChatServiceSender({
    this.deviceID,
    this.userID,
    required super.address,
    int? port,
    Function(dynamic)? onError,
  }) : super(
          port: port ?? 50311,
          name: "Send",
        );

  @override
  void onDataHandler(Uint8List data) {
    _buf.addAll(data);
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
    _onDataBus.fire(ChatSocketReceiveDataEvent(line: ""));
  }

  @override
  void onErrorHandler(dynamic e) {
    _logger.e("$this: Send socket error: $e");
    ChatService.eventBus.fire(ChatServiceStateEvent(
      from: this,
      userID: userID,
      deviceID: deviceID,
      error: "$e",
    ));
  }

  @override
  void onConnectedHandler() async {
    _logger.i("$this: Send socket is now connected.");
    ChatService.eventBus.fire(
      ChatServiceStateEvent(
        from: this,
        userID: userID,
        deviceID: deviceID,
        state: ChatServiceState.connected,
      ),
    );
  }

  @override
  void onConnectingHandler() {
    _logger.i("$this: Send socket is now connecting.");
    ChatService.eventBus.fire(
      ChatServiceStateEvent(
        from: this,
        userID: userID,
        deviceID: deviceID,
        state: ChatServiceState.connecting,
      ),
    );
  }

  @override
  void onDisconnectedHandler() async {
    _logger.i("$this: Send socket is now closed.");
    ChatService.eventBus.fire(
      ChatServiceStateEvent(
        from: this,
        userID: userID,
        deviceID: deviceID,
        state: ChatServiceState.disconnected,
      ),
    );
  }

  Future<void> _ensureSocketConnected() async {
    _logger.d("$this: Ensure socket is connected");
    if (!isConnected) {
      if (!isConnecting) {
        await connect();
        listen();
      } else {
        _logger.d("$this: Socket is being connected. Wait a bit");
        for (var i = 0; i < 50; i++) {
          final ok =
              await Future<bool>.delayed(Duration(milliseconds: 100), () {
            if (isConnected) {
              _logger.d("$this: Socket is connected. OK.");
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

  Future<void> sendPing() async {
    try {
      _logger.d("$this: Ping");
      await _ensureSocketConnected();
      write("PING:PONG\n");
      _logger.d("$this: Ping sent.");
      await flush();
      await _waitForAck("PONG");
    } catch (e) {
      _logger.e('Error sending ping: $e');
      rethrow;
    }
  }

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
    final sub = _onDataBus.on<ChatSocketReceiveDataEvent>().listen((_) {
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
      final start = DateTime.now();
      await _ensureSocketConnected();
      if (_socket == null) {
        _logger.e("$this: Socket is not connected.");
        throw Exception("$this: Socket is not connected.");
      }
      final delay = DateTime.now().difference(start).inSeconds;
      _logger.d("$this: Send start=$start(after $delay seconds)");
      _socket?.write("TEXT:$id:$message\n");
      await _socket?.flush();
      _logger.d("$this: Wait for ack of $id");
      await _waitForAck(id);
      _logger.d("$this: Sent: ${message.shortString(256)}...");
    } catch (e) {
      _logger.e('$this: Error sending message: $e');
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
          _logger.i("$this: ACK DONE received.");
          return;
        }
        final parts = line.split(":");
        if (parts.length >= 3) {
          final n = int.tryParse(parts[2]);
          if (n != null) {
            _logger.i("$this: progress=$n");
            onProgress?.call(n, fileSize);
          } else {
            _logger.e('$this: parts[2]="${parts[2]}"');
          }
        }
        break;
      }
    }
    _lines.removeWhere((element) => element.startsWith("ACK:$id"));

    // Not done yet. Wait for more ACKs.
    var completer = Completer<String>();
    _logger.i("$this: Subscribe to onData bus");
    final sub = _onDataBus.on<ChatSocketReceiveDataEvent>().listen((event) {
      _logger.d("$this: got line");
      var found = false;
      for (var line in _lines.reversed) {
        if (line.startsWith("ACK:$id")) {
          _logger.d("$this: complete the future");
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
          _logger.i("$this: sendFile: ACK DONE!");
          return;
        }
        _logger.d("$this: sendFile: got ACK $s");
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
      _logger.d("$this: sendFile: start");
      socket.write("FILE_START:$id:$filename:$fileSize\n");
      _logger.d("$this: sendFile: sent file information to peer");
      await socket.flush();
      final inputStream = file.openRead();
      _logger.d("$this: sendFile: read");
      socket.addStream(inputStream);
      _logger.d("$this: sendFile: pipe");
      await _waitForFileDone(id, fileSize, onProgress);
    } catch (e) {
      _logger.e('Error sending file: $e');
      rethrow;
    }
  }
}
