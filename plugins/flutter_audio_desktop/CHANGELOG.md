## 0.1.0

- Now you can listen to playback events using `stream` (a broadcast stream) inside `AudioPlayer`. This was a great problem in earlier version as one always needs to trigger UI updates whenever playback progresses, ends etc.
- One of the big problems in earlier version was that there was no way to detect if an audio playback has ended after completion. Resulting in issues like #25 & #26. Now `audio.isCompleted` stores `bool` if an audio has ended, same can be accessed from `stream`.
- Added a new `Queue` class to play audio files sequentially, without having to deal with things like `audio.isCompleted` etc. manually.
- Added methods to deal with `Queue` or repeat playback etc.
- Now you can provide any random `id` while creating new instance of `AudioPlayer`, this was a big problem earlier as new `id` had to be consecutive to earlier one.
- Now you can access same instance of `AudioPlayer` even if you make new constructor, by providing same `id`. 
- Now asset files can be played & loaded into `AudioPlayer` using `load` method.
  - `AudioSource` class has two static methods
    - `AudioSource.fromFile` to load an audio file.
    - `AudioSource.fromAsset` to load an audio asset.
- Now audio field stores `Audio` object, inside the AudioPlayer class & contains following fields to get information about current playback.
  - `file`: Current loaded `File`.
  - `isPlaying` : Whether file is playing.
  - `isCompleted`: Whether file is ended playing.
    - By default once playback is ended, `stop` method is called & `AudioPlayer` is reverted to initial configuration.
  - `isStopped`: Whether file is loaded.
  - `position`: Position of current playback in `Duration`.
  - `duration`: Duration of current file in `Duration`.
- Now contructor of `AudioPlayer` no longer calls async methods, which could result in false assertions.
- Now `ma_resource_manager` is used from `miniaudio_engine` with `MA_DATA_SOURCE_FLAG_STREAM` flag.
  - This will improve general performance during playback, as whole file will not be loaded into memory.
- Structure of code improved & separated into various files & classes.
- Now device handling is present in an entirely separate class `AudioDevices`.
- Improvements to how methods are identified & called in method channel. `flutter_types.hpp` improves code readability. 
- Other bugs that randomly caused termination after false assertions are also fixed to an extent.
- Removed wave & noise APIs temporarily. Apologies to everyone & [MichealReed](https://github.com/MichealReed).

## 0.0.9

- Missed

## 0.0.8

**Multiple player instances, wave & noise methods**

- Now multiple AudioPlayer instances can be made, by providing optional id parameter to the constructor.
- Added methods for playing waves.
- Added methods for playing noise.

## 0.0.7

**Initial Playback Device Changing Support**

- Added setDevice method to AudioPlayer class.

## 0.0.6

**Microsoft Windows Support**

- Plugin is now capable of playing audio files on Windows.

## 0.0.5

**A Little Fix**

- pub package now has miniaudio in it.

## 0.0.4

**Final Improvements**

- Now plugin uses MethodChannel instead of dart:ffi for calling native methods.
- Any additional setup is not required anymore.

## 0.0.3

**First Public Release**

- Added docstrings.
- Improved dart usage.
- Fixed wrong sample rate.
- Now Dart code is asynchronous.


## 0.0.2

**Now Fully Open Source**

Changed native code to use [miniaudio](https://github.com/mackron/miniaudio)


## 0.0.1

**Initial Release**

Supports audio playback on Linux.

Added mandatory audio playback functions like:
- Loading audio file
- Playing
- Pausing
- Getting duration of an audio file.
- Seeking
- Changing volume
