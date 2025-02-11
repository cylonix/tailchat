import 'package:flutter/foundation.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';
import '../message.dart';
import '../preview_data.dart' show PreviewData;
import '../user.dart' show User;
import 'text_message.dart';

// A special message to send private emojis to each other.
part 'emoji_message.g.dart';

/// A class that represents text message containing just private emojis.
@JsonSerializable(explicitToJson: true, includeIfNull: false)
@immutable
class EmojiMessage extends TextMessage {
  /// Creates a text message.
  const EmojiMessage({
    required User author,
    int? createdAt,
    required String id,
    Map<String, dynamic>? metadata,
    String? remoteId,
    String? roomId,
    String? caption,
    Status? status,
    String? replyId,
    required String text, // Emojis in private unicode
    MessageType? type,
    int? updatedAt,
    int? expireAt,
  }) : super(
          text: text,
          author: author,
          createdAt: createdAt,
          id: id,
          metadata: metadata,
          remoteId: remoteId,
          roomId: roomId,
          caption: caption,
          status: status,
          type: type ?? MessageType.emoji,
          updatedAt: updatedAt,
          replyId: replyId,
          expireAt: expireAt,
        );

  /// Creates from a map (decoded JSON).
  factory EmojiMessage.fromJson(Map<String, dynamic> json) =>
      _$EmojiMessageFromJson(json);

  /// Converts to the map representation, encodable to JSON.
  @override
  Map<String, dynamic> toJson() => _$EmojiMessageToJson(this);

  /// Creates a copy of the text message with an updated data
  /// [metadata] with null value will nullify existing metadata, otherwise
  /// both metadata will be merged into one Map, where keys from a passed
  /// metadata will overwrite keys from the previous one.
  /// [remoteId] and [updatedAt] with null values will nullify existing value.
  /// [status] and [text] with null values will be overwritten by previous values.
  /// [uri] is ignored for this message type.
  @override
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
  }) {
    return EmojiMessage(
      author: author ?? this.author,
      createdAt: createdAt ?? this.createdAt,
      id: id ?? this.id,
      metadata: metadata == null
          ? null
          : {
              ...this.metadata ?? {},
              ...metadata,
            },
      remoteId: remoteId,
      roomId: roomId,
      caption: caption,
      replyId: replyId,
      status: status ?? this.status,
      text: text ?? this.text,
      updatedAt: updatedAt,
      expireAt: expireAt,
    );
  }

  /// Equatable props
  @override
  List<Object?> get props => [
        author,
        createdAt,
        id,
        metadata,
        previewData,
        remoteId,
        roomId,
        caption,
        status,
        text,
        updatedAt,
        replyId,
      ];

  String get shortText {
    return text.runes.length > 5
        ? String.fromCharCodes(text.runes.toList().sublist(0, 5))
        : text;
  }

  /// Return smaller set of substring with utf-16 code points.
  @override
  String get summary {
    return 'Emoji: $shortText';
  }
}
