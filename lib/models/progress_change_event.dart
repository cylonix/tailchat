// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

class ProgressChangeEvent {
  final String chatID;
  final String messageID;
  final String peer;
  final int bytes;
  final int total;
  final int time; // ms
  ProgressChangeEvent({
    required this.chatID,
    required this.messageID,
    required this.peer,
    required this.bytes,
    required this.total,
    required this.time,
  });
  @override
  String toString() {
    return "messageID=$messageID: $bytes/$total";
  }
}
