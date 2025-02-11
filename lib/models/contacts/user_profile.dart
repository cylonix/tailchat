// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'package:uuid/uuid.dart';

class UserProfile {
  final String id;
  final int createdAt;
  String name;
  String username;
  String? profileUrl;
  String? status;
  UserProfile({
    String? id,
    required this.username,
    String? name,
    this.profileUrl,
    this.status,
  })  : id = id ?? const Uuid().v5(Namespace.nil.value, username).toString(),
        name = name ?? username.split("@")[0],
        createdAt = DateTime.now().millisecondsSinceEpoch;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'username': username,
        'profileUrl': profileUrl,
        'status': status,
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        id: json['id'],
        name: json['name'],
        username: json['username'],
        profileUrl: json['profileUrl'],
        status: json['status'],
      );
}
