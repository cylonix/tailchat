import 'package:equatable/equatable.dart';
import 'package:flutter_chat_types/src/messages/emoji_message.dart';
import 'package:meta/meta.dart';
import 'messages/custom_message.dart';
import 'messages/delete_message.dart';
import 'messages/file_message.dart';
import 'messages/image_message.dart';
import 'messages/text_message.dart';
import 'messages/unsupported_message.dart';
import 'preview_data.dart' show PreviewData;
import 'user.dart' show User;

/// All possible message types.
enum MessageType { custom, delete, emoji, file, image, text, unsupported }

/// All possible statuses message can have.
enum Status {
  delivered,
  error,
  seen,
  sending,
  toretry,
  retrying,
  sent,
  received,
  paused,
}

/// An abstract class that contains all variables and methods
/// every message will have.
@immutable
abstract class Message extends Equatable {
  const Message(
    this.author,
    this.createdAt,
    this.id,
    this.metadata,
    this.remoteId,
    this.roomId,
    this.caption,
    this.status,
    this.type,
    this.updatedAt,
    this.replyId,
    this.expireAt,
  );

  /// Creates a particular message from a map (decoded JSON).
  /// Type is determined by the `type` field.
  factory Message.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String;

    switch (type) {
      case 'custom':
        return CustomMessage.fromJson(json);
      case 'file':
        return FileMessage.fromJson(json);
      case 'image':
        return ImageMessage.fromJson(json);
      case 'text':
        return TextMessage.fromJson(json);
      case 'delete':
        return DeleteMessage.fromJson(json);
      case 'emoji':
        return EmojiMessage.fromJson(json);
      default:
        return UnsupportedMessage.fromJson(json);
    }
  }

  /// Creates a copy of the message with an updated data
  /// [metadata] with null value will nullify existing metadata, otherwise
  /// both metadata will be merged into one Map, where keys from a passed
  /// metadata will overwrite keys from the previous one.
  /// [previewData] will be only set for the text message type.
  /// [status] with null value will be overwritten by the previous status.
  /// [text] will be only set for the text message type. Null value will be
  /// overwritten by the previous text (can't be empty).
  /// [remoteId] and [updatedAt] with null values will nullify existing value.
  /// [uri] will be only set for file and image message types. Null value
  /// will be overwritten by the previous value (uri can't be empty).
  Message copyWith({
    String? id,
    User? author,
    Map<String, dynamic>? metadata,
    PreviewData? previewData,
    String? remoteId,
    Status? status,
    String? text,
    int? updatedAt,
    int? createdAt,
    int? expireAt,
    String? uri,
  });

  /// Converts a particular message to the map representation, encodable to JSON.
  Map<String, dynamic> toJson();

  /// User who sent this message
  final User author;

  /// Created message timestamp, in ms
  final int? createdAt;

  /// Expiration timestamp, in ms
  final int? expireAt;

  /// Unique ID of the message
  final String id;

  /// Additional custom metadata or attributes related to the message
  final Map<String, dynamic>? metadata;

  /// Unique ID of the message received from the backend
  final String? remoteId;

  /// ID of the room where this message is sent
  final String? roomId;

  /// Caption of the message. This is more applicable for file/image messages.
  final String? caption;

  /// Message [Status]
  final Status? status;

  /// [MessageType]
  final MessageType type;

  /// Updated message timestamp, in ms
  final int? updatedAt;

  /// Message ID that this message is replying to
  final String? replyId;

  String get summary {
    return "";
  }

  String? get name {
    return null;
  }

  String? get uri {
    return null;
  }

  bool get canSave {
    return false;
  }

  bool get retry {
    return true;
  }
}
