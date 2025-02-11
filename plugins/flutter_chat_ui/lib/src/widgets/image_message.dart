import 'dart:io';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import '../conditional/conditional.dart';
import '../util.dart';
import 'inherited_chat_theme.dart';
import 'inherited_user.dart';
import 'text.dart';

/// A class that represents image message widget. Supports different
/// aspect ratios, renders blurred image as a background which is visible
/// if the image is narrow, renders image in form of a file if aspect
/// ratio is very small or very big.
class ImageMessage extends StatefulWidget {
  /// Creates an image message widget based on [types.ImageMessage]
  const ImageMessage({
    Key? key,
    required this.message,
    this.messageWidth,
    this.uriFixup,
    this.showBlurredBackground = false,
    this.showSummaryFormat = false,
    this.simpleUI = false,
  }) : super(key: key);

  /// [types.ImageMessage]
  final types.ImageMessage message;

  /// Maximum message width
  final int? messageWidth;

  /// If to show blurred background.
  final bool showBlurredBackground;

  /// If to show always the summary format.
  final bool showSummaryFormat;

  /// Simple UI
  final bool simpleUI;

  /// Uri may be relative path in some platforms.
  final Future<String?> Function(String?)? uriFixup;

  @override
  _ImageMessageState createState() => _ImageMessageState();
}

/// [ImageMessage] widget state
class _ImageMessageState extends State<ImageMessage> {
  ImageProvider? _image;
  ImageStream? _stream;
  bool _imageIsLoaded = false;
  Size _size = const Size(0, 0);
  late String _uri, _sizeText, _captionText;

  @override
  void initState() {
    super.initState();
    _size = Size(widget.message.width ?? 0, widget.message.height ?? 0);
    _sizeText = formatBytes(widget.message.size.truncate());
    _captionText = '${widget.message.caption ?? ""} $_sizeText';

    _setUri();
    _loadImage();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadImage();
  }

  void _setUri() async {
    _uri = widget.message.uri;
    final uriFixup = widget.uriFixup;
    if (uriFixup != null) {
      final uri = await uriFixup(_uri);
      if (uri != null && _uri != uri) {
        _uri = uri;
        if (mounted) {
          _loadImage();
          setState(() {});
        }
      }
    }
  }

  Future<ImageProvider?> _getImageProvider() async {
    final uri = _uri;
    if (!uri.startsWith('http')) {
      try {
        final exists = await File(uri).exists();
        if (!exists) {
          return null;
        }
        final stat = await FileStat.stat(uri);
        if (stat.size < widget.message.size) {
          return null;
        }
      } catch (e) {
        // ignore for now as not ready is normal...
      }
    }
    try {
      return Conditional().getProvider(uri);
    } catch (e) {
      // ignore for now as it may not be ready yet...
      return null;
    }
  }

  /// Only loaded image once. If we need to handle image change in the future,
  /// we need to revisit this.
  void _loadImage() async {
    if (_imageIsLoaded) {
      return;
    }
    _image ??= await _getImageProvider();
    if (_image == null) {
      return;
    }
    final oldImageStream = _stream;
    if (!mounted) {
      return;
    }
    try {
      _stream = _image!.resolve(createLocalImageConfiguration(context));
    } catch (e) {
      _imageIsLoaded = false;
      _image = null;
      return;
    }
    if (_stream?.key == oldImageStream?.key) {
      return;
    }
    final listener = ImageStreamListener(_updateImage);
    oldImageStream?.removeListener(listener);
    _stream?.addListener(listener);
    setState(() {
      _imageIsLoaded = true;
    });
  }

  void _updateImage(ImageInfo info, bool _) {
    if (!mounted) {
      return;
    }
    final newSize = Size(
      info.image.width.toDouble(),
      info.image.height.toDouble(),
    );
    setState(() {
      _size = Size(
        _size.width == 0 ? newSize.width : _size.width,
        _size.height == 0 ? newSize.height : _size.height,
      );
    });
  }

  @override
  void dispose() {
    _stream?.removeListener(ImageStreamListener(_updateImage));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final message = widget.message;
    final user = InheritedUser.of(context).user;
    final fromMe = user.id == message.author.id &&
        message.status != types.Status.received &&
        !widget.simpleUI;
    final theme = InheritedChatTheme.of(context).theme;
    final name = widget.showSummaryFormat ? message.shortName : message.name;
    final noStyle = widget.showSummaryFormat || widget.simpleUI;

    if (_size.aspectRatio < 0.1 ||
        _size.aspectRatio > 10 ||
        !_imageIsLoaded ||
        widget.showSummaryFormat) {
      return Container(
        color: widget.showSummaryFormat
            ? null
            : fromMe
                ? theme.primaryColor
                : theme.secondaryColor,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 64,
              margin: widget.showSummaryFormat
                  ? const EdgeInsets.only(right: 16)
                  : EdgeInsets.fromLTRB(
                      theme.messageInsetsVertical,
                      theme.messageInsetsVertical,
                      16,
                      theme.messageInsetsVertical,
                    ),
              width: 64,
              child: _imageIsLoaded
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(15),
                      child: Image(
                        fit: BoxFit.cover,
                        image: _image!,
                      ),
                    )
                  : const Icon(Icons.image, size: 48),
            ),
            Flexible(
              child: Container(
                margin: widget.showSummaryFormat
                    ? null
                    : EdgeInsets.fromLTRB(
                        0,
                        theme.messageInsetsVertical,
                        theme.messageInsetsHorizontal,
                        theme.messageInsetsVertical,
                      ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ChatText(name, theme, fromMe: fromMe, noStyle: noStyle),
                    const SizedBox(height: 4),
                    ChatCaption(
                      _captionText,
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
      );
    } else {
      return Column(
        crossAxisAlignment: widget.simpleUI
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          Container(
            constraints: _constraints,
            decoration: widget.showBlurredBackground
                ? BoxDecoration(
                    image: DecorationImage(
                      fit: BoxFit.cover,
                      image: _image!,
                    ),
                  )
                : null,
            child: widget.showBlurredBackground
                ? BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 1, sigmaY: 1),
                    child: AspectRatio(
                      aspectRatio:
                          _size.aspectRatio > 0 ? _size.aspectRatio : 1,
                      child: Image(
                        fit: BoxFit.contain,
                        image: _image!,
                      ),
                    ),
                  )
                : Image(image: _image!),
          ),
          if (!widget.message.isEmoji)
            Padding(
              padding: widget.simpleUI
                  ? const EdgeInsets.only(top: 4, bottom: 4)
                  : const EdgeInsets.all(4),
              child: ChatCaption(
                _captionText,
                theme,
                fromMe: fromMe,
                noStyle: noStyle,
              ),
            ),
        ],
      );
    }
  }

  /// Make sure the constraints fit the aspect ratio.
  BoxConstraints get _constraints {
    final messageWidth = widget.messageWidth?.toDouble() ?? 400;
    var maxH = min(messageWidth + 50, min(500, _size.height));
    var maxW = min(max(170, _size.width), maxH * _size.aspectRatio);
    var minW = min(maxW, min(170, _size.width));

    return BoxConstraints(
      maxHeight: maxH.toDouble(),
      maxWidth: maxW.toDouble(),
      minWidth: minW.toDouble(),
    );
  }
}
