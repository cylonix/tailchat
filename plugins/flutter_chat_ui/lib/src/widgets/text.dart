import 'package:flutter/material.dart';
import '../chat_theme.dart';

/// A [Text] class extension that sets the common text theme for text.
class ChatText extends Text {
  ChatText(
    String text,
    ChatTheme theme, {
    Key? key,
    bool fromMe = false,
    bool noStyle = false,
  }) : super(
          text,
          key: key,
          style: noStyle
              ? null
              : fromMe
                  ? theme.sentMessageBodyTextStyle
                  : theme.receivedMessageBodyTextStyle,
          textWidthBasis: TextWidthBasis.longestLine,
        );
}

/// A [Text] class extension that sets the common text theme for caption.
class ChatCaption extends Text {
  ChatCaption(
    String text,
    ChatTheme theme, {
    Key? key,
    bool fromMe = false,
    bool noStyle = false,
  }) : super(
          text,
          key: key,
          style: noStyle
              ? null
              : fromMe
                  ? theme.sentMessageCaptionTextStyle
                  : theme.receivedMessageCaptionTextStyle,
          textWidthBasis: TextWidthBasis.longestLine,
        );
}

/// A [Padding] class extension that shows the username.
class Username extends Padding {
  Username(String name, ChatTheme theme, Color color, {Key? key})
      : super(
          key: key,
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.userNameTextStyle.copyWith(color: color),
          ),
        );
}
