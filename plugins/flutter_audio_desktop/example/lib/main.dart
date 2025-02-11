import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_audio_desktop/flutter_audio_desktop.dart';

class Player extends StatefulWidget {
  const Player({super.key});

  @override
  PlayerState createState() => PlayerState();
}

class PlayerState extends State<Player> {
  AudioDevice? _defaultDevice;
  List<AudioDevice>? _allDevices;
  AudioPlayer? _audioPlayer;
  File? _file;
  bool _isPlaying = false;
  bool _isStopped = true;
  bool _isCompleted = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  double _volume = 1.0;
  final _textController = TextEditingController();

  @override
  void didChangeDependencies() async {
    super.didChangeDependencies();
    // Create AudioPlayer object by providing any id.
    // You can change playback device by providing device.
    _audioPlayer = AudioPlayer(id: 0)
      // Listen to AudioPlayer events.
      ..stream.listen(
        (Audio audio) {
          setState(() {
            _file = audio.file;
            _isPlaying = audio.isPlaying;
            _isStopped = audio.isStopped;
            _isCompleted = audio.isCompleted;
            _position = audio.position;
            _duration = audio.duration;
          });
        },
      );
    // Get default & all devices to initialize in AudioPlayer.
    // Here we are just showing it to the user.
    _defaultDevice = await AudioDevices.defaultDevice;
    _allDevices = await AudioDevices.allDevices;
  }

  // Get AudioPlayer events without stream.
  void _updatePlaybackState() {
    setState(() {
      if (_audioPlayer == null) {
        return;
      }
      _file = _audioPlayer!.audio.file;
      _isPlaying = _audioPlayer!.audio.isPlaying;
      _isStopped = _audioPlayer!.audio.isStopped;
      _isCompleted = _audioPlayer!.audio.isCompleted;
      _position = _audioPlayer!.audio.position;
      _duration = _audioPlayer!.audio.duration;
    });
  }

  String _getDurationString(Duration duration) {
    int minutes = duration.inSeconds ~/ 60;
    String seconds = duration.inSeconds - (minutes * 60) > 9
        ? '${duration.inSeconds - (minutes * 60)}'
        : '0${duration.inSeconds - (minutes * 60)}';
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text('flutter_audio_desktop'),
      ),
      body: ListView(
        padding: EdgeInsets.only(
          top: 8.0,
          bottom: 8.0,
          left: 8.0,
          right: 8.0,
        ),
        children: [
          Card(
            elevation: 2.0,
            color: Colors.white,
            margin: EdgeInsets.all(8.0),
            child: Padding(
              padding: EdgeInsets.only(left: 16.0, right: 16.0, bottom: 12.0),
              child: Column(
                children: [
                  SubHeader(text: 'File Loading'),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _textController,
                          autofocus: true,
                          decoration: InputDecoration(
                            labelText: 'File Location',
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16.0),
                        child: IconButton(
                          icon: Icon(Icons.check),
                          iconSize: 32.0,
                          color: Colors.blue,
                          onPressed: () async {
                            // Load AudioSource.
                            await _audioPlayer?.load(
                              AudioSource.fromFile(
                                File(_textController.text),
                              ),
                            );
                            _updatePlaybackState();
                          },
                        ),
                      ),
                    ],
                  ),
                  SubHeader(text: 'Playback Setters/Getters'),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Padding(
                        padding: EdgeInsets.all(18.0),
                        child: IconButton(
                          icon: Icon(Icons.play_arrow),
                          iconSize: 32.0,
                          color: Colors.blue,
                          onPressed: _isStopped
                              ? null
                              : () async {
                                  await _audioPlayer?.play();
                                  _updatePlaybackState();
                                },
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.all(18.0),
                        child: IconButton(
                          icon: Icon(Icons.pause),
                          iconSize: 32.0,
                          color: Colors.blue,
                          onPressed: _isStopped
                              ? null
                              : () async {
                                  await _audioPlayer?.pause();
                                  _updatePlaybackState();
                                },
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.all(18.0),
                        child: IconButton(
                          icon: Icon(Icons.stop),
                          iconSize: 32.0,
                          color: Colors.blue,
                          onPressed: _isStopped
                              ? null
                              : () async {
                                  await _audioPlayer?.stop();
                                  _updatePlaybackState();
                                },
                        ),
                      ),
                      Slider(
                        value: _volume,
                        min: 0.0,
                        max: 1.0,
                        onChanged: _isStopped
                            ? null
                            : (double volume) async {
                                _volume = volume;
                                // Change Volume.
                                await _audioPlayer?.setVolume(_volume);
                                _updatePlaybackState();
                              },
                      ),
                    ],
                  ),
                  SubHeader(text: 'Position & Duration Setters/Getters'),
                  Row(
                    children: [
                      Text(_getDurationString(_position)),
                      Expanded(
                        child: Slider(
                          value: _position.inMilliseconds.toDouble(),
                          min: 0.0,
                          max: _duration.inMilliseconds.toDouble(),
                          onChanged: _isStopped
                              ? null
                              : (double position) async {
                                  // Get or set playback position.
                                  await _audioPlayer?.setPosition(
                                    Duration(milliseconds: position.toInt()),
                                  );
                                },
                        ),
                      ),
                      Text(_getDurationString(_duration)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Card(
            elevation: 2.0,
            color: Colors.white,
            margin: EdgeInsets.all(8.0),
            child: Padding(
              padding: EdgeInsets.only(left: 16.0, right: 16.0, bottom: 12.0),
              child: Column(
                children: [
                  SubHeader(text: 'Playback State'),
                  Table(
                    children: [
                      TableRow(children: [
                        Text(
                          'audio.file',
                          style: TextStyle(
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          '$_file',
                          style: TextStyle(
                            fontSize: 16,
                          ),
                        ),
                      ]),
                      TableRow(children: [
                        Text(
                          'audio.isPlaying',
                          style: TextStyle(
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          '$_isPlaying',
                          style: TextStyle(
                            fontSize: 16,
                          ),
                        ),
                      ]),
                      TableRow(children: [
                        Text(
                          'audio.isStopped',
                          style: TextStyle(
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          '$_isStopped',
                          style: TextStyle(
                            fontSize: 16,
                          ),
                        ),
                      ]),
                      TableRow(children: [
                        Text(
                          'audio.isCompleted',
                          style: TextStyle(
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          '$_isCompleted',
                          style: TextStyle(
                            fontSize: 16,
                          ),
                        ),
                      ]),
                      TableRow(children: [
                        Text(
                          'audio.position',
                          style: TextStyle(
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          '$_position',
                          style: TextStyle(
                            fontSize: 16,
                          ),
                        ),
                      ]),
                      TableRow(children: [
                        Text(
                          'audio.position',
                          style: TextStyle(
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          '$_duration',
                          style: TextStyle(
                            fontSize: 16,
                          ),
                        ),
                      ]),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Card(
            elevation: 2.0,
            color: Colors.white,
            margin: EdgeInsets.all(8.0),
            child: Padding(
              padding: EdgeInsets.only(left: 16.0, right: 16.0, bottom: 12.0),
              child: Column(
                children: [
                      SubHeader(text: 'Default Device'),
                      ListTile(
                        title: Text('${_defaultDevice?.name}'),
                        subtitle: Text('${_defaultDevice?.id}'),
                      ),
                      SubHeader(text: 'All Devices'),
                    ] +
                    ((_allDevices != null)
                        ? _allDevices!.map((AudioDevice device) {
                            return ListTile(
                              title: Text(device.name),
                              subtitle: Text(device.id),
                            );
                          }).toList()
                        : []),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Player(),
    );
  }
}

void main() => runApp(MyApp());

class SubHeader extends StatelessWidget {
  final String text;

  const SubHeader({required this.text, super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.centerLeft,
      height: 56.0,
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14,
          color: Colors.black.withValues(alpha: 0.67),
        ),
      ),
    );
  }
}
