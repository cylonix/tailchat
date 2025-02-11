// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'dart:convert';

class FriendInfo {
  final String userName;
  final String id;
  final int? int64ID;
  List<String> labels;
  FriendInfo({
    required this.userName,
    required this.id,
    this.int64ID,
    required this.labels,
  });
  factory FriendInfo.fromJson(Map<String, dynamic> json) {
    List<String> labelList = <String>[];
    List<dynamic> labels = json['label'] ?? [];
    if (labels.isNotEmpty) {
      for (var value in labels) {
        labelList.add(value.toString());
      }
    }
    return FriendInfo(
      userName: json["Name"].toString(),
      id: json["ID"].toString(),
      int64ID: json['Int64ID'],
      labels: labelList,
    );
  }
  Map<String, dynamic> toJson() => {
        "Name": userName,
        "ID": id,
        "Int64ID": int64ID,
      };
  @override
  String toString() {
    return json.encode(this);
  }
}
