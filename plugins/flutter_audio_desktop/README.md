# ✒ [libwinmedia](https://github.com/harmonoid/libwinmedia) is sequel to this project.
#### It provides network playback, better format support, control & features.
<br></br>
<br></br>
<br></br>
<br></br>
<br></br>
<br></br>
<br></br>
#### An audio playback library for Flutter Desktop.

Feel free to open issue anytime.


## Installing

Mention in your pubspec.yaml:

```yaml
dependencies:
  ...
  flutter_audio_desktop: ^0.1.0
```

## Using

```dart
// Create new instance.
var audioPlayer = new AudioPlayer(id: 0)
..stream.listen(
  (Audio audio) {
    // Listen to playback events.
  },
);
// Load audio source
audioPlayer.load(
  new AudioSource.fromFile(
    new File('/home/alexmercerind/music.mp3'),
  ),
);
// Start playback.
audioPlayer.play();
// Get audio duration.
audioPlayer.audio.duration;
// Change playback volume.
audioPlayer.setVolume(0.5);
// Change playback position.
audioPlayer.setPosition(Duration(seconds: 10));
// Get playback position.
audioPlayer.audio.position;
Timer(Duration(seconds: 10), () {
    // Pause playback.
    audioPlayer.pause();
}
// Few other things.
audioPlayer.audio.file;
audioPlayer.audio.isPlaying;
audioPlayer.audio.isCompleted;
audioPlayer.audio.isStopped;

```

Other classes & methods are documented in their docstrings very well.

See [this](https://github.com/alexmercerind/flutter_audio_desktop/blob/master/example/lib/main.dart) example for a better overview.

#### Windows

<img src="https://github.com/alexmercerind/flutter_audio_desktop/blob/assets/windows.png?raw=true" width="500"></img>

#### Linux

<img src="https://github.com/alexmercerind/flutter_audio_desktop/blob/assets/linux.png?raw=true" width="500"></img>

## Support

If you want to be kind to me, then consider buying me a coffee.

<a href="https://www.buymeacoffee.com/alexmercerind"><img src="https://img.buymeacoffee.com/button-api/?text=Buy me a coffee&emoji=&slug=alexmercerind&button_colour=FFDD00&font_colour=000000&font_family=Cookie&outline_colour=000000&coffee_colour=ffffff"></a>

Thankyou!


## Progress

|Platform            |Status                                                    |
|--------------------|----------------------------------------------------------|
|Linux               |Working                                                   |
|Microsoft Windows   |Working                                                   |
|MacOS               |[Learn More](https://www.youtube.com/watch?v=dQw4w9WgXcQ) |


## License

I don't want to put any restrictions on how you distribute your Flutter Desktop apps, so this library comes under very permissive software, MIT license.

Since, other libraries like [libvlcpp](https://github.com/videolan/libvlcpp) or [libvlc](https://www.videolan.org/vlc/libvlc.html) come under GPL & LGPL licenses respectively, so there will be many restrictions if I plan to use them.

Thus, this project uses [miniaudio](https://github.com/mackron/miniaudio) and [miniaudio_engine](https://github.com/mackron/miniaudio) from [David Reid](https://github.com/mackron) under MIT license.


## Acknowledgments

- [David Reid](https://github.com/mackron) for his amazing single header libraries [miniaudio](https://github.com/mackron/miniaudio) and [miniaudio_engine](https://github.com/mackron/miniaudio).
- Thanks to [MichealReed](https://github.com/MichealReed) for his support to the project.
