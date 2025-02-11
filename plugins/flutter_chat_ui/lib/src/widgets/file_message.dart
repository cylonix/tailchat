import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:just_audio/just_audio.dart';
import 'package:mime/mime.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import '../chat_theme.dart';
import '../util.dart';
import 'inherited_chat_theme.dart';
import 'inherited_l10n.dart';
import 'inherited_user.dart';
import 'text.dart';

/// A class that represents file message widget
class FileMessage extends StatefulWidget {
  /// Creates a file message widget based on a [types.FileMessage]
  const FileMessage({
    Key? key,
    required this.message,
    required this.messageWidth,
    this.simpleUI = false,
    this.uriFixup,
    this.logger,
  }) : super(key: key);

  /// [types.FileMessage]
  final types.FileMessage message;

  /// Maximum message width
  final int messageWidth;

  /// Simple UI
  final bool simpleUI;

  /// Uri may be relative path in some platforms.
  final Future<String?> Function(String?)? uriFixup;

  /// Logger function
  final void Function({String? d, String? i, String? w, String? e})? logger;

  @override
  _FileMessageState createState() => _FileMessageState();
}

/// [FileMessage] widget state
class _FileMessageState extends State<FileMessage> {
  Uint8List? _thumbnailData;
  late String _uri;
  late bool _isVideo, _isAudio, _canPlayAudio;
  Duration? _audioDuration;
  AudioPlayer? _audioPlayer;
  bool _wantToPlayAudio = false;
  bool _isAudioReady = false;
  bool _isAudioPlaying = false;

  @override
  void initState() {
    super.initState();
    _setUri();
    _setMimeType();
    _loadThumbnailData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadThumbnailData();
    _setupAudio();
  }

  @override
  void dispose() {
    _audioPlayer?.dispose();
    super.dispose();
  }

  void _setUri() async {
    _uri = widget.message.uri;
    final uriFixup = widget.uriFixup;
    if (uriFixup != null) {
      final uri = await uriFixup(_uri);
      if (uri != null && _uri != uri) {
        _uri = uri;
        if (mounted) {
          _loadThumbnailData();
          _setupAudio();
          setState(() {});
        }
      }
    }
  }

  void _setMimeType() {
    final mime = lookupMimeType(widget.message.uri)?.split('/')[0];
    _isVideo = mime == 'video';
    _isAudio = mime == 'audio';
    _canPlayAudio = !Platform.isLinux && !Platform.isWindows;
  }

  /// File may still be downloading. Don't load thumbnail before it is ready.
  Future<bool> get _fileIsReady async {
    try {
      final exists = await File(_uri).exists();
      if (!exists) {
        widget.logger?.call(d: "video $_uri does not exist");
        return false;
      }
      final stat = await FileStat.stat(_uri);
      widget.logger?.call(
        d: "video $_uri size ${stat.size}/${widget.message.size}",
      );
      return stat.size == widget.message.size;
    } catch (e) {
      widget.logger?.call(e: "failed to lookup video at $_uri");
      return false;
    }
  }

  void _loadThumbnailData() async {
    if (_thumbnailData != null) {
      return;
    }
    if (!_isVideo || !(Platform.isAndroid || Platform.isIOS)) {
      return;
    }
    if (!await _fileIsReady) {
      return;
    }
    try {
      final data = await VideoThumbnail.thumbnailData(
        video: _uri,
        imageFormat: ImageFormat.JPEG,
        maxWidth: widget.messageWidth,
        quality: 50,
      );
      if (mounted) {
        setState(() {
          _thumbnailData = data;
        });
      }
    } catch (e) {
      widget.logger?.call(e: 'load thumbnail exception: $e');
    }
  }

  Widget _thumbnail(ChatTheme theme, Color color) {
    final data = _thumbnailData;
    if (data == null) {
      return const SizedBox();
    }
    return Stack(
      alignment: AlignmentDirectional.center,
      children: [
        Container(
          constraints: BoxConstraints(
            maxHeight: min(widget.messageWidth.toDouble() + 50, 500),
            maxWidth: min(widget.messageWidth.toDouble() + 50, 500),
            minWidth: 170,
          ),
          decoration: BoxDecoration(
            image: DecorationImage(
              fit: BoxFit.cover,
              image: Image.memory(data).image,
            ),
          ),
        ),
        _documentIcon(theme, color, size: 50),
      ],
    );
  }

  bool get _hasThumbnail {
    return _thumbnailData != null;
  }

  Future<void> _setupAudio() async {
    if (_isAudioReady || !_wantToPlayAudio) {
      return;
    }
    if (!await _fileIsReady) {
      return;
    }
    final player = AudioPlayer();
    _audioPlayer = player;
    try {
      var url = _uri;
      if (url.startsWith('/')) {
        url = 'file://$url';
      }
      _audioDuration = await player.setUrl(url);
      setState(() {
        _isAudioReady = true;
      });
    } catch (e) {
      widget.logger?.call(e: '$e');
    }
  }

  Widget _audioWidget(ChatTheme theme, Color color, bool fromMe) {
    return InkWell(
      child: Padding(
        padding: EdgeInsets.all(widget.simpleUI ? 0 : 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _documentIcon(
              theme,
              color,
              icon: Icon(
                  _isAudioPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  size: 32),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: ChatText(
                _audioDuration?.toString().split('.')[0] ??
                    widget.message.shortName,
                theme,
                fromMe: fromMe,
              ),
            ),
            const SizedBox(width: 30),
          ],
        ),
      ),
      onTap: () async {
        if (!_wantToPlayAudio) {
          _wantToPlayAudio = true;
          await _setupAudio();
        }
        if (!_isAudioReady) {
          return;
        }
        if (_isAudioPlaying) {
          setState(() {
            _isAudioPlaying = false;
          });
          await _audioPlayer?.pause();
        } else {
          setState(() {
            _isAudioPlaying = true;
          });
          await _audioPlayer?.play();
          if (_isAudioPlaying) {
            // Completed without pausing. Dispose the player.
            await _audioPlayer?.dispose();
            if (mounted) {
              setState(() {
                _audioPlayer = null;
                _wantToPlayAudio = false;
                _isAudioReady = false;
                _isAudioPlaying = false;
              });
            }
          }
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final message = widget.message;
    final user = InheritedUser.of(context).user;
    final isMyUserID = user.id == message.author.id;
    final isReceived = message.status == types.Status.received;
    final fromMe = isMyUserID && !isReceived && !widget.simpleUI;
    final theme = InheritedChatTheme.of(context).theme;
    final color = fromMe
        ? theme.sentMessageDocumentIconColor
        : theme.receivedMessageDocumentIconColor;

    return Column(
      crossAxisAlignment: widget.simpleUI
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      children: [
        if (_hasThumbnail) _thumbnail(theme, color),
        if (_isAudio && _canPlayAudio) _audioWidget(theme, color, fromMe),
        _documentDescription(theme, color, fromMe),
      ],
    );
  }

  Widget _documentIcon(
    ChatTheme theme,
    Color color, {
    Widget? icon,
    double size = 32,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular((size + 10) / 2),
      ),
      height: size + 10,
      width: size + 10,
      child: icon ??
          (_isVideo || _isAudio
              ? Icon(Icons.play_arrow_rounded, size: size)
              : theme.documentIcon != null
                  ? theme.documentIcon!
                  : Image.asset(
                      'assets/icon-document.png',
                      color: color,
                      package: 'flutter_chat_ui',
                    )),
    );
  }

  Widget _documentDescription(ChatTheme theme, Color color, bool fromMe) {
    final message = widget.message;
    final sizeText = formatBytes(message.size.truncate());
    final caption = '${message.caption ?? ""} $sizeText';
    final noStyle = widget.simpleUI;

    if (_hasThumbnail || _isAudio && _canPlayAudio) {
      return _audioDuration != null
          ? const SizedBox()
          : Padding(
              padding: widget.simpleUI
                  ? const EdgeInsets.only(top: 4, bottom: 4)
                  : const EdgeInsets.all(4),
              child: ChatCaption(
                caption,
                theme,
                fromMe: fromMe,
                noStyle: noStyle,
              ),
            );
    }

    return Semantics(
      label: InheritedL10n.of(context).l10n.fileButtonAccessibilityLabel,
      child: Container(
        padding: EdgeInsets.fromLTRB(
          widget.simpleUI ? 0 : theme.messageInsetsHorizontal,
          theme.messageInsetsVertical,
          theme.messageInsetsHorizontal,
          theme.messageInsetsVertical,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _documentIcon(theme, color),
            Flexible(
              child: Container(
                margin: const EdgeInsets.only(
                  left: 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ChatText(message.name, theme, fromMe: fromMe),
                    const SizedBox(height: 4),
                    ChatCaption(
                      caption,
                      theme,
                      fromMe: fromMe,
                      noStyle: noStyle,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
