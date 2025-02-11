// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'dart:convert';
import 'device.dart';
import 'user_profile.dart';

// Contact ID is local significant. It is used to identify contacts in the
// local storage. Device ID is a hash of the hostname and is used to identify
// the device in the network.
class Contact extends UserProfile {
  List<Device> devices;

  Contact({
    super.id,
    required super.username,
    super.name,
    super.profileUrl,
    super.status,
    List<Device>? devices,
  }) : devices = devices ?? [];

  static generateID(String username) {
    return UserProfile(username: username.trim().toLowerCase()).id;
  }

  @override
  Map<String, dynamic> toJson() {
    final m = super.toJson();
    m['devices'] = devices.map((d) => d.toJson()).toList();
    return m;
  }

  factory Contact.fromJson(Map<String, dynamic> json) => Contact(
        name: json['name'],
        username: json['username'],
        profileUrl: json['profileUrl'],
        status: json['status'],
        devices: (json['devices'] as List?)
                ?.map((d) => Device.fromJson(d))
                .toList() ??
            [],
      );
  factory Contact.fromUserProfile(
    UserProfile user, {
    String? status,
    List<Device>? devices,
  }) =>
      Contact(
        name: user.name,
        username: user.username,
        profileUrl: user.profileUrl,
        status: user.status,
        devices: devices,
      );

  bool get isOnline {
    return devices.any((d) => d.isOnline);
  }

  DateTime? get lastSeen {
    DateTime? t;
    for (var d in devices) {
      if (t == null || d.lastSeen.isAfter(t)) {
        t = d.lastSeen;
        continue;
      }
    }
    return t;
  }

  @override
  String toString() {
    return jsonEncode(this);
  }
}
