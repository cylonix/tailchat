// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'dart:convert';

class FileMeta {
  final String chatID;
  final String messageID;
  final String name;
  const FileMeta({
    required this.chatID,
    required this.messageID,
    required this.name,
  });
  factory FileMeta.fromJson(Map<String, dynamic> json) {
    return FileMeta(
      name: json['Name'],
      chatID: json['ChatID'],
      messageID: json['MessageID'],
    );
  }
  Map<String, dynamic> toJson() {
    return {
      "ChatID": chatID,
      "MessageID": messageID,
      "Name": name,
    };
  }

  @override
  String toString() {
    return jsonEncode(this);
  }
}

class WaitingFile {
  final FileMeta? meta;
  final String name;
  final int size;
  const WaitingFile({
    required this.meta,
    required this.name,
    required this.size,
  });
  factory WaitingFile.fromJson(Map<String, dynamic> json) {
    FileMeta? meta;
    if (json["Meta"] != null && json["Meta"].isNotEmpty) {
      meta = FileMeta.fromJson(jsonDecode(json["Meta"]));
    }
    return WaitingFile(name: json['Name'], size: json["Size"], meta: meta);
  }
  Map<String, dynamic> toJson() {
    return {
      "Meta": meta,
      "Name": name,
      "Size": size,
    };
  }

  @override
  String toString() {
    return jsonEncode(this);
  }
}
