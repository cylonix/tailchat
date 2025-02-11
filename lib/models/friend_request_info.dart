// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'dart:convert';

class FriendRequestInfo {
  final String? username;
  final String note;
  final String id;
  final String? requestTime;
  FriendRequestInfo({
    this.username,
    required this.note,
    required this.id,
    this.requestTime,
  });
  factory FriendRequestInfo.fromJson(Map<String, dynamic> json) {
    String? time = json['Date'];
    return FriendRequestInfo(
      username: json["Username"].toString(),
      note: json["Note"].toString(),
      id: json["ID"].toString(),
      requestTime: time,
    );
  }
  Map<String, dynamic> toJson() => {
    "Note": note,
    "ID": id,
  };
  @override
  String toString() {
    return json.encode(this);
  }
}
