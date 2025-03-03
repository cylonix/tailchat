import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import './inherited_l10n.dart';
import 'package:intl/intl.dart';
import 'package:photo_view/photo_view_gallery.dart';
import '../chat_l10n.dart';
import '../chat_theme.dart';
import '../conditional/conditional.dart';
import '../models/date_header.dart';
import '../models/emoji_enlargement_behavior.dart';
import '../models/message_spacer.dart';
import '../models/preview_image.dart';
import '../models/send_button_visibility_mode.dart';
import '../util.dart';
import 'chat_list.dart';
import 'inherited_chat_theme.dart';
import 'inherited_user.dart';
import 'input.dart';
import 'message.dart';
import 'reply_message.dart';

/// Entry widget, represents the complete chat. If you wrap it in [SafeArea] and
/// it should be full screen, set [SafeArea]'s `bottom` to `false`.
class Chat extends StatefulWidget {
  /// Creates a chat widget
  const Chat({
    Key? key,
    this.bubbleBuilder,
    this.customBottomWidget,
    this.customDateHeaderText,
    this.customMessageBuilder,
    this.dateFormat,
    this.dateHeaderThreshold = 900000,
    this.dateLocale,
    this.detailStatusBuilder,
    this.disableImageGallery,
    this.emojiEnlargementBehavior = EmojiEnlargementBehavior.multi,
    this.emptyState,
    this.fileMessageBuilder,
    this.groupMessagesThreshold = 60000,
    this.hideBackgroundOnEmojiMessages = true,
    this.imageMessageBuilder,
    this.inputLeading,
    this.isAttachmentUploading,
    this.isLastPage,
    this.isTV = false,
    this.l10n = const ChatL10nEn(),
    required this.messages,
    this.onAttachmentPressed,
    this.onBackgroundTap,
    this.onCloseReplyMessagePressed,
    this.onEndReached,
    this.onEndReachedThreshold,
    this.onMessageLongPress,
    this.onMessageTap,
    this.onPreviewDataFetched,
    required this.onSendPressed,
    this.onTextChanged,
    this.onTextFieldTap,
    this.onVoiceInput,
    this.replyMessage,
    this.scrollPhysics,
    this.sendButtonVisibilityMode = SendButtonVisibilityMode.editing,
    this.showUserAvatars = false,
    this.showUserNames = false,
    this.simpleUI = false,
    this.textMessageBuilder,
    this.emojiMessageBuilder,
    this.textSelectable = false,
    this.theme = const DefaultChatTheme(),
    this.timeFormat,
    this.usePreviewData = true,
    this.uriFixup,
    this.logger,
    this.onImageAssetSelected,
    this.onEmojiSelected,
    required this.user,
  }) : super(key: key);

  /// See [Message.bubbleBuilder]
  final Widget Function(
    Widget child, {
    required types.Message message,
    required bool nextMessageInGroup,
  })? bubbleBuilder;

  /// See [Input.onImageAssetSelected]
  final void Function(String)? onImageAssetSelected;

  /// See [Input.onEmojiSelected]
  final void Function(String, String)? onEmojiSelected;

  /// Allows you to replace the default Input widget e.g. if you want to create
  /// a channel view.
  final Widget? customBottomWidget;

  /// If [dateFormat], [dateLocale] and/or [timeFormat] is not enough to
  /// customize date headers in your case, use this to return an arbitrary
  /// string based on a [DateTime] of a particular message. Can be helpful to
  /// return "Today" if [DateTime] is today. IMPORTANT: this will replace
  /// all default date headers, so you must handle all cases yourself, like
  /// for example today, yesterday and before. Or you can just return the same
  /// date header for any message.
  final String Function(DateTime)? customDateHeaderText;

  /// See [Message.customMessageBuilder]
  final Widget Function(types.CustomMessage, {required int messageWidth})?
      customMessageBuilder;

  /// Allows you to customize the date format. IMPORTANT: only for the date,
  /// do not return time here. See [timeFormat] to customize the time format.
  /// [dateLocale] will be ignored if you use this, so if you want a localized date
  /// make sure you initialize your [DateFormat] with a locale. See [customDateHeaderText]
  /// for more customization.
  final DateFormat? dateFormat;

  /// Time (in ms) between two messages when we will render a date header.
  /// Default value is 15 minutes, 900000 ms. When time between two messages
  /// is higher than this threshold, date header will be rendered. Also,
  /// not related to this value, date header will be rendered on every new day.
  final int dateHeaderThreshold;

  /// Locale will be passed to the `Intl` package. Make sure you initialized
  /// date formatting in your app before passing any locale here, otherwise
  /// an error will be thrown. Also see [customDateHeaderText], [dateFormat], [timeFormat].
  final String? dateLocale;

  /// See [Message.detailStatusBuilder]
  final Widget Function(types.Message)? detailStatusBuilder;

  /// Disable automatic image preview on tap.
  final bool? disableImageGallery;

  /// See [Message.emojiEnlargementBehavior]
  final EmojiEnlargementBehavior emojiEnlargementBehavior;

  /// Allows you to change what the user sees when there are no messages.
  /// `emptyChatPlaceholder` and `emptyChatPlaceholderTextStyle` are ignored
  /// in this case.
  final Widget? emptyState;

  /// See [Message.fileMessageBuilder]
  final Widget Function(types.FileMessage, {required int messageWidth})?
      fileMessageBuilder;

  /// Time (in ms) between two messages when we will visually group them.
  /// Default value is 1 minute, 60000 ms. When time between two messages
  /// is lower than this threshold, they will be visually grouped.
  final int groupMessagesThreshold;

  /// See [Message.hideBackgroundOnEmojiMessages]
  final bool hideBackgroundOnEmojiMessages;

  /// See [Message.imageMessageBuilder]
  final Widget Function(types.ImageMessage, {required int messageWidth})?
      imageMessageBuilder;

  /// see [Input.leading]
  final Widget? inputLeading;

  /// See [Input.isAttachmentUploading]
  final bool? isAttachmentUploading;

  /// See [ChatList.isLastPage]
  final bool? isLastPage;

  /// See [Message.isTV]
  final bool isTV;

  /// Localized copy. Extend [ChatL10n] class to create your own copy or use
  /// existing one, like the default [ChatL10nEn]. You can customize only
  /// certain properties, see more here [ChatL10nEn].
  final ChatL10n l10n;

  /// List of [types.Message] to render in the chat widget
  final List<types.Message> messages;

  /// See [Input.onAttachmentPressed]
  final void Function()? onAttachmentPressed;

  /// Called when user taps on background
  final void Function()? onBackgroundTap;

  /// Called when reply message widget is closed.
  final void Function()? onCloseReplyMessagePressed;

  /// See [ChatList.onEndReached]
  final Future<void> Function()? onEndReached;

  /// See [ChatList.onEndReachedThreshold]
  final double? onEndReachedThreshold;

  /// See [Message.onMessageLongPress]
  final void Function(types.Message, Offset?)? onMessageLongPress;

  /// See [Message.onMessageTap]
  final void Function(types.Message, Offset?)? onMessageTap;

  /// See [Message.onPreviewDataFetched]
  final void Function(types.TextMessage, types.PreviewData)?
      onPreviewDataFetched;

  /// See [Input.onSendPressed]
  final void Function(types.PartialText) onSendPressed;

  /// See [Input.onTextChanged]
  final void Function(String)? onTextChanged;

  /// See [Input.onTextFieldTap]
  final void Function()? onTextFieldTap;

  /// See [Input.onVoiceInput]
  final void Function(bool)? onVoiceInput;

  /// If there is message to reply to
  final types.Message? replyMessage;

  /// See [ChatList.scrollPhysics]
  final ScrollPhysics? scrollPhysics;

  /// See [Input.sendButtonVisibilityMode]
  final SendButtonVisibilityMode sendButtonVisibilityMode;

  /// See [Message.showUserAvatars]
  final bool showUserAvatars;

  /// Show user names for received messages. Useful for a group chat. Will be
  /// shown only on text messages.
  final bool showUserNames;

  /// Show simplified UI without bubbles et al.
  final bool simpleUI;

  /// see [Message.textSelectable]
  final bool textSelectable;

  /// See [Message.textMessageBuilder]
  final Widget Function(
    types.TextMessage, {
    required int messageWidth,
    required bool showName,
  })? textMessageBuilder;

  /// See [Message.emojiMessageBuilder]
  final Widget Function(
    types.EmojiMessage, {
    required int messageWidth,
  })? emojiMessageBuilder;

  /// Chat theme. Extend [ChatTheme] class to create your own theme or use
  /// existing one, like the [DefaultChatTheme]. You can customize only certain
  /// properties, see more here [DefaultChatTheme].
  final ChatTheme theme;

  /// Allows you to customize the time format. IMPORTANT: only for the time,
  /// do not return date here. See [dateFormat] to customize the date format.
  /// [dateLocale] will be ignored if you use this, so if you want a localized time
  /// make sure you initialize your [DateFormat] with a locale. See [customDateHeaderText]
  /// for more customization.
  final DateFormat? timeFormat;

  /// See [Message.usePreviewData]
  final bool usePreviewData;

  /// See [InheritedUser.user]
  final types.User user;

  /// Fix the URI in the message e.g. converting from relative path to absolute
  /// path. See [ImageMessage.uriFixup]
  final Future<String?> Function(String?)? uriFixup;

  /// Logger function
  final void Function({String? d, String? i, String? w, String? e})? logger;

  @override
  State<Chat> createState() => _ChatState();
}

/// [Chat] widget state
class _ChatState extends State<Chat> {
  final _imageGalleryFocus = FocusNode();
  List<Object> _chatMessages = [];
  List<PreviewImage> _gallery = [];
  int _imageViewIndex = 0;
  bool _isImageViewVisible = false;

  @override
  void initState() {
    super.initState();
    didUpdateWidget(widget);
  }

  @override
  void dispose() {
    _imageGalleryFocus.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant Chat oldWidget) {
    super.didUpdateWidget(oldWidget);
    _calculateChatMessages();
  }

  void _calculateChatMessages() async {
    if (widget.messages.isNotEmpty) {
      final result = await calculateChatMessages(
        widget.messages,
        widget.user,
        customDateHeaderText: widget.customDateHeaderText,
        dateFormat: widget.dateFormat,
        dateHeaderThreshold: widget.dateHeaderThreshold,
        dateLocale: widget.dateLocale,
        groupMessagesThreshold: widget.groupMessagesThreshold,
        showUserNames: widget.showUserNames,
        timeFormat: widget.timeFormat,
        enableImageGallery: widget.disableImageGallery != true,
        simpleUI: widget.simpleUI,
        uriFixup: widget.uriFixup,
      );
      if (mounted) {
        setState(() {
          _chatMessages = result[0] as List<Object>;
          _gallery = result[1] as List<PreviewImage>;
        });
      }
    }
  }

  Widget _emptyStateBuilder() {
    return widget.emptyState ??
        Container(
          alignment: Alignment.center,
          margin: const EdgeInsets.symmetric(
            horizontal: 24,
          ),
          child: Text(
            widget.l10n.emptyChatPlaceholder,
            style: widget.theme.emptyChatPlaceholderTextStyle,
            textAlign: TextAlign.center,
          ),
        );
  }

  void _changeImage(PageController controller, int index) {
    if (index != _imageViewIndex) {
      if (widget.isTV) {
        controller.jumpToPage(index);
      }
      setState(() {
        _imageViewIndex = index;
      });
    }
  }

  Widget _imageGalleryBuilder() {
    final controller = PageController(initialPage: _imageViewIndex);
    return Dismissible(
      key: const Key('photo_view_gallery'),
      direction: DismissDirection.down,
      onDismissed: (direction) => _onCloseGalleryPressed(),
      child: Stack(
        children: [
          Focus(
            focusNode: _imageGalleryFocus,
            child: PhotoViewGallery.builder(
              enableRotation: true,
              builder: (BuildContext context, int index) =>
                  PhotoViewGalleryPageOptions(
                imageProvider: Conditional().getProvider(_gallery[index].uri),
              ),
              itemCount: _gallery.length,
              loadingBuilder: (context, event) =>
                  _imageGalleryLoadingBuilder(context, event),
              onPageChanged: _onPageChanged,
              pageController: controller,
              scrollPhysics: const ClampingScrollPhysics(),
              allowImplicitScrolling: widget.isTV,
            ),
            onKeyEvent: (node, event) {
              if (node != _imageGalleryFocus) {
                return KeyEventResult.ignored;
              }
              if (event.logicalKey == LogicalKeyboardKey.arrowUp ||
                  event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                final i = _imageViewIndex - 1 < 0 ? 0 : _imageViewIndex - 1;
                _changeImage(controller, i);
                return KeyEventResult.handled;
              } else if (event.logicalKey == LogicalKeyboardKey.arrowDown ||
                  event.logicalKey == LogicalKeyboardKey.arrowRight) {
                final max = _gallery.length - 1;
                var i = _imageViewIndex + 1 > max ? max : _imageViewIndex + 1;
                _changeImage(controller, i);
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
          ),
          if (!widget.isTV)
            Positioned(
              right: 16,
              top: 56,
              child: CloseButton(
                color: Colors.white,
                onPressed: _onCloseGalleryPressed,
              ),
            ),
        ],
      ),
    );
  }

  Widget _imageGalleryLoadingBuilder(
    BuildContext context,
    ImageChunkEvent? event,
  ) {
    return Center(
      child: SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          value: event == null || event.expectedTotalBytes == null
              ? 0
              : event.cumulativeBytesLoaded / event.expectedTotalBytes!,
        ),
      ),
    );
  }

  types.Message? _getReplyMessage(String? replyId) {
    if (replyId == null) {
      return null;
    }
    try {
      return widget.messages.firstWhere((element) => element.id == replyId);
    } catch (_) {
      return null;
    }
  }

  Widget _messageBuilder(Object object, BoxConstraints constraints) {
    if (object is DateHeader) {
      return Container(
        alignment: widget.simpleUI ? Alignment.centerLeft : Alignment.center,
        margin: widget.theme.dateDividerMargin,
        padding: widget.simpleUI ? const EdgeInsets.only(left: 10) : null,
        child: Text(
          object.text,
          style: widget.theme.dateDividerTextStyle,
        ),
      );
    } else if (object is MessageSpacer) {
      return SizedBox(
        height: object.height,
      );
    } else {
      final map = object as Map<String, Object>;
      final message = map['message']! as types.Message;
      final _messageWidth =
          widget.showUserAvatars && message.author.id != widget.user.id
              ? min(constraints.maxWidth * 0.7, 2000).floor()
              : min(constraints.maxWidth * 0.7, 2000).floor();

      final messageWidget = Message(
        key: ValueKey(message.id),
        bubbleBuilder: widget.bubbleBuilder,
        customMessageBuilder: widget.customMessageBuilder,
        detailStatusBuilder: widget.detailStatusBuilder,
        emojiEnlargementBehavior: widget.emojiEnlargementBehavior,
        fileMessageBuilder: widget.fileMessageBuilder,
        hideBackgroundOnEmojiMessages: widget.hideBackgroundOnEmojiMessages,
        imageMessageBuilder: widget.imageMessageBuilder,
        isTV: widget.isTV,
        message: message,
        messageWidth: _messageWidth,
        onMessageLongPress: widget.onMessageLongPress,
        onMessageTap: (tappedMessage, offset) {
          if (tappedMessage is types.ImageMessage &&
              widget.disableImageGallery != true) {
            _onImagePressed(tappedMessage);
          }

          widget.onMessageTap?.call(tappedMessage, offset);
        },
        onPreviewDataFetched: _onPreviewDataFetched,
        replyMessage: _getReplyMessage(message.replyId),
        roundBorder: map['nextMessageInGroup'] == true,
        showAvatar: map['nextMessageInGroup'] == false,
        showName: map['showName'] == true,
        showStatus: map['showStatus'] == true,
        showUserAvatars: widget.showUserAvatars,
        simpleUI: widget.simpleUI,
        textMessageBuilder: widget.textMessageBuilder,
        emojiMessageBuilder: widget.emojiMessageBuilder,
        textSelectable: widget.textSelectable,
        usePreviewData: widget.usePreviewData,
        uriFixup: widget.uriFixup,
        logger: widget.logger,
      );
      return Container(
        child: messageWidget,
        constraints: BoxConstraints(maxWidth: constraints.maxWidth),
      );
    }
  }

  Widget _replyMessageBuilder() {
    final message = widget.replyMessage;
    if (message == null) {
      return const SizedBox();
    }
    return Column(
      children: [
        const Divider(height: 1),
        ReplyMessage(
          message: message,
          onClosed: () {
            widget.onCloseReplyMessagePressed?.call();
          },
          uriFixup: widget.uriFixup,
        ),
      ],
    );
  }

  void _onCloseGalleryPressed() {
    setState(() {
      _isImageViewVisible = false;
    });
  }

  void _onImagePressed(types.ImageMessage message) {
    setState(() {
      _imageViewIndex = _gallery.indexWhere((element) {
        return element.id == message.id;
      });
      _isImageViewVisible = true;
      if (widget.isTV) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) {
              return Scaffold(
                body: _imageGalleryBuilder(),
              );
            },
          ),
        );
      }
    });
  }

  void _onPageChanged(int index) {
    setState(() {
      _imageViewIndex = index;
    });
  }

  void _onPreviewDataFetched(
    types.TextMessage message,
    types.PreviewData previewData,
  ) {
    widget.onPreviewDataFetched?.call(message, previewData);
  }

  Widget get _messageList {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) => ChatList(
        reverse: !widget.isTV,
        isLastPage: widget.isLastPage,
        itemBuilder: (item, index) => _messageBuilder(item, constraints),
        items: _chatMessages,
        onEndReached: widget.onEndReached,
        onEndReachedThreshold: widget.onEndReachedThreshold,
        scrollPhysics: widget.scrollPhysics,
      ),
    );
  }

  Widget get _messageListForTV {
    return Column(
      children: [
        _replyMessageBuilder(),
        Flexible(
          child: widget.messages.isEmpty
              ? SizedBox.expand(child: _emptyStateBuilder())
              : _messageList,
        ),
      ],
    );
  }

  Widget get _input {
    return widget.customBottomWidget ??
        Input(
          isTV: widget.isTV,
          isAttachmentUploading: widget.isAttachmentUploading,
          leading: widget.inputLeading,
          onAttachmentPressed: widget.onAttachmentPressed,
          onSendPressed: widget.onSendPressed,
          onTextChanged: widget.onTextChanged,
          onTextFieldTap: widget.onTextFieldTap,
          onImageAssetSelected: widget.onImageAssetSelected,
          onEmojiSelected: widget.onEmojiSelected,
          onVoiceInput: widget.onVoiceInput,
          sendButtonVisibilityMode: widget.sendButtonVisibilityMode,
        );
  }

  Widget get _buildForTV {
    return InheritedUser(
      user: widget.user,
      child: InheritedChatTheme(
        theme: widget.theme,
        child: InheritedL10n(
          l10n: widget.l10n,
          child: Container(
            color: widget.simpleUI ? null : widget.theme.backgroundColor,
            child: Row(
              children: [
                _input,
                Expanded(child: _messageListForTV),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isTV) {
      return _buildForTV;
    }
    return InheritedUser(
      user: widget.user,
      child: InheritedChatTheme(
        theme: widget.theme,
        child: InheritedL10n(
          l10n: widget.l10n,
          child: Stack(
            children: [
              Container(
                color: widget.simpleUI ? null : widget.theme.backgroundColor,
                child: Column(
                  children: [
                    Flexible(
                      child: widget.messages.isEmpty
                          ? SizedBox.expand(
                              child: _emptyStateBuilder(),
                            )
                          : InkWell(
                              onTap: () {
                                FocusManager.instance.primaryFocus?.unfocus();
                                widget.onBackgroundTap?.call();
                              },
                              child: _messageList,
                            ),
                    ),
                    _input,
                    _replyMessageBuilder(),
                  ],
                ),
              ),
              if (_isImageViewVisible) _imageGalleryBuilder(),
            ],
          ),
        ),
      ),
    );
  }
}
