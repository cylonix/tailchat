import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';
import 'file_message.dart';

part 'partial_file.g.dart';

/// A class that represents partial file message.
@JsonSerializable(explicitToJson: true)
@immutable
class PartialFile {
  /// Creates a partial file message with all variables file can have.
  /// Use [FileMessage] to create a full message.
  /// You can use [FileMessage.fromPartial] constructor to create a full
  /// message from a partial one.
  const PartialFile({
    this.metadata,
    this.mimeType,
    required this.name,
    required this.size,
    required this.uri,
  });

  /// Creates a partial file message from a map (decoded JSON).
  factory PartialFile.fromJson(Map<String, dynamic> json) =>
      _$PartialFileFromJson(json);

  /// Converts a partial file message to the map representation, encodable to JSON.
  Map<String, dynamic> toJson() => _$PartialFileToJson(this);

  /// Additional custom metadata or attributes related to the message
  final Map<String, dynamic>? metadata;

  /// Media type
  final String? mimeType;

  /// The name of the file
  final String name;

  /// Size of the file in bytes
  final num size;

  /// The file source (either a remote URL or a local resource)
  final String uri;
}
