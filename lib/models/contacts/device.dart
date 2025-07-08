// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'dart:convert';
import 'package:uuid/uuid.dart';

const defaultPort = 50311;

class Device {
  final String id;
  String userID;
  String address;
  String hostname;
  String os;
  String? pnUUID;
  int port;
  DateTime lastSeen;
  bool isOnline;
  final bool isPhysical;
  bool isAvailable;

  Device({
    required this.userID,
    required this.address,
    required this.hostname,
    this.port = defaultPort,
    this.os = "",
    this.pnUUID,
    this.isAvailable = false,
    this.isOnline = false,
    this.isPhysical = false,
    DateTime? lastSeen,
  })  : id = generateID(hostname),
        lastSeen = lastSeen ?? DateTime.now();

  static String generateID(String hostname) {
    return Uuid().v5(Namespace.dns.value, hostname.trim().toLowerCase());
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        "user_id": userID,
        'address': address,
        'hostname': hostname,
        'port': port,
        "os": os,
        'pnUUID': pnUUID,
        'lastSeen': lastSeen.toIso8601String(),
        'isOnline': isOnline,
        'isPhysical': isPhysical,
        "isAvailable": isAvailable,
      };

  factory Device.fromJson(Map<String, dynamic> json) => Device(
        userID: json['user_id'],
        address: json['address'],
        hostname: json['hostname'],
        port: json['port'],
        os: json['os'],
        pnUUID: json['pnUUID'],
        lastSeen: DateTime.parse(json['lastSeen']),
        isOnline: json['isOnline'] ?? false,
        isAvailable: json['isAvailable'] ?? false,
        isPhysical: json['isPhysical'] ?? false,
      );

  @override
  String toString() {
    return jsonEncode(this);
  }

  String get title {
    if (hostname == address) {
      return hostname;
    }
    return hostname.split('.').first;
  }

  List<String> get subtitles {
    if (hostname == address) {
      return [];
    }
    return [hostname.replaceFirst('$title.', ''), address];
  }
}
