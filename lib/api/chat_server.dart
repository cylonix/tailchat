// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:app_links/app_links.dart';
import 'package:collection/collection.dart';
import 'package:event_bus/event_bus.dart';
import 'package:flutter/services.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:http/http.dart' as http;

import '../api/notification.dart';
import '../models/alert.dart';
import '../models/chat/chat_event.dart';
import '../models/chat/chat_id.dart';
import '../models/chat/chat_message.dart';
import '../models/chat/chat_storage.dart';
import '../models/contacts/contact.dart';
import '../models/contacts/contacts_repository.dart';
import '../models/contacts/device.dart';
import '../models/contacts/user_profile.dart';
import '../models/progress_change_event.dart';
import '../utils/logger.dart';
import '../utils/utils.dart';
import 'chat_service.dart';
import 'config.dart';
import 'contacts.dart';
import 'dns.dart';
import 'send_chat.dart';

class ChatServer {
  static var _serverStarted = false;
  static var _serverStarting = false;
  static final _eventBus = EventBus();
  static String? _activeChatID;
  static bool _appIsActive = true; // Must be true to start the app.
  static bool isNetworkAvailable = Platform.isLinux ? true : false;
  static final _logger = Logger(tag: "ChatServer");
  static ContactsRepository? _contactsRepository;
  static bool hasSubscribedToMessages = false;
  static bool isCylonixEnabled = false;
  static String? sharedFolderPath;
  static StreamSubscription? _serviceMessageSub;

  static EventBus getChatEventBus() {
    return _eventBus;
  }

  static Future<void> setAppIsActive(
    bool active,
    Function(dynamic) onError,
  ) async {
    _logger.d("app is active = $active");
    _appIsActive = active;
    if (Platform.isIOS) {
      try {
        if (active) {
          final wasEnabled = isCylonixEnabled;
          await _resetCylonixEnabled();
          if (wasEnabled != isCylonixEnabled) {
            await _cylonixEnabledStateChanged(onError);
            return;
          }
        }
        _logger.d("Cylonix enabled: $isCylonixEnabled");
        try {
          active
              ? await startServiceStateMonitor(onError)
              : await ChatService.stopServiceStateMonitor();
        } on SocketListenerExistsException catch (e) {
          _logger.d(
            "App might be resumed from not-paused state e.g. inactive. "
            "Ignore SocketListenerExistsException: $e",
          );
        }
        if (isCylonixEnabled) {
          active
              ? await subscribeToMessages(onError)
              : _cancelSubscriberSocket();
        }
      } catch (e) {
        _logger.e("Failed to start/stop service state monitor: $e");
        onError(e);
      }
    }
  }

  static Future<void> _cylonixEnabledStateChanged(
    Function(dynamic) onError,
  ) async {
    _logger.i("cylonixEnabledStateChanged enabled=$isCylonixEnabled");
    await ChatService.stopService();
    _serverStarted = false;
    await startServer(onError);
    try {
      await subscribeToMessages(onError, force: true);
    } on MustHaveAddressException catch (e) {
      _logger.d(
        "Address may not be ready. Ignore MustHaveAddressException: $e",
      );
    }
  }

  static void setIsOnFront(String chatID, bool onFront) {
    if (onFront) {
      _activeChatID = chatID;
    } else if (_activeChatID == chatID) {
      _activeChatID = null;
    }
  }

  static void clearActiveChatID() {
    _activeChatID = null;
  }

  static Future<void> startServer(Function(dynamic) onError) async {
    _logger.i("Starting chat server");
    if (_serverStarting) {
      _logger.i("chat server is starting. skip...");
      return;
    }
    if (_serverStarted) {
      _logger.i("chat server has been started or is starting. skip...");
      return;
    }
    try {
      _serverStarting = true;
      _logger.i("Initializing chat service");
      _contactsRepository ??= await ContactsRepository.getInstance();
      if (isMobile() || Platform.isMacOS) {
        _logger.i("Starting chat service");
        await ChatService.startService();
        if (isApple()) {
          _logger.i("Starting to listen to chat service events");
          ChatService.subscribeToEvents().listen(_handleEvent);
        }
      }
      ChatService.eventBus.on<ChatServiceStateEvent>().listen(_handleEvent);
      try {
        await startServiceStateMonitor(onError, force: true);
      } on MustHaveAddressException catch (e) {
        _logger.d(
          "Address may not be ready. Ignore MustHaveAddressException: $e",
        );
      }
      _logger.i("Done starting service");
      _serverStarted = true;
    } finally {
      _serverStarting = false;
    }
  }

  static Future<void> restartServer() async {
    await ChatService.restartServer();
  }

  static Future<void> init(
    Function(dynamic) onError,
    Function(Alert) onAlert,
    Function() onNavigateToHome,
  ) async {
    final appLinks = AppLinks(); // AppLinks is singleton
    appLinks.uriLinkStream.listen((uri) async {
      try {
        _logger.i("AppLinks: Received URI: $uri");
        // We may receive URIs that are not from app links but
        // from received sharing. Double check the url.
        if (!uri.toString().startsWith("https://cylonix.io/tailchat/")) {
          _logger.d("Received URI is not a valid app link: $uri");
          return;
        }
        onNavigateToHome();
        await _handleAppLink(uri.path, onError, onAlert);
      } catch (e) {
        _logger.e("Failed to handle dynamic link: $e");
        onError("Failed to handle dynamic link: $e");
      }
    }, onError: (error) {
      _logger.e("AppLinks error: $error");
      onError("AppLinks error: $error");
    }, onDone: () {
      _logger.i("AppLinks stream closed");
      onAlert(Alert(
        "AppLinks stream closed. No more dynamic links will be handled.",
        variant: AlertVariant.info,
      ));
    });

    ChatService.platform.setMethodCallHandler((MethodCall call) async {
      switch (call.method) {
        case 'cylonixServiceStateChanged':
          _logger.i("Cylonix service state changed");
          try {
            await _resetCylonixEnabled();
            await _cylonixEnabledStateChanged(onError);
          } catch (e) {
            _logger.e("Failed to start service state monitor: $e");
            onError(e);
          }
          break;
        case 'handleAppLink':
          _logger.i("handleAppLink: ${call.arguments}");
          try {
            final json = call.arguments as Map<dynamic, dynamic>;
            final path = json['path'] as String?;
            if (path == null || !path.startsWith("/tailchat/")) {
              throw Exception("Invalid app link path: $path");
            }
            onNavigateToHome();
            await _handleAppLink(
              path,
              onError,
              onAlert,
            );
          } catch (e) {
            _logger.e("handleAppLink: Failed: $e");
            onError("Failed to handle app link: $e");
          }
          break;
      }
    });
  }

  static Future<void> _handleAppLink(
    String path,
    Function(dynamic) onError,
    Function(Alert) onAlert,
  ) async {
    final pathComponents = path.split("/");
    if (pathComponents.length != 5) {
      throw Exception("Invalid app link: $pathComponents");
    }
    // skip the first two components '/' and 'tailchat'
    final op = pathComponents[2];
    if (op != "add") {
      throw Exception("Unsupported app link operation: $op");
    }
    final name = pathComponents[3];
    final deviceName = pathComponents[4];
    if (name.isEmpty || deviceName.isEmpty) {
      throw Exception("Invalid contact: ${pathComponents.sublist(3)}");
    }
    if ((await getDevice(
          Device.generateID(deviceName),
        )) !=
        null) {
      _logger.i("handleAppLink: Device $deviceName already exists. Skip.");
      onAlert(Alert(
        "Skipping adding contact through the link. "
        "Device '$deviceName' already exists.",
        variant: AlertVariant.warning,
      ));
      return;
    }
    final contact = Contact(username: name);
    final device = Device(
      userID: contact.id,
      address: "",
      hostname: deviceName,
    );
    if ((await getContact(contact.id)) != null) {
      await addDevice(device);
      _logger.i(
        "handleAppLink: added device to existing contact $name: $device",
      );
      onAlert(Alert(
        "Added device '$deviceName' to contact '$name' through app link.",
        variant: AlertVariant.success,
      ));
    } else {
      contact.devices.add(device);
      await addContact(contact);
      onAlert(Alert(
        "Added contact '$name' with device '$deviceName' through app link.",
        variant: AlertVariant.success,
      ));
      _logger.i("handleAppLink: added contact: $contact");
    }
  }

  static Future<void> _resetCylonixEnabled() async {
    isCylonixEnabled = false;
    sharedFolderPath = null;
    if (Platform.isIOS) {
      _logger.i("Reset Cylonix enabled");
      isCylonixEnabled = await ChatService.isCylonixEnabled();
      if (isCylonixEnabled) {
        sharedFolderPath = await ChatService.getCylonixSharedFolderPath();
      }
    }
  }

  static Future<void> startServiceStateMonitor(
    Function(dynamic) onError, {
    bool force = false,
  }) async {
    _logger.i("Starting service state monitor");
    await ChatService.startServiceStateMonitor(
      address: address,
      disconnectIfExists: force,
      onError: onError,
    );
  }

  static get isServiceSocketConnected {
    _logger.i("Service connected: ${ChatService.isServiceSocketConnected}");
    return ChatService.isServiceSocketConnected;
  }

  static Future<void> subscribeToMessages(
    Function(dynamic) onError, {
    bool force = false,
  }) async {
    if (hasSubscribedToMessages) {
      if (force) {
        _serviceMessageSub?.cancel();
        _logger.d("Force to subscribe to messages.");
      } else {
        _logger.d("Already subscribed to messages. Skip.");
        return;
      }
    }
    hasSubscribedToMessages = true;
    await _resetCylonixEnabled();
    if ((isMobile() || Platform.isMacOS) && !isCylonixEnabled) {
      _logger.i("Start to listen to chat messages");
      _serviceMessageSub =
          ChatService.subscribeToMessages().listen(_handleChatServiceMessage);
    } else {
      _logger.i("Start to listen to subscriber socket");
      try {
        ChatService.listenToSubscriberSocket(
          _handleMessage,
          address: address,
          disconnectIfExists: true,
          onError: onError,
        );
      } catch (e) {
        _logger.e("Failed to listen to subscriber socket: $e");
        hasSubscribedToMessages = false;
        rethrow;
      }
    }
  }

  static void _cancelSubscriberSocket() {
    _logger.i("Cancel subscriber socket");
    ChatService.stopSubscriberSocket();
    hasSubscribedToMessages = false;
  }

  static void _handleChatServiceMessage(dynamic message) {
    if (message is String) {
      _handleMessage(message);
      return;
    }

    _logger.e("Received non-string message: $message");
  }

  // Cache what we got from the service side.
  static String? hostname, address;
  static int? port, subscriberPort;
  static void _updateNetworkConfig({
    String? newHostname,
    String? newAddress,
    int? newPort,
    int? newSubscriberPort,
  }) async {
    hostname = newHostname;
    address = newAddress;
    port = newPort;
    subscriberPort = newSubscriberPort;
    _eventBus.fire(ChatReceiveNetworkConfigEvent(
      address: address,
      hostname: hostname,
      port: port,
      subscriberPort: subscriberPort,
    ));
    if (address != null) {
      await _resetCylonixEnabled();
      if (isCylonixEnabled && _appIsActive) {
        try {
          ChatService.listenToSubscriberSocket(
            _handleMessage,
            address: address,
            disconnectIfExists: true,
          );
          ChatService.startServiceStateMonitor(
            address: address,
            disconnectIfExists: true,
          );
        } catch (e) {
          _logger.e("Failed to listen to subscriber socket: $e");
        }
      }
    }
  }

  static Future<bool> sendPushNotificationToken(
    String uuid,
    String token,
  ) async {
    try {
      final result = await http.put(
        Uri.parse("https://cylonix.io/apn/tailchat"),
        headers: {
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "id": uuid,
          "token": token,
          "platform": Platform.isIOS
              ? "apple"
              : Platform.isAndroid
                  ? "android"
                  : "unknown",
        }),
      );
      if (result.statusCode != 200) {
        throw "${result.statusCode} ${result.body}";
      }
      return true;
    } catch (e) {
      _logger.e("Failed to send push notification id: $e");
    }
    return false;
  }

  /// Handle flutter event channel events.
  static void _handleEvent(dynamic event) async {
    _logger.d(
      "Received event from chat service: "
      "${event.toString().shortString(100)}",
    );
    if (event is Map<dynamic, dynamic>) {
      switch (event['type']) {
        case "network_available":
          _logger.i("Network available: $event");
          try {
            final v = event['available'] as bool? ?? false;
            isNetworkAvailable = v;
            _eventBus.fire(ChatReceiveNetworkAvailableEvent(v));
          } catch (e) {
            _logger.e("Failed to handle network available change: $e");
          }
          break;
        case "network_config":
          _logger.i("Network config: $event");
          await _handleReceiveNetworkConfig(event['devices']);
          break;
        case "pn_info":
          _logger.d("Received push notification info: $event");
          final uuid = event['uuid'];
          final token = event['token'];
          if (uuid != null &&
              token != null &&
              uuid.isNotEmpty &&
              token.isNotEmpty) {
            await sendPushNotificationToken(uuid, token);
            if (uuid != Pst.pushNotificationUUID ||
                token != Pst.pushNotificationToken) {
              await Pst.savePushNotificationUUID(uuid);
              await Pst.savePushNotificationToken(token);
            }
          }
          break;
        case "file_receive":
          _logger.d("Receive file $event");
          final filePath = event['file_path'];
          if (filePath == null ||
              event['total_read'] == null ||
              event['file_size'] == null ||
              event['time'] == null) {
            _logger.e("Invalid file event");
            break;
          }
          late int received, total, time;
          try {
            received = event['total_read'] as int;
            total = event['file_size'] as int;
            time = event['time'] as int;
          } catch (e) {
            _logger.e("Failed to decode file event: $e");
          }
          if (received < 0 || total <= 0 || time < 0) {
            _logger.e(
              "Invalid receive and total size $received/$total in $time",
            );
            break;
          }
          final messageID = ChatStorage.getMessageIDFromFilename(filePath);
          if (messageID == null) {
            _logger.e("Invalid message id from $filePath");
            break;
          }
          _eventBus.fire(ProgressChangeEvent(
            messageID: messageID,
            bytes: received,
            total: total,
            time: time,
          ));
          break;
        case "logs":
          _logger.d("Received logs");
          ChatService.handleLogs(event['logs'] as String?);
          break;
        default:
          _logger.e("Unknown event type: ${event['type']} $event");
      }
      return;
    }
    if (event is ChatServiceStateEvent) {
      await _handleChatServiceStateEvent(event);
      return;
    }
    _logger.e("Unknown event object ${event.runtimeType} $event");
  }

  static Future<void> _handleChatServiceStateEvent(
    ChatServiceStateEvent event,
  ) async {
    final device =
        event.isSelfDevice ? Pst.selfDevice : await getDevice(event.deviceID);

    // Update device status.
    if (device == null) {
      _logger.e("Failed to find device for this update.");
      return;
    }
    switch (event.state) {
      case ChatServiceState.connected:
        device.isAvailable = true;
        device.isOnline = true;
        device.lastSeen = DateTime.now();
        break;
      default:
        device.isAvailable = false;
        device.isOnline = false;
        break;
    }
    try {
      if (device.id == Pst.selfDevice?.id) {
        await Pst.saveSelfDevice(device);
      }
      _logger.d("Update device: $device");
      await updateDevice(device);
    } catch (e) {
      _logger.e("failed to update self device: $e");
    }

    if ((event.deviceID != null && event.deviceID != Pst.selfDevice?.id) ||
        !event.isSelfDevice) {
      final from = event.from;
      if (from == null) {
        _logger.e("Invalid chat service instance: $event");
        return;
      }

      // A remote service is connected. Let's send our information.
      if (event.state == ChatServiceState.connected) {
        final self = Pst.selfUser;
        final selfDevice = Pst.selfDevice;
        if (self == null || selfDevice == null) {
          _logger.e("Invalid self user or device. $self $selfDevice");
          return;
        }
        final sender = {
          "profile": self,
          "device": selfDevice,
          "pn_uuid": Pst.pushNotificationUUID,
        };
        try {
          await from.sendMessage("SENDER:${jsonEncode(sender)}");
        } catch (e) {
          _logger.e(
            "failed to send message to "
            "${from.address}:${from.port}: $e",
          );
        }
      }
    }
  }

  static void _handleMessage(
    String message, {
    Function(String)? sendResponse,
  }) async {
    _logger.d("Got message ${message.shortString(256)}...");
    final lines = message.split("\n");
    for (var line in lines) {
      line = line.trim();
      if (line.isEmpty) {
        continue;
      }
      final parts = line.split(":");
      if (parts.length < 2) {
        _logger.e("Unknown message format: $line");
        continue;
      }
      final id = parts[1];
      switch (parts[0]) {
        case "CTRL":
          _logger.d("Received control message: $line");
          break;
        case "TEXT":
          handleReceiveChatMessage(line.replaceFirst("TEXT:$id:", ""));
          break;
        case "FILE_END":
          _logger.d("Received file ${line.replaceFirst("FILE_END:$id", "")}");
          break;
        case "NETWORK":
          final config = line.replaceFirst("NETWORK:", "");
          await _handleReceiveNetworkConfig(config);
          break;
        case "NETWORK_AVAILABLE":
          final v = id == "TRUE";
          if (isNetworkAvailable != v) {
            isNetworkAvailable = v;
            _eventBus.fire(ChatReceiveNetworkAvailableEvent(v));
          }
          break;
        default:
          _logger.e("Unknown message type $line");
      }
      sendResponse?.call('ACK:$id:DONE\n');
    }
  }

  static List<Device> deviceList = [];
  static bool _needsResolution(String address, String hostname) {
    _logger.d("Check if $hostname needs resolution from $address");
    return hostname.isEmpty || hostname == address;
  }

  static Future<void> _handleReceiveNetworkConfig(String config) async {
    _logger.d("Received network config: $config");
    dynamic json;
    try {
      json = jsonDecode(config);
    } catch (e) {
      _logger.e("Failed to decode network config: $e");
    }
    if (json is! List<dynamic>?) {
      _logger.e("Invalid network message type: ${json.runtimeType}");
      return;
    }
    if (json == null || json.isEmpty) {
      _updateNetworkConfig(
        newAddress: null,
        newHostname: null,
        newPort: null,
      );
      return;
    }
    try {
      json = await Future.wait(json.map((device) async {
        final address = device['address'] as String;
        var hostname = device['hostname'] as String;
        hostname = hostname.replaceAll(RegExp(r'\.+$'), '');
        device['hostname'] = hostname;

        if (_needsResolution(address, hostname) && isIPv4Address(address)) {
          _logger.i("Resolving hostname for $address");
          final resolvedHostname = await resolveHostname(address);
          return {
            ...device,
            'hostname': resolvedHostname,
          };
        }
        return device;
      }));

      final self = json.firstWhereOrNull(
        (c) =>
            (c['is_local'] ?? false) &&
            (isFQDN(c['hostname']) || isIPv4Address(c['address'])),
      );
      if (self == null) {
        _logger.e("invalid update with self device information: $json");
        return;
      }
      _logger.d("Notifying: ${self['address']} ${self['hostname']}");
      deviceList = json
          .where(
            (d) => d['address'] != "100.100.100.100" && (isFQDN(d['hostname'])),
          )
          .map(
            (d) => Device(
                userID: "",
                address: d['address'],
                hostname: d['hostname'],
                port: 0),
          )
          .toList();
      _updateNetworkConfig(
        newAddress: self['address'],
        newHostname: self['hostname'],
        newPort: self['port'],
      );
    } catch (e) {
      _logger.e("failed to process network config: $e");
    }
  }

  static Future<void> _handleReceiveSenderInformation(String sender) async {
    _logger.d("Received sender information: $sender");
    try {
      final json = jsonDecode(sender);
      final user = UserProfile.fromJson(json['profile']);
      final device = Device.fromJson(json['device']);
      final pnUUID = json['pn_uuid'] as String?;
      device.isAvailable = true;
      device.lastSeen = DateTime.now();
      device.isOnline = true;
      device.pnUUID = pnUUID;

      final contact = await getContact(user.id);
      if (contact == null) {
        // New contact.
        await addContact(
          Contact.fromUserProfile(user, devices: [device]),
        );
        return;
      }
      final idx = contact.devices.indexWhere((d) => d.id == device.id);
      if (idx < 0) {
        contact.devices.add(device);
      } else {
        contact.devices[idx] = device;
      }
      await updateContact(contact);
    } catch (e) {
      _logger.e("Failed to process sender: $e");
    }
  }

  static Future<void> _handleReceivePNInfo(String pnInfo) async {
    _logger.d("Received push notification information: $pnInfo");
    try {
      final parts = pnInfo.split(" ");
      if (parts.length != 2) {
        throw "invalid format: $pnInfo";
      }
      final hostname = parts[0];
      final pnUUID = parts[1];
      final device = await getDevice(Device.generateID(hostname));
      if (device == null) {
        final contacts = await getContacts();
        _logger.i(
            "failed to get device to update push notification: contacts=$contacts");
        throw "failed to get device for $hostname";
      }
      if (device.pnUUID == pnUUID) {
        _logger.d("push notification information is the same. skip...");
        return;
      }
      device.isAvailable = true;
      device.lastSeen = DateTime.now();
      device.isOnline = true;
      device.pnUUID = pnUUID;
      await updateDevice(device);
    } catch (e) {
      _logger.e("Failed to process push notificatin information: $e");
    }
  }

  static void handleReceiveChatMessage(String m) async {
    if (m.startsWith("SENDER:")) {
      final sender = m.replaceFirst("SENDER:", "");
      await _handleReceiveSenderInformation(sender);
      return;
    }
    if (m.startsWith("PN_INFO:")) {
      final pnInfo = m.replaceFirst("PN_INFO:", "");
      await _handleReceivePNInfo(pnInfo);
      return;
    }

    try {
      _logger.d("handle received chat message ${m.shortString(256)}...");
      final json = jsonDecode(m);
      if ((json['room_message'] as bool?) ?? false) {
        _handleRoomMessage(json);
        return;
      }

      final chatID = json['chat_id'];
      final machine = json['machine'];
      // Set the received message to be true for meta data
      final jsonData = jsonDecode(json['message']);
      Map<String, dynamic>? metaData = jsonData['metadata'];
      if (metaData == null) {
        metaData = <String, dynamic>{'received': true};
      } else {
        metaData['received'] = true;
      }
      jsonData['metadata'] = metaData;
      jsonData['status'] = "received";

      final message = types.Message.fromJson(jsonData);
      _receiveMessage(chatID, machine, message);
    } catch (e) {
      _logger.e("failed to process message $m: $e");
    }
  }

  static void _handleRoomMessage(Map<dynamic, dynamic> request) async {
    _logger.d("room message: $request");
    try {
      final chatID = request['chat_id']!;
      final machine = request['machine']!;
      if (chatID.isEmpty || machine.isEmpty) {
        throw Exception("empty chat id or source machine is not allowed");
      }

      final from = await getDevice(machine);
      if (from == null) {
        throw Exception("failed to get the peer device $machine");
      }

      if (request['method'] == "GET") {
        final room = await ChatStorage(chatID: chatID).getRoom();
        sendPeerRoom(chatID: chatID, peer: from, room: room);
        return;
      }

      final roomJson = request['room'];
      types.Room? room;
      if (roomJson != null) {
        if (roomJson is! Map<String, dynamic>) {
          throw Exception("invlaid message: $request");
        }
        room = types.Room.fromJson(roomJson);
      }

      if (room != null) {
        await ChatStorage(chatID: chatID).saveRoom(room);
      }

      switch (request['method']) {
        case "POST":
          _eventBus.fire(
            ChatReceiveNewRoomEvent(
              chatID: chatID,
              machine: machine,
              room: room,
            ),
          );
          break;
        case "PATCH":
          _eventBus.fire(
            ChatReceiveUpdateRoomEvent(
              chatID: chatID,
              machine: machine,
              room: room,
            ),
          );
          break;
        case "RESPONSE":
          _eventBus.fire(ChatReceiveRoomEvent(chatID: chatID, room: room));
        default:
          throw Exception("uknown request: $request");
      }
    } catch (e) {
      _logger.d("$e");
    }
  }

  static void _handleDeleteAll(
    types.Message message,
    ChatStorage storage,
  ) async {
    final user = ChatMessage.selfToAuthor();
    if (user == null) {
      _logger.w("received delete-all message. can't find my own id.");
      return;
    }
    _logger.i("delete all from ${message.author.id} mine is ${user.id}");
    if (message.author.id == user.id) {
      // Remove all messages if delete-all is sent from the same user.
      await storage.deleteMessagesFile();
    }
  }

  static void _receiveMessage(
    String chatID,
    String machine,
    types.Message message,
  ) async {
    _logger.d("received chat message to $chatID");
    _showNotification(chatID, machine, message);
    final storage = ChatStorage(chatID: chatID);
    message = await _fixMessageFilePath(storage, message);
    await storage.appendMessage(message);
    if (message is types.DeleteMessage && message.deleteAll) {
      _handleDeleteAll(message, storage);
    }
    _eventBus.fire(ChatReceiveEvent(
      chatID: chatID,
      machine: machine,
      message: message,
    ));
  }

  static Future<types.Message> _fixMessageFilePath(
    ChatStorage storage,
    types.Message message,
  ) async {
    var name = message.name;
    if (name != null) {
      name = ChatStorage.filenameWithMessageID(message.id, name);
      final uri = sharedFolderPath != null
          ? "$sharedFolderPath/$name"
          : await ChatStorage.getFileMessageUri(name);
      return (uri != null) ? message.copyWith(uri: uri) : message;
    }
    return message;
  }

  static Future<void> _showNotification(
    String chatID,
    String machine,
    types.Message message,
  ) async {
    // Not yet supported on Windows.
    if (Platform.isWindows) {
      return;
    }
    // Skip if on front.
    if (_activeChatID == chatID) {
      return;
    }

    String? hostname;
    // Only show the source device for a 1-on-1 chat on a single device.
    final machines = ChatID(id: chatID).machines;

    if (machines != null) {
      hostname = (await _contactsRepository?.getDevice(machine))?.hostname;
    }
    hostname = hostname != null ? '[$hostname]' : '';
    final id = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final title = "${message.author.firstName}$hostname";
    if (message is types.CustomMessage) {
      final meta = message.metadata;
      final command = meta?['command'];
      final from = meta?['from_user'];
      if (meta?['sub_type'] == "Video Call") {
        if (_appIsActive) {
          _logger.d("app is active. skip notifications...");
          return;
        }
        if (command == "dial") {
          // Check if it is out of date since APP may have been inactive
          // for a long time.
          // todo: move the notification trigger to cylonixd.
          final expiresAt = DateTime.fromMillisecondsSinceEpoch(
            (message.createdAt ?? 0) + 30000,
          );
          final createdAt = DateTime.fromMillisecondsSinceEpoch(
            message.createdAt ?? 0,
          );
          if (DateTime.now().isBefore(expiresAt)) {
            // Use incoming call notification for incoming video call.
            //final server = meta?['server'];
            //final room = meta?['room'];
            //await Global.showIncomingCallNotification(id, from, server, room);
            return;
          } else {
            _logger.d("expired dialing from $from $createdAt $expiresAt");
          }
        }
        // Fall through for normal notifications.
      }
    }

    await notify(id, title, message.summary);
  }
}
