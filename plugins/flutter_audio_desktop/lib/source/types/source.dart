import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart' as path;

class AudioSource {
  /// ### Creates a new audio source for loading in AudioPlayer.
  ///
  /// This class contains two static methods [AudioSource.fromFile] & [AudioSource.fromAsset].
  ///
  /// - Audio source using file.
  /// ```dart
  ///  AudioSource source = await AudioSource.fromFile(new File(filePath));
  /// ```
  ///
  /// - Audio source using asset.
  /// ```dart
  ///  AudioSource source = await AudioSource.fromAsset('assets/audio.MP3');
  /// ```
  ///

  AudioSource({required this.file});

  /// ### Creates a new audio source using File.
  ///
  /// Provide a [File] as parameter.
  ///
  /// Throws [FileSystemException] if the file is not found.
  ///
  /// ```dart
  ///  var source = await AudioSource.fromFile(new File(filePath));
  /// ```
  ///
  static AudioSource fromFile(File file) {
    if (file.existsSync()) {
      return AudioSource(file: file);
    } else {
      throw FileSystemException('EXCEPTION: File does not exist.', file.path);
    }
  }

  /// ### Creates a new audio source using File.
  ///
  /// Provide asset path as [String] in the parameter.
  ///
  ///
  /// ```dart
  ///  var source = await AudioSource.fromAsset('assets/audio.MP3');
  /// ```
  ///
  static Future<AudioSource> fromAsset(String asset) async {
    String temporaryDirectoryPath = (await path.getTemporaryDirectory()).path;
    String temporaryFilePath = path.join(
      temporaryDirectoryPath,
      'audio.${asset.split('.').last}',
    );
    File audioFile = File(temporaryFilePath);
    await audioFile.writeAsBytes(
      (await rootBundle.load(asset)).buffer.asUint8List(),
    );
    return AudioSource(
      file: audioFile,
    );
  }

  File file;
}
