import 'dart:io';

import 'package:flutter_audio_desktop/source/core/channel.dart';
import 'package:flutter_audio_desktop/source/types/audio.dart';

class AudioPlayerInternal {
  /// Unique ID of the audio player instance.
  late int id;

  /// Device ID of the device ,to which the audio player is playing.
  late String deviceId;

  /// Broadcast stream to listen to playback events e.g. completion, loading, play/pause etc.
  late Stream<Audio> stream;

  /// Current playback state of audio player.
  late Audio audio;
}

class AudioPlayerGetters extends AudioPlayerInternal {
  /// ### Gets position of current playback.
  ///
  /// Returns [Duration].
  ///
  /// ```dart
  /// Duration position = await audioPlayer.position;
  /// ```
  ///
  Future<Duration> get position async {
    return Duration(
      milliseconds: await channel.invokeMethod(
        'getPosition',
        {
          'id': id,
          'deviceId': deviceId,
        },
      ),
    );
  }

  /// ### Gets duration of currently loaded audio source.
  ///
  /// Returns [Duration].
  ///
  /// ```dart
  /// Duration duration = await audioPlayer.duration;
  /// ```
  ///
  Future<Duration> get duration async {
    return Duration(
      milliseconds: await channel.invokeMethod(
        'getDuration',
        {
          'id': id,
          'deviceId': deviceId,
        },
      ),
    );
  }
}

class AudioPlayerEvents extends AudioPlayerGetters {
  /// Internal method used by plugin for managing playback state.
  Future<void> onLoad(File file) async {
    audio.file = file;
    audio.isPlaying = false;
    audio.isCompleted = false;
    audio.isStopped = false;
    audio.position = Duration.zero;
    audio.duration = await duration;
  }

  /// Internal method used by plugin for managing playback state.
  Future<void> onStop() async {
    audio.file = null;
    audio.isPlaying = false;
    audio.isCompleted = false;
    audio.isStopped = true;
    audio.position = Duration.zero;
    audio.duration = Duration.zero;
  }

  /// Internal method used by plugin for managing playback state.
  Future<void> onPlay() async {
    audio.isPlaying = true;
    audio.isCompleted = audio.duration.inSeconds == 0
        ? false
        : audio.position.inSeconds == audio.duration.inSeconds;
    audio.isStopped = false;
    audio.position = await position;
    audio.duration = await duration;
  }

  /// Internal method used by plugin for managing playback state.
  Future<void> onUpdate() async {
    audio.isCompleted = audio.duration.inSeconds == 0
        ? false
        : audio.position.inSeconds == audio.duration.inSeconds;
    audio.position = await position;
    audio.duration = await duration;
  }
}
