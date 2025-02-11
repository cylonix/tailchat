import 'package:flutter_audio_desktop/source/core/channel.dart';
import 'package:flutter_audio_desktop/source/core/devices.dart';
import 'package:flutter_audio_desktop/source/core/events.dart';
import 'package:flutter_audio_desktop/source/types/source.dart';
import 'package:flutter_audio_desktop/source/types/audio.dart';

class AudioPlayer extends AudioPlayerEvents {
  /// ### Creates a new audio player instance or gets an existing one.
  ///
  /// Provide a unique integer as [id] while creating new object.
  /// ```dart
  /// AudioPlayer audioPlayer = AudioPlayer(id: 0);
  /// ```
  ///
  /// Optionally provide [AudioDevice] as [device] to change the playback device for the audio player.
  /// If a [device] is not provided, audio player will play audio on the default device.
  /// ```dart
  /// AudioPlayer audioPlayer = AudioPlayer(
  ///   id: 0,
  ///   device: (await AudioDevices.allDevices).last,
  /// );
  /// ```
  ///
  /// **NOTE:** Use [AudioDevices.allDevices] and [AudioDevices.defaultDevice] to get devices available on your device.
  /// ```dart
  /// allDevices = await AudioDevices.allDevices;
  /// ```
  /// **NOTE:** If an [id] is used for the first time, a new instance of audio player will be created.
  /// If the provided [id] was already used before, no new audio player will be created.

  AudioPlayer({int id = 0, AudioDevice? device}) {
    id = id;
    deviceId = device?.id ?? 'default';
    audio = Audio();
    audio.file = null;
    audio.isPlaying = false;
    audio.isCompleted = false;
    audio.isStopped = true;
    audio.position = Duration.zero;
    audio.duration = Duration.zero;
    stream = _startStream().asBroadcastStream()..listen((_) {});
  }

  /// ### Loads an audio source to the player.
  ///
  /// Provide an [AudioSource] as parameter.
  ///
  /// - Loading a file.
  ///
  /// ```dart
  /// audioPlayer.load(
  ///   await AudioSource.fromFile(
  ///     new File(filePath),
  ///   ),
  /// );
  /// ```
  ///
  /// - Loading an asset.
  ///
  /// ```dart
  /// audioPlayer.load(
  ///   await AudioSource.fromAsset(
  ///     'assets/audio.MP3',
  ///   ),
  /// );
  /// ```
  ///
  Future<void> load(AudioSource audioSource) async {
    await channel.invokeMethod(
      'load',
      {
        'id': id,
        'deviceId': deviceId,
        'filePath': audioSource.file.path,
      },
    );
    await onLoad(audioSource.file);
  }

  /// ### Plays loaded audio source.
  ///
  /// ```dart
  /// audioPlayer.play();
  /// ```
  ///
  /// **NOTE:** Method does nothing if no audio source is loaded.
  ///
  Future<void> play() async {
    if (!audio.isStopped) {
      await channel.invokeMethod(
        'play',
        {
          'id': id,
          'deviceId': deviceId,
        },
      );
      await onPlay();
    }
  }

  /// ### Pauses loaded audio source.
  ///
  /// ```dart
  /// audioPlayer.pause();
  /// ```
  ///
  /// **NOTE:** Method does nothing if no audio source is loaded.
  ///
  Future<void> pause() async {
    if (!audio.isStopped) {
      audio.isPlaying = false;
      await channel.invokeMethod(
        'pause',
        {
          'id': id,
          'deviceId': deviceId,
        },
      );
    }
  }

  /// ### Stops audio player instance.
  ///
  /// ```dart
  /// audioPlayer.stop();
  /// ```
  ///
  /// **NOTE:** Once this method is called, [AudioPlayer.load] must be called again.
  ///
  Future<void> stop() async {
    if (!audio.isStopped) {
      await channel.invokeMethod(
        'stop',
        {
          'id': id,
          'deviceId': deviceId,
        },
      );
      await onStop();
    }
  }

  /// ### Seeks loaded audio source.
  ///
  /// Provide an [Duration] as parameter.
  ///
  /// ```dart
  /// audioPlayer.setPosition(
  ///   Duration(seconds: 20),
  /// );
  /// ```
  ///
  Future<void> setPosition(Duration duration) async {
    if (!audio.isStopped) {
      return await channel.invokeMethod(
        'setPosition',
        {
          'id': id,
          'deviceId': deviceId,
          'position': duration.inMilliseconds,
        },
      );
    }
  }

  /// ### Sets audio player instance volume.
  ///
  /// Provide an [double] as parameter.
  ///
  /// ```dart
  /// audioPlayer.setVolume(0.8);
  /// ```
  ///
  Future<void> setVolume(double volume) async {
    if (!audio.isStopped) {
      await channel.invokeMethod(
        'setVolume',
        {
          'id': id,
          'deviceId': deviceId,
          'volume': volume,
        },
      );
    }
  }

  Future<Audio> _notifyCurrentAudioState() async {
    if (!audio.isCompleted) {
      await onUpdate();
    } else {
      await onStop();
    }
    return audio;
  }

  Stream<Audio> _startStream() async* {
    bool wasAudioPaused = false;
    Stream<Future<Audio>> stream = Stream.periodic(
      Duration(milliseconds: 100),
      (_) async {
        return await _notifyCurrentAudioState();
      },
    );
    await for (Future<Audio> audioFuture in stream) {
      Audio audio = await audioFuture;
      if (audio.isCompleted) {
        yield audio;
        await stop();
      } else if (audio.isPlaying) {
        yield audio;
        wasAudioPaused = false;
      } else if (!wasAudioPaused) {
        yield audio;
        wasAudioPaused = true;
      }
    }
  }
}
