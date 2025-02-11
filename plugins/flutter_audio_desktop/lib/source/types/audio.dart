import 'dart:io';

class Audio {
  /// Currently loaded [File].
  File? file;

  /// Current playback state of audio player.
  bool isPlaying;

  /// Audio source completion state of audio player.
  bool isCompleted;

  /// Whether an [AudioSource] is loaded or not.
  bool isStopped;

  /// Current position of playback in [Duration].
  Duration position;

  /// [Duration] of currently loaded audio source.
  Duration duration;

  Audio({
    this.file,
    this.isPlaying = false,
    this.isStopped = true,
    this.isCompleted = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
  });
}
