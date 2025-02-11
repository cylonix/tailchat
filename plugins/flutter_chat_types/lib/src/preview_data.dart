import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';

part 'preview_data.g.dart';

/// A class that represents data obtained from the web resource (link preview).
///
/// See https://github.com/flyerhq/flutter_link_previewer
@JsonSerializable(explicitToJson: true)
@immutable
class PreviewData extends Equatable {
  /// Creates preview data.
  const PreviewData({
    this.description,
    this.image,
    this.link,
    this.title,
  });

  /// Creates preview data from a map (decoded JSON).
  factory PreviewData.fromJson(Map<String, dynamic> json) =>
      _$PreviewDataFromJson(json);

  /// Converts preview data to the map representation, encodable to JSON.
  Map<String, dynamic> toJson() => _$PreviewDataToJson(this);

  /// Creates a copy of the preview data with an updated data.
  /// Null values will nullify existing values.
  PreviewData copyWith({
    String? description,
    PreviewDataImage? image,
    String? link,
    String? title,
  }) {
    return PreviewData(
      description: description,
      image: image,
      link: link,
      title: title,
    );
  }

  /// Equatable props
  @override
  List<Object?> get props => [description, image, link, title];

  /// Link description (usually og:description meta tag)
  final String? description;

  /// See [PreviewDataImage]
  final PreviewDataImage? image;

  /// Remote resource URL
  final String? link;

  /// Link title (usually og:title meta tag)
  final String? title;
}

/// A utility class that forces image's width and height to be stored
/// alongside the url.
///
/// See https://github.com/flyerhq/flutter_link_previewer
@JsonSerializable(explicitToJson: true)
@immutable
class PreviewDataImage extends Equatable {
  /// Creates preview data image.
  const PreviewDataImage({
    required this.height,
    required this.url,
    required this.width,
  });

  /// Creates preview data image from a map (decoded JSON).
  factory PreviewDataImage.fromJson(Map<String, dynamic> json) =>
      _$PreviewDataImageFromJson(json);

  /// Converts preview data image to the map representation, encodable to JSON.
  Map<String, dynamic> toJson() => _$PreviewDataImageToJson(this);

  /// Equatable props
  @override
  List<Object> get props => [height, url, width];

  /// Image height in pixels
  final double height;

  /// Remote image URL
  final String url;

  /// Image width in pixels
  final double width;
}
