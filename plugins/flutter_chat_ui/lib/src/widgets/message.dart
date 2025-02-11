import 'package:flutter/material.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import '../models/emoji_enlargement_behavior.dart';
import '../util.dart';
import 'emoji_message.dart';
import 'file_message.dart';
import 'image_message.dart';
import 'inherited_chat_theme.dart';
import 'inherited_user.dart';
import 'reply_message.dart';
import 'text_message.dart';
import 'text.dart';

/// Base widget for all message types in the chat. Renders bubbles around
/// messages and status. Sets maximum width for a message for
/// a nice look on larger screens.
// ignore: must_be_immutable
class Message extends StatelessWidget {
  /// Creates a particular message from any message type
  Message({
    Key? key,
    this.bubbleBuilder,
    this.customMessageBuilder,
    this.detailStatusBuilder,
    required this.emojiEnlargementBehavior,
    this.fileMessageBuilder,
    required this.hideBackgroundOnEmojiMessages,
    this.imageMessageBuilder,
    this.isTV = false,
    required this.message,
    required this.messageWidth,
    this.onMessageLongPress,
    this.onMessageTap,
    this.onPreviewDataFetched,
    this.replyMessage,
    required this.roundBorder,
    required this.showAvatar,
    required this.showName,
    required this.showStatus,
    required this.showUserAvatars,
    this.simpleUI = false,
    this.textMessageBuilder,
    this.emojiMessageBuilder,
    this.uriFixup,
    this.logger,
    required this.usePreviewData,
    this.textSelectable = false,
  }) : super(key: key);

  /// Customize the default bubble using this function. `child` is a content
  /// you should render inside your bubble, `message` is a current message
  /// (contains `author` inside) and `nextMessageInGroup` allows you to see
  /// if the message is a part of a group (messages are grouped when written
  /// in quick succession by the same author)
  final Widget Function(
    Widget child, {
    required types.Message message,
    required bool nextMessageInGroup,
  })? bubbleBuilder;

  /// Build a custom message inside predefined bubble
  final Widget Function(types.CustomMessage, {required int messageWidth})?
      customMessageBuilder;

  /// Additional detail message status
  final Widget Function(types.Message)? detailStatusBuilder;

  /// Controls the enlargement behavior of the emojis in the
  /// [types.TextMessage].
  /// Defaults to [EmojiEnlargementBehavior.multi].
  final EmojiEnlargementBehavior emojiEnlargementBehavior;

  /// Build a file message inside predefined bubble
  final Widget Function(types.FileMessage, {required int messageWidth})?
      fileMessageBuilder;

  /// Hide background for messages containing only emojis.
  final bool hideBackgroundOnEmojiMessages;

  /// TV UI support.
  final bool isTV;

  /// Build an image message inside predefined bubble
  final Widget Function(types.ImageMessage, {required int messageWidth})?
      imageMessageBuilder;

  /// Any message type
  final types.Message message;

  /// Maximum message width
  final int messageWidth;

  /// Called when user makes a long press on any message
  final void Function(types.Message, Offset?)? onMessageLongPress;

  /// Called when user taps on any message
  final void Function(types.Message, Offset?)? onMessageTap;

  /// See [TextMessage.onPreviewDataFetched]
  final void Function(types.TextMessage, types.PreviewData)?
      onPreviewDataFetched;

  /// Set if this message is replying to another message.
  final types.Message? replyMessage;

  /// Rounds border of the message to visually group messages together.
  final bool roundBorder;

  /// Show user avatar for the received message. Useful for a group chat.
  final bool showAvatar;

  /// See [TextMessage.showName]
  final bool showName;

  /// Show message's status
  final bool showStatus;

  /// Show user avatars for received messages. Useful for a group chat.
  final bool showUserAvatars;

  /// Simple UI shows no bubble, background color et al.
  final bool simpleUI;

  /// Text selectable or not.
  final bool textSelectable;

  /// Build a text message inside predefined bubble.
  final Widget Function(
    types.TextMessage, {
    required int messageWidth,
    required bool showName,
  })? textMessageBuilder;

  /// Build an emoji widget inside predefined bubble.
  final Widget Function(
    types.EmojiMessage, {
    required int messageWidth,
  })? emojiMessageBuilder;

  /// See [TextMessage.usePreviewData]
  final bool usePreviewData;

  /// see [FileMessage.uriFixup]
  final Future<String?> Function(String?)? uriFixup;

  /// Logger function
  final void Function({String? d, String? i, String? w, String? e})? logger;

  /// Saved tap position
  Offset? _savedTapPosition;

  Widget _avatarBuilder(BuildContext context) {
    final color = getUserAvatarNameColor(
      message.author,
      InheritedChatTheme.of(context).theme.userAvatarNameColors,
    );
    final imageUrl = message.author.imageUrl;
    final hasImage = imageUrl != null && imageUrl.isNotEmpty;
    final initials = getUserInitials(message.author);

    return showAvatar || simpleUI
        ? Container(
            margin: const EdgeInsets.only(right: 8),
            child: CircleAvatar(
              backgroundColor: hasImage
                  ? InheritedChatTheme.of(context)
                      .theme
                      .userAvatarImageBackgroundColor
                  : color,
              backgroundImage:
                  hasImage ? NetworkImage(message.author.imageUrl!) : null,
              radius: 16,
              child: !hasImage
                  ? Text(
                      initials,
                      style: InheritedChatTheme.of(context)
                          .theme
                          .userAvatarTextStyle,
                    )
                  : null,
            ),
          )
        : const SizedBox(width: 40);
  }

  Widget _bubbleBuilder(
    BuildContext context,
    BorderRadius borderRadius,
    bool currentUserIsAuthor,
    bool enlargeEmojis,
  ) {
    return bubbleBuilder != null
        ? bubbleBuilder!(
            _messageWithReplyMessageBuilder(),
            message: message,
            nextMessageInGroup: roundBorder,
          )
        : enlargeEmojis && hideBackgroundOnEmojiMessages
            ? _messageWithReplyMessageBuilder()
            : Container(
                padding: simpleUI ? const EdgeInsets.only(right: 10) : null,
                decoration: BoxDecoration(
                  borderRadius: borderRadius,
                  color: simpleUI
                      ? null
                      : !currentUserIsAuthor ||
                              message.type == types.MessageType.image
                          ? InheritedChatTheme.of(context).theme.secondaryColor
                          : InheritedChatTheme.of(context).theme.primaryColor,
                ),
                child: ClipRRect(
                  borderRadius: borderRadius,
                  child: _messageWithReplyMessageBuilder(),
                ),
              );
  }

  Widget _messageWithReplyMessageBuilder() {
    final message = replyMessage;
    if (message == null) {
      return _messageBuilder();
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Column(
            crossAxisAlignment:
                simpleUI ? CrossAxisAlignment.start : CrossAxisAlignment.center,
            children: [
              _replyMessageBuilder(message),
              _messageBuilder(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _replyMessageBuilder(types.Message message) {
    return ReplyMessage(
      message: message,
      shrinkWrap: true,
      uriFixup: uriFixup,
    );
  }

  Widget _messageBuilder() {
    switch (message.type) {
      case types.MessageType.custom:
        final customMessage = message as types.CustomMessage;
        return customMessageBuilder != null
            ? customMessageBuilder!(customMessage, messageWidth: messageWidth)
            : const SizedBox();
      case types.MessageType.file:
        final fileMessage = message as types.FileMessage;
        return fileMessageBuilder != null
            ? fileMessageBuilder!(fileMessage, messageWidth: messageWidth)
            : FileMessage(
                message: fileMessage,
                messageWidth: messageWidth,
                simpleUI: simpleUI,
                uriFixup: uriFixup,
                logger: logger,
              );
      case types.MessageType.image:
        final imageMessage = message as types.ImageMessage;
        return imageMessageBuilder != null
            ? imageMessageBuilder!(imageMessage, messageWidth: messageWidth)
            : ImageMessage(
                message: imageMessage,
                messageWidth: messageWidth,
                simpleUI: simpleUI,
                uriFixup: uriFixup,
              );
      case types.MessageType.text:
        final textMessage = message as types.TextMessage;
        return textMessageBuilder != null
            ? textMessageBuilder!(
                textMessage,
                messageWidth: messageWidth,
                showName: showName && !simpleUI,
              )
            : TextMessage(
                emojiEnlargementBehavior: emojiEnlargementBehavior,
                hideBackgroundOnEmojiMessages: hideBackgroundOnEmojiMessages,
                message: textMessage,
                onPreviewDataFetched: onPreviewDataFetched,
                showName: showName && !simpleUI,
                simpleUI: simpleUI,
                usePreviewData: usePreviewData,
                selectable: textSelectable,
                onMessageTap: () => onMessageLongPress?.call(
                  message,
                  _savedTapPosition,
                ),
              );
      case types.MessageType.emoji:
        final m = message as types.EmojiMessage;
        return emojiMessageBuilder != null
            ? emojiMessageBuilder!(m, messageWidth: messageWidth)
            : EmojiMessage(message: m, messageWidth: messageWidth);
      default:
        return const SizedBox();
    }
  }

  Widget _statusBuilder(BuildContext context) {
    switch (message.status) {
      case types.Status.delivered:
      case types.Status.sent:
        return InheritedChatTheme.of(context).theme.deliveredIcon != null
            ? InheritedChatTheme.of(context).theme.deliveredIcon!
            : Image.asset(
                'assets/icon-delivered.png',
                color: InheritedChatTheme.of(context).theme.primaryColor,
                package: 'flutter_chat_ui',
              );
      case types.Status.error:
        return InheritedChatTheme.of(context).theme.errorIcon != null
            ? InheritedChatTheme.of(context).theme.errorIcon!
            : Image.asset(
                'assets/icon-error.png',
                color: InheritedChatTheme.of(context).theme.errorColor,
                package: 'flutter_chat_ui',
              );
      case types.Status.seen:
        return InheritedChatTheme.of(context).theme.seenIcon != null
            ? InheritedChatTheme.of(context).theme.seenIcon!
            : Image.asset(
                'assets/icon-seen.png',
                color: InheritedChatTheme.of(context).theme.primaryColor,
                package: 'flutter_chat_ui',
              );
      case types.Status.sending:
        double? percentage;
        if (message is types.FileMessage) {
          final fileMessage = message as types.FileMessage;
          percentage = fileMessage.percentage;
        }
        return InheritedChatTheme.of(context).theme.sendingIcon != null
            ? InheritedChatTheme.of(context).theme.sendingIcon!
            : Center(
                child: SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(
                    value: percentage,
                    backgroundColor: Colors.transparent,
                    strokeWidth: 1.5,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      InheritedChatTheme.of(context).theme.primaryColor,
                    ),
                  ),
                ),
              );
      case types.Status.toretry:
      case types.Status.paused:
        return const Icon(Icons.pause_circle_outline_rounded, size: 12);
      default:
        return const SizedBox();
    }
  }

  Widget _detailStatusBuilder(context) {
    var metadata = message.metadata;
    if (metadata != null && metadata["progress"] != null) {
      for (var k in metadata["progress"].keys) {
        String p = metadata["progress"][k];
        if (p.isNotEmpty) {
          return Text("$p $k");
        }
      }
    }
    return detailStatusBuilder?.call(message) ?? const SizedBox();
  }

  bool get _isEmojiImage {
    final m = message;
    return m is types.ImageMessage && m.isEmoji;
  }

  bool get _enlargeTextMessageEmojis {
    final m = message;
    return m is types.TextMessage &&
        isConsistsOfEmojis(emojiEnlargementBehavior, m);
  }

  bool get _enlargeEmojiMessageEmojis {
    return message is types.EmojiMessage && message.replyId == null;
  }

  bool get _enlargeEmojis {
    return emojiEnlargementBehavior != EmojiEnlargementBehavior.never &&
        (_enlargeTextMessageEmojis ||
            _isEmojiImage ||
            _enlargeEmojiMessageEmojis);
  }

  Widget _buildMessageBody(BuildContext context, Widget bubbleChild) {
    return GestureDetector(
      onSecondaryTapDown: (TapDownDetails details) {
        _savedTapPosition = details.globalPosition;
      },
      onTapDown: (TapDownDetails details) {
        _savedTapPosition = details.globalPosition;
      },
      onSecondaryTap: () => onMessageLongPress?.call(
        message,
        _savedTapPosition,
      ),
      onLongPress: () => onMessageLongPress?.call(
        message,
        _savedTapPosition,
      ),
      onTap: () => onMessageTap?.call(message, _savedTapPosition),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: bubbleChild,
      ),
    );
  }

  bool _currentUserIsAuthor(BuildContext context) {
    final user = InheritedUser.of(context).user;
    return user.id == message.author.id &&
        message.status != types.Status.received;
  }

  BorderRadius _borderRadius(BuildContext context) {
    final bool isAuthor = _currentUserIsAuthor(context);
    final messageBorderRadius =
        InheritedChatTheme.of(context).theme.messageBorderRadius;
    return BorderRadius.only(
      bottomLeft: Radius.circular(
        isAuthor || roundBorder ? messageBorderRadius : 0,
      ),
      bottomRight: Radius.circular(isAuthor
          ? roundBorder
              ? messageBorderRadius
              : 0
          : messageBorderRadius),
      topLeft: Radius.circular(messageBorderRadius),
      topRight: Radius.circular(messageBorderRadius),
    );
  }

  @override
  Widget build(BuildContext context) {
    final messageWidget = _buildMessage(context);
    if (isTV) {
      return ListTile(
        title: messageWidget,
        onTap: () => onMessageTap?.call(message, _savedTapPosition),
      );
    }
    return messageWidget;
  }

  Widget _buildMessage(BuildContext context) {
    // Skip showing delete message
    if (message is types.DeleteMessage) {
      return const SizedBox();
    }

    final theme = InheritedChatTheme.of(context).theme;
    final isAuthor = _currentUserIsAuthor(context);
    final color = getUserAvatarNameColor(
      message.author,
      theme.userAvatarNameColors,
    );
    final name = getUserName(message.author);

    return Container(
      alignment:
          isAuthor && !simpleUI ? Alignment.centerRight : Alignment.centerLeft,
      margin: const EdgeInsets.only(
        bottom: 4,
        left: 20,
      ),
      child: Row(
        crossAxisAlignment:
            simpleUI ? CrossAxisAlignment.start : CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          if ((!isAuthor || simpleUI) && showUserAvatars)
            _avatarBuilder(context),
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: simpleUI ? double.infinity : messageWidth.toDouble(),
              ),
              child: Column(
                crossAxisAlignment: simpleUI
                    ? CrossAxisAlignment.start
                    : CrossAxisAlignment.end,
                children: [
                  if (simpleUI) Username(name, theme, color),
                  _buildMessageBody(
                    context,
                    _bubbleBuilder(
                      context,
                      _borderRadius(context),
                      isAuthor,
                      _enlargeEmojis,
                    ),
                  ),
                  if (showStatus) _detailStatusBuilder(context),
                  if (simpleUI && showStatus && isAuthor)
                    _statusBuilder(context),
                ],
              ),
            ),
          ),
          if (isAuthor && !simpleUI)
            Padding(
              padding: InheritedChatTheme.of(context).theme.statusIconPadding,
              child: showStatus ? _statusBuilder(context) : null,
            ),
        ],
      ),
    );
  }
}
