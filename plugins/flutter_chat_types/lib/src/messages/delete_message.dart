import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';
import '../message.dart';
import '../preview_data.dart' show PreviewData;
import '../user.dart' show User;

part 'delete_message.g.dart';

/// A class that represents delete message. Use [metadata] to store anything
/// you want.
@JsonSerializable(explicitToJson: true, includeIfNull: false)
@immutable
class DeleteMessage extends Message {
  /// Creates a delete message.
  const DeleteMessage({
    required User author,
    int? createdAt,
    required String id,
    Map<String, dynamic>? metadata,
    String? remoteId,
    String? roomId,
    String? caption,
    Status? status,
    String? replyId,
    MessageType? type,
    int? updatedAt,
    this.deleteAll = false,
    this.summary = "",
  }) : super(
          author,
          createdAt,
          id,
          metadata,
          remoteId,
          roomId,
          caption,
          status,
          MessageType.delete,
          updatedAt,
          replyId,
          null,
        );

  factory DeleteMessage.fromMessage(Message message) {
    return DeleteMessage(
      author: message.author,
      id: message.id,
      remoteId: message.remoteId,
      roomId: message.roomId,
      caption: message.caption,
      status: Status.toretry,
      summary: 'Delete: ${message.summary}',
    );
  }

  factory DeleteMessage.deleteAll(User author, String id) {
    return DeleteMessage(
      author: author,
      id: id,
      deleteAll: true,
      status: Status.toretry,
      summary: 'Delete All: ${author.firstName}',
    );
  }

  /// Creates a delete message from a map (decoded JSON).
  factory DeleteMessage.fromJson(Map<String, dynamic> json) =>
      _$DeleteMessageFromJson(json);

  /// Converts a delete message to the map representation,
  /// encodable to JSON.
  @override
  Map<String, dynamic> toJson() => _$DeleteMessageToJson(this);

  /// Creates a copy of the delete message with an updated data.
  /// [metadata] with null value will nullify existing metadata, otherwise
  /// both metadata will be merged into one Map, where keys from a passed
  /// metadata will overwrite keys from the previous one.
  /// [previewData] is ignored for this message type.
  /// [remoteId] and [updatedAt] with null values will nullify existing value.
  /// [status] with null value will be overwritten by the previous status.
  /// [text] is ignored for this message type.
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
    return DeleteMessage(
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
      status: status ?? this.status,
      updatedAt: updatedAt,
      summary: summary,
      replyId: replyId,
      deleteAll: deleteAll,
    );
  }

  /// Delete all messages from the author.
  final bool deleteAll;

  /// Equatable props
  @override
  List<Object?> get props => [
        author,
        createdAt,
        id,
        metadata,
        remoteId,
        roomId,
        caption,
        status,
        updatedAt,
        replyId,
        deleteAll,
      ];

  @override
  final String summary;
}
