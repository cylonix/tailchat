import 'package:flutter/foundation.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';
import '../message.dart';
import '../preview_data.dart' show PreviewData;
import '../user.dart' show User;
import 'partial_text.dart';

part 'text_message.g.dart';

/// A class that represents text message.
@JsonSerializable(explicitToJson: true, includeIfNull: false)
@immutable
class TextMessage extends Message {
  /// Creates a text message.
  const TextMessage({
    required User author,
    int? createdAt,
    required String id,
    Map<String, dynamic>? metadata,
    this.previewData,
    String? remoteId,
    String? roomId,
    String? caption,
    String? replyId,
    Status? status,
    required this.text,
    MessageType? type,
    int? updatedAt,
    int? expireAt,
  }) : super(
          author,
          createdAt,
          id,
          metadata,
          remoteId,
          roomId,
          caption,
          status,
          type ?? MessageType.text,
          updatedAt,
          replyId,
          expireAt,
        );

  /// Creates a full text message from a partial one.
  TextMessage.fromPartial({
    required User author,
    int? createdAt,
    required String id,
    required PartialText partialText,
    String? remoteId,
    String? roomId,
    String? caption,
    String? replyId,
    Status? status,
    int? updatedAt,
    int? expireAt,
  })  : previewData = partialText.previewData,
        text = partialText.text,
        super(
          author,
          createdAt,
          id,
          partialText.metadata,
          remoteId,
          roomId,
          caption,
          status,
          MessageType.text,
          updatedAt,
          replyId,
          expireAt,
        );

  /// Creates a text message from a map (decoded JSON).
  factory TextMessage.fromJson(Map<String, dynamic> json) =>
      _$TextMessageFromJson(json);

  /// Converts a text message to the map representation, encodable to JSON.
  @override
  Map<String, dynamic> toJson() => _$TextMessageToJson(this);

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
    return TextMessage(
      author: author ?? this.author,
      createdAt: createdAt ?? this.createdAt,
      expireAt: expireAt ?? this.expireAt,
      id: id ?? this.id,
      metadata: metadata == null
          ? null
          : {
              ...this.metadata ?? {},
              ...metadata,
            },
      previewData: previewData,
      remoteId: remoteId,
      roomId: roomId,
      caption: caption,
      status: status ?? this.status,
      text: text ?? this.text,
      updatedAt: updatedAt,
      replyId: replyId,
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

  /// See [PreviewData]
  final PreviewData? previewData;

  /// User's message
  final String text;

  @override
  String get summary {
    return text.runes.length > 20
        ? "${String.fromCharCodes(text.runes.toList().sublist(0, 20))}..."
        : text;
  }
}
