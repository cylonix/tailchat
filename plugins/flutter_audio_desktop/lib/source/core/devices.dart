import 'package:flutter_audio_desktop/source/core/channel.dart';

class AudioDevice {
  /// ID of this audio device.
  final String id;

  /// Name of this audio device.
  final String name;

  /// A playback audio device connected to the device.
  AudioDevice(this.id, this.name);
}

class AudioDevices {
  /// ### Gets all connected playback devices
  ///
  /// Returns [List] of all [AudioDevice] connected to the device.
  ///
  /// ```dart
  /// List<AudioDevice> devices = await AudioDevices.allDevices;
  /// ```
  ///
  static Future<List<AudioDevice>> get allDevices async {
    List<AudioDevice> devices = <AudioDevice>[];
    var devicesMap = await channel.invokeMethod(
      'getDevices',
      {},
    );
    devicesMap.forEach((id, name) {
      if (id != 'default') {
        devices.add(
          AudioDevice(id.toString(), name.toString()),
        );
      }
    });
    return devices;
  }

  /// ### Gets default connected playback device
  ///
  /// Returns default [AudioDevice] with id `'default'`.
  ///
  /// ```dart
  /// List<AudioDevice> devices = await AudioDevices.allDevices;
  /// ```
  ///
  static Future<AudioDevice> get defaultDevice async {
    AudioDevice? defaultDevice;
    var devicesMap = await channel.invokeMethod(
      'getDevices',
      {},
    );
    devicesMap.forEach((id, name) {
      if (id == 'default') {
        defaultDevice = AudioDevice(id.toString(), name.toString());
      }
    });
    if (defaultDevice == null) {
      throw 'EXCEPTION: Could not find the default device.';
    }
    return defaultDevice!;
  }
}
