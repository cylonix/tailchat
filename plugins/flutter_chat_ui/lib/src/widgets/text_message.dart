import 'package:flutter/material.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:flutter_link_previewer/flutter_link_previewer.dart'
    show LinkPreview, regexLink;
import '../models/emoji_enlargement_behavior.dart';
import '../util.dart';
import 'inherited_chat_theme.dart';
import 'inherited_user.dart';
import 'text.dart';

/// A class that represents text message widget with optional link preview
class TextMessage extends StatelessWidget {
  /// Creates a text message widget from a [types.TextMessage] class
  const TextMessage({
    Key? key,
    required this.emojiEnlargementBehavior,
    required this.hideBackgroundOnEmojiMessages,
    required this.message,
    this.onPreviewDataFetched,
    this.onMessageTap,
    required this.usePreviewData,
    required this.showName,
    this.simpleUI = false,
    this.selectable = false,
  }) : super(key: key);

  /// See [Message.emojiEnlargementBehavior]
  final EmojiEnlargementBehavior emojiEnlargementBehavior;

  /// See [Message.hideBackgroundOnEmojiMessages]
  final bool hideBackgroundOnEmojiMessages;

  /// [types.TextMessage]
  final types.TextMessage message;

  /// See [LinkPreview.onPreviewDataFetched]
  final void Function(types.TextMessage, types.PreviewData)?
      onPreviewDataFetched;

  /// Show user name for the received message. Useful for a group chat.
  final bool showName;

  /// Simple UI
  final bool simpleUI;

  /// Enables link (URL) preview
  final bool usePreviewData;

  /// Selectable or not
  final bool selectable;

  /// Callback on SelectableText
  final void Function()? onMessageTap;

  void _onPreviewDataFetched(types.PreviewData previewData) {
    if (message.previewData == null) {
      onPreviewDataFetched?.call(message, previewData);
    }
  }

  Widget _linkPreview(
    types.User user,
    double width,
    BuildContext context,
  ) {
    final theme = InheritedChatTheme.of(context).theme;
    final fromMe = user.id == message.author.id &&
        message.status != types.Status.received &&
        !simpleUI;
    final bodyTextStyle = fromMe
        ? theme.sentMessageBodyTextStyle
        : theme.receivedMessageBodyTextStyle;
    final linkDescriptionTextStyle = fromMe
        ? theme.sentMessageLinkDescriptionTextStyle
        : theme.receivedMessageLinkDescriptionTextStyle;
    final linkTitleTextStyle = fromMe
        ? theme.sentMessageLinkTitleTextStyle
        : theme.receivedMessageLinkTitleTextStyle;

    final color =
        getUserAvatarNameColor(message.author, theme.userAvatarNameColors);
    final name = getUserName(message.author);

    return LinkPreview(
      enableAnimation: true,
      header: showName ? name : null,
      headerStyle: theme.userNameTextStyle.copyWith(color: color),
      linkStyle: bodyTextStyle,
      metadataTextStyle: linkDescriptionTextStyle,
      metadataTitleStyle: linkTitleTextStyle,
      onPreviewDataFetched: _onPreviewDataFetched,
      padding: EdgeInsets.symmetric(
        horizontal: simpleUI ? 0 : theme.messageInsetsHorizontal,
        vertical: theme.messageInsetsVertical,
      ),
      previewData: message.previewData,
      text: message.text,
      textStyle: bodyTextStyle,
      width: width,
    );
  }

  Widget _textWidgetBuilder(
    types.User user,
    BuildContext context,
    bool enlargeEmojis,
  ) {
    final theme = InheritedChatTheme.of(context).theme;
    final color =
        getUserAvatarNameColor(message.author, theme.userAvatarNameColors);
    final name = getUserName(message.author);
    final fromMe = user.id == message.author.id &&
        message.status != types.Status.received &&
        !simpleUI;
    final style = fromMe
        ? enlargeEmojis
            ? theme.sentEmojiMessageTextStyle
            : theme.sentMessageBodyTextStyle
        : enlargeEmojis
            ? theme.receivedEmojiMessageTextStyle
            : theme.receivedMessageBodyTextStyle;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showName) Username(name, theme, color),
        selectable
            ? SelectableText(
                message.text,
                style: style,
                textWidthBasis: TextWidthBasis.longestLine,
                onTap: onMessageTap,
              )
            : Text(
                message.text,
                style: style,
                textWidthBasis: TextWidthBasis.longestLine,
              ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final _enlargeEmojis =
        emojiEnlargementBehavior != EmojiEnlargementBehavior.never &&
            isConsistsOfEmojis(emojiEnlargementBehavior, message);
    final _theme = InheritedChatTheme.of(context).theme;
    final _user = InheritedUser.of(context).user;
    final _width = MediaQuery.of(context).size.width;

    if (usePreviewData && onPreviewDataFetched != null) {
      final urlRegexp = RegExp(regexLink, caseSensitive: false);
      final matches = urlRegexp.allMatches(message.text);

      if (matches.isNotEmpty) {
        return _linkPreview(_user, _width, context);
      }
    }

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: _enlargeEmojis && hideBackgroundOnEmojiMessages || simpleUI
            ? 0.0
            : _theme.messageInsetsHorizontal,
        vertical: _theme.messageInsetsVertical,
      ),
      child: _textWidgetBuilder(_user, context, _enlargeEmojis),
    );
  }
}
