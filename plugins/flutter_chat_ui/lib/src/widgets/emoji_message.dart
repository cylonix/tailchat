import 'package:flutter/material.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:cylonix_emojis/cylonix_emojis.dart';

/// A class that represents emoji message widget.
class EmojiMessage extends StatefulWidget {
  /// Creates an emoji message widget based on [types.EmojiMessage]
  const EmojiMessage({
    Key? key,
    required this.message,
    required this.messageWidth,
  }) : super(key: key);

  /// [types.EmojiMessage]
  final types.EmojiMessage message;

  /// Maximum message width
  final int messageWidth;

  @override
  _EmojiMessageState createState() => _EmojiMessageState();
}

/// [EmojiMessage] widget state
class _EmojiMessageState extends State<EmojiMessage> {
  @override
  Widget build(BuildContext context) {
    final codes = widget.message.text.codeUnits;
    final emojis = <Widget>[];
    for (int i = 0; i < codes.length; i++) {
      final emoji = lookupByCode(codes[i]);
      if (emoji != null) {
        emojis.add(Image.asset(emoji.assetPath));
      }
    }
    return Wrap(
      children: emojis,
    );
  }
}
