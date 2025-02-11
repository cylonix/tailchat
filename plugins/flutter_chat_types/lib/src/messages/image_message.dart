import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';
import '../message.dart';
import '../preview_data.dart' show PreviewData;
import '../user.dart' show User;
import '../util.dart' show shortFileName;
import 'partial_image.dart';

part 'image_message.g.dart';

/// A class that represents image message.
@JsonSerializable(explicitToJson: true, includeIfNull: false)
@immutable
class ImageMessage extends Message {
  /// Creates an image message.
  const ImageMessage({
    required User author,
    int? createdAt,
    int? expireAt,
    this.height,
    required String id,
    Map<String, dynamic>? metadata,
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
    required this.uri,
    this.width,
    this.isEmoji = false,
  }) : super(
          author,
          createdAt,
          id,
          metadata,
          remoteId,
          roomId,
          caption,
          status,
          type ?? MessageType.image,
          updatedAt,
          replyId,
          expireAt,
        );

  /// Creates a full image message from a partial one.
  ImageMessage.fromPartial({
    required User author,
    int? createdAt,
    required String id,
    required PartialImage partialImage,
    String? remoteId,
    String? roomId,
    String? caption,
    String? replyId,
    Status? status,
    double? percent,
    int? updatedAt,
    int? expireAt,
  })  : height = partialImage.height,
        name = partialImage.name,
        size = partialImage.size,
        uri = partialImage.uri,
        width = partialImage.width,
        isEmoji = false,
        percentage = percent,
        super(
          author,
          createdAt,
          id,
          partialImage.metadata,
          remoteId,
          roomId,
          caption,
          status,
          MessageType.image,
          updatedAt,
          replyId,
          expireAt,
        );

  /// Creates an image message from a map (decoded JSON).
  factory ImageMessage.fromJson(Map<String, dynamic> json) =>
      _$ImageMessageFromJson(json);

  /// Converts an image message to the map representation, encodable to JSON.
  @override
  Map<String, dynamic> toJson() => _$ImageMessageToJson(this);

  /// Creates a copy of the image message with an updated data
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
    return ImageMessage(
      author: author ?? this.author,
      createdAt: createdAt ?? this.createdAt,
      expireAt: expireAt ?? this.expireAt,
      height: height,
      id: id ?? this.id,
      metadata: metadata == null
          ? null
          : {
              ...this.metadata ?? {},
              ...metadata,
            },
      name: name,
      remoteId: remoteId,
      roomId: roomId,
      caption: caption,
      size: size,
      status: status ?? this.status,
      percentage: percentage,
      updatedAt: updatedAt,
      uri: uri ?? this.uri,
      width: width,
      isEmoji: isEmoji,
      replyId: replyId,
    );
  }

  /// Equatable props
  @override
  List<Object?> get props => [
        author,
        createdAt,
        height,
        id,
        metadata,
        name,
        remoteId,
        roomId,
        caption,
        size,
        status,
        percentage,
        updatedAt,
        uri,
        width,
        replyId,
      ];

  final bool isEmoji;

  /// Image height in pixels
  final double? height;

  /// The name of the image
  @override
  final String name;

  /// Size of the image in bytes
  final num size;

  /// The image source (either a remote URL or a local resource)
  @override
  final String uri;

  /// Image width in pixels
  final double? width;

  /// The percentage for image sending
  final double? percentage;

  String get shortName {
    return shortFileName(name);
  }

  @override
  String get summary {
    return 'Image: $shortName';
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
