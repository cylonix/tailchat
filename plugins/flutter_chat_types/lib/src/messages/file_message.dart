import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';
import '../message.dart';
import '../preview_data.dart' show PreviewData;
import '../user.dart' show User;
import '../util.dart' show shortFileName;
import 'partial_file.dart';

part 'file_message.g.dart';

/// A class that represents file message.
@JsonSerializable(explicitToJson: true, includeIfNull: false)
@immutable
class FileMessage extends Message {
  /// Creates a file message.
  const FileMessage({
    required User author,
    int? createdAt,
    required String id,
    Map<String, dynamic>? metadata,
    this.mimeType,
    required this.name,
    String? remoteId,
    String? roomId,
    String? caption,
    String? replyId,
    required this.size,
    Status? status,
    this.percentage,
    MessageType? type,
    int? updatedAt,
    int? expireAt,
    required this.uri,
  }) : super(
          author,
          createdAt,
          id,
          metadata,
          remoteId,
          roomId,
          caption,
          status,
          type ?? MessageType.file,
          updatedAt,
          replyId,
          expireAt,
        );

  /// Creates a full file message from a partial one.
  FileMessage.fromPartial({
    required User author,
    int? createdAt,
    required String id,
    required PartialFile partialFile,
    String? remoteId,
    String? roomId,
    String? caption,
    String? replyId,
    Status? status,
    double? percent,
    int? updatedAt,
    int? expireAt,
  })  : mimeType = partialFile.mimeType,
        name = partialFile.name,
        size = partialFile.size,
        uri = partialFile.uri,
        percentage = percent,
        super(
          author,
          createdAt,
          id,
          partialFile.metadata,
          remoteId,
          roomId,
          caption,
          status,
          MessageType.file,
          updatedAt,
          replyId,
          expireAt,
        );

  /// Creates a file message from a map (decoded JSON).
  factory FileMessage.fromJson(Map<String, dynamic> json) =>
      _$FileMessageFromJson(json);

  /// Converts a file message to the map representation, encodable to JSON.
  @override
  Map<String, dynamic> toJson() => _$FileMessageToJson(this);

  /// Creates a copy of the file message with an updated data.
  /// [metadata] with null value will nullify existing metadata, otherwise
  /// both metadata will be merged into one Map, where keys from a passed
  /// metadata will overwrite keys from the previous one.
  /// [previewData] is ignored for this message type.
  /// [remoteId] and [updatedAt] with null values will nullify existing value.
  /// [status] and [uri] with null values will be overwritten by previous values.
  /// [text] is ignored for this message type.
  @override
  Message copyWith({
    String? id,
    User? author,
    Map<String, dynamic>? metadata,
    PreviewData? previewData,
    String? remoteId,
    Status? status,
    double? percentage,
    String? text,
    int? updatedAt,
    int? createdAt,
    int? expireAt,
    String? uri,
  }) {
    return FileMessage(
      author: author ?? this.author,
      createdAt: createdAt ?? this.createdAt,
      id: id ?? this.id,
      metadata: metadata == null
          ? null
          : {
              ...this.metadata ?? {},
              ...metadata,
            },
      mimeType: mimeType,
      name: name,
      remoteId: remoteId,
      roomId: roomId,
      caption: caption,
      size: size,
      status: status ?? this.status,
      percentage: percentage,
      updatedAt: updatedAt,
      uri: uri ?? this.uri,
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
        mimeType,
        name,
        remoteId,
        roomId,
        size,
        status,
        percentage,
        updatedAt,
        uri,
        replyId,
      ];

  /// Media type
  final String? mimeType;

  /// The name of the file
  @override
  final String name;

  /// Size of the file in bytes
  final num size;

  /// The file source (either a remote URL or a local resource)
  @override
  final String uri;

  /// The percentage for file sending
  final double? percentage;

  String get shortName {
    return shortFileName(name);
  }

  @override
  String get summary {
    return 'File: $shortName';
  }

  @override
  bool get canSave {
    return true;
  }

  @override
  bool get retry {
    return false;
  }
}
