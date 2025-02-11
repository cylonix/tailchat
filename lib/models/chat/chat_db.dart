// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'dart:convert';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
class Message {
  /// Message local db index.
  final int id;

  /// Message global uuid.
  final String uuid;

  /// Message type [types.MessageType].
  final types.MessageType type;

  /// Message sender global uuid.
  final String senderID;

  /// Message creation time in ms.
  final int? createdAt;

  /// Message update time in ms.
  final int? updatedAt;

  /// Message to be expired time in ms.
  final int? exipreAt;

  /// Text message content or file/image message caption.
  final String? text;

  /// File or image name or custom emoji unicode.
  final String? name;

  /// UUID of the room where this message is sent.
  final String? roomID;

  /// Message ID that this message is replying to.
  final String? replyToID;

  /// Message [types.Status]
  final types.Status? status;

  /// Meta data.
  final Map<String, dynamic>? metaData;

  const Message({
    required this.id,
    required this.uuid,
    required this.type,
    required this.senderID,
    this.createdAt,
    this.exipreAt,
    this.updatedAt,
    this.text,
    this.name,
    this.roomID,
    this.replyToID,
    this.status,
    this.metaData,
  });

  Map<String, Object?> toMap() {
    return {
      "id": id == 0 ? null : id,
      "uuid": uuid,
      "type": type.index,
      "sender_id": senderID,
      "created_at": createdAt,
      "updated_at": updatedAt,
      "expire_at": exipreAt,
      "text": text,
      "name": name,
      "room_id": roomID,
      "reply_to_id": replyToID,
      "status": status?.index,
      "meta_data": jsonEncode(metaData),
    };
  }

}
