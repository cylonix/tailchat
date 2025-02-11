// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter_audio_desktop/flutter_audio_desktop.dart' as desktop;
import '../utils/global.dart';

class PlayerWidget extends StatefulWidget {
  const PlayerWidget({super.key});

  @override
  State<PlayerWidget> createState() => _PlayerWidgetState();
}

class _PlayerWidgetState extends State<PlayerWidget>
    with SingleTickerProviderStateMixin {
  late AudioPlayer _audioPlayer;
  late desktop.AudioPlayer _desktopAudioPlayer;
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _initPlayer();
    _initAnimation();
  }

  _initAnimation() {
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.fastOutSlowIn,
    );
  }

  _initPlayer() async {
    if (Platform.isWindows || Platform.isLinux) {
      // Create new instance.
      _desktopAudioPlayer = desktop.AudioPlayer(id: 0)
        ..stream.listen(
          (desktop.Audio audio) {
            // Listen to playback events.
          },
        );
      // Load audio source
      await _desktopAudioPlayer.load(
        await desktop.AudioSource.fromAsset(
          'packages/sase_app_ui/assets/audio/always_with_me.mp3',
        ),
      );
      await _desktopAudioPlayer.play();
      return;
    }
    _audioPlayer = AudioPlayer();
    // Set a asset source that will be played by the audio player.
    try {
      Global.logger.d("audio player setting asset...");
      await _audioPlayer.setAsset(
        'packages/sase_app_ui/assets/audio/short_always_with_me.m4a',
      );
      Global.logger.d("audio player set asset DONE");
      await _audioPlayer.play();
    } catch (e) {
      Global.logger.e("failed to set up audio player: $e");
    }
  }

  @override
  void dispose() {
    if (Platform.isWindows || Platform.isLinux) {
      _desktopAudioPlayerDispose();
    } else {
      _audioPlayer.dispose();
    }
    _controller.dispose();
    super.dispose();
  }

  _desktopAudioPlayerDispose() async {
    await _desktopAudioPlayer.stop();
  }

  @override
  Widget build(BuildContext context) {
    if (Platform.isWindows || Platform.isLinux) {
      _desktopAudioPlayer.stream;
      return Center(
        child: StreamBuilder<desktop.Audio>(
          stream: _desktopAudioPlayer.stream,
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              final audio = snapshot.data;
              return _playerButton(audio: audio);
            } else {
              return const CircularProgressIndicator();
            }
          },
        ),
      );
    }
    return Center(
      child: StreamBuilder<PlayerState>(
        stream: _audioPlayer.playerStateStream,
        builder: (context, snapshot) {
          final playerState = snapshot.data;
          return _playerButton(playerState: playerState);
        },
      ),
    );
  }

  Widget _playerButton({PlayerState? playerState, desktop.Audio? audio}) {
    if (Platform.isWindows || Platform.isLinux) {
      final playing = audio?.isPlaying == true;
      return IconButton(
        icon: Icon(playing ? Icons.music_note : Icons.music_off),
        iconSize: 32.0,
        onPressed:
            playing ? _desktopAudioPlayer.pause : _desktopAudioPlayer.play,
      );
    }
    final processingState = playerState?.processingState;
    if (processingState == ProcessingState.loading ||
        processingState == ProcessingState.buffering) {
      return Container(
        margin: const EdgeInsets.all(8.0),
        width: 32.0,
        height: 32.0,
        child: const CircularProgressIndicator(),
      );
    } else if (_audioPlayer.playing != true) {
      return IconButton(
        icon: const Icon(Icons.music_off),
        iconSize: 32.0,
        onPressed: _audioPlayer.play,
      );
    } else if (processingState != ProcessingState.completed) {
      return _animatedPlayingIcon;
    } else {
      return IconButton(
        icon: const Icon(Icons.replay),
        iconSize: 32.0,
        onPressed: () => _audioPlayer.seek(Duration.zero,
            index: _audioPlayer.effectiveIndices?.first),
      );
    }
  }

  Widget get _animatedPlayingIcon {
    return Stack(
      alignment: AlignmentDirectional.center,
      children: [
        ScaleTransition(
          scale: _animation,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withValues(alpha: 0.3),
                  blurRadius: 20,
                )
              ],
            ),
            child: Icon(
              Icons.circle,
              size: 48,
              color: Colors.white.withValues(alpha: 0.2),
            ),
          ),
        ),
        Center(
          child: IconButton(
            icon: const Icon(Icons.music_note),
            iconSize: 32,
            onPressed: _audioPlayer.pause,
          ),
        ),
      ],
    );
  }
}
