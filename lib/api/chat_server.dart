// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:collection/collection.dart';
import 'package:event_bus/event_bus.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import '../api/notification.dart';
import '../models/chat/chat_event.dart';
import '../models/chat/chat_id.dart';
import '../models/chat/chat_message.dart';
import '../models/chat/chat_storage.dart';
import '../models/contacts/contact.dart';
import '../models/contacts/contacts_repository.dart';
import '../models/contacts/device.dart';
import '../models/contacts/user_profile.dart';
import '../utils/logger.dart';
import '../utils/utils.dart';
import 'chat_service.dart';
import 'config.dart';
import 'contacts.dart';
import 'dns.dart';
import 'send_chat.dart';

class ChatServer {
  static var _serverStarted = false;
  static final _eventBus = EventBus();
  static String? _activeChatID;
  static bool _appIsActive = false;
  static final _logger = Logger(tag: "ChatServer");
  static ChatService? _chatService;
  static ContactsRepository? _contactsRepository;

  static EventBus getChatEventBus() {
    return _eventBus;
  }

  static void setAppIsActive(bool active) {
    _logger.d("app is active = $active");
    _appIsActive = active;
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

  static void startServer() async {
    _logger.i("Starting chat server");
    if (_serverStarted) {
      _logger.i("chat server has been started or is starting. skip...");
      return;
    }
    _serverStarted = true;
    _chatService ??= ChatService();
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
    await _chatService?.startServiceStateMonitor();
    _logger.i("Done starting service");
  }

  static get isServiceSocketConnected {
    _logger.i("Service connected: ${_chatService?.isServiceSocketConnected}");
    return _chatService?.isServiceSocketConnected ?? false;
  }

  static bool hasSubscribedToMessages = false;
  static void subscribeToMessages() {
    if (hasSubscribedToMessages) {
      _logger.d("Already subscribed to messages. Skip.");
      return;
    }
    hasSubscribedToMessages = true;
    if (isMobile() || Platform.isMacOS) {
      _logger.i("Starting to listen to chat messages");
      ChatService.subscribeToMessages().listen(_handleChatServiceMessage);
    } else {
      _logger.i("Starting to listening to subscriber socket");
      _chatService?.listenToSubscriberSocket(_handleMessage);
    }
  }

  static void _handleChatServiceMessage(dynamic message) {
    _logger.d("Received message from chat service: $message");
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
  }) {
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
  }

  /// Handle flutter event channel events.
  static void _handleEvent(dynamic event) async {
    _logger.d("Received event from chat service: $event");
    if (event is Map<dynamic, dynamic>) {
      switch (event['type']) {
        case "network_config":
          _logger.i("Network config: $event");
          await _handleReceiveNetworkConfig(event['devices']);
          break;
        case "pn_info":
          _logger.d("Received push notification info: $event");
          final uuid = event['uuid'];
          if (uuid != null) {
            await Pst.savePushNotificationUUID(uuid);
          }
          break;
        case "file_receive":
          _logger.d("Receive file $event");
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
    ChatService? from = event.from;
    if (from == null) {
      _logger.e("Invalid chat service instance: $event");
      return;
    }

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

    if (event.deviceID != null && event.deviceID != Pst.selfDevice?.id) {
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
            "${from.serverAddress}:${from.port}: $e",
          );
        }
      }
    }
  }

  static void _handleMessage(String message) async {
    _logger.d("Got message $message");
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
          _handleReceiveChatMessage(line.replaceFirst("TEXT:$id:", ""));
          break;
        case "FILE_END":
          _logger.d("Received file ${line.replaceFirst("FILE_END:$id", "")}");
          break;
        case "NETWORK":
          final config = line.replaceFirst("NETWORK:", "");
          await _handleReceiveNetworkConfig(config);
          break;
        default:
          _logger.e("Unknown message type $line");
      }
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
        final hostname = device['hostname'] as String;

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
    _logger.d("Receive sender information: $sender");
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

  static void _handleReceiveChatMessage(String m) async {
    if (m.startsWith("SENDER:")) {
      final sender = m.replaceFirst("SENDER:", "");
      await _handleReceiveSenderInformation(sender);
      return;
    }

    try {
      _logger.d("handle received chat message $m");
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
      final uri = await ChatStorage.getFileMessageUri(name);
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
