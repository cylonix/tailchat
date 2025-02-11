import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:cylonix_emojis/cylonix_emojis.dart';
import '../models/send_button_visibility_mode.dart';
import 'attachment_button.dart';
import 'inherited_chat_theme.dart';
import 'inherited_l10n.dart';
import 'send_button.dart';
import 'voice_recording.dart';

class NewLineIntent extends Intent {
  const NewLineIntent();
}

class SendMessageIntent extends Intent {
  const SendMessageIntent();
}

class EscapeIntent extends Intent {
  const EscapeIntent();
}

/// A class that represents bottom bar widget with a text field, attachment and
/// send buttons inside. By default hides send button when text field is empty.
class Input extends StatefulWidget {
  /// Creates [Input] widget
  const Input({
    Key? key,
    this.isTV = false,
    this.isAttachmentUploading,
    this.leading,
    this.onAttachmentPressed,
    required this.onSendPressed,
    this.onTextChanged,
    this.onTextFieldTap,
    this.onImageAssetSelected,
    this.onEmojiSelected,
    this.onVoiceInput,
    required this.sendButtonVisibilityMode,
  }) : super(key: key);

  /// Special handling for TV.
  final bool isTV;

  /// Handle special emojis through image message.
  final void Function(String)? onImageAssetSelected;

  /// Handle special emojis through emoji message.
  final void Function(String, String)? onEmojiSelected;

  /// See [AttachmentButton.onPressed]
  final void Function()? onAttachmentPressed;

  /// Whether attachment is uploading. Will replace attachment button with a
  /// [CircularProgressIndicator]. Since we don't have libraries for
  /// managing media in dependencies we have no way of knowing if
  /// something is uploading so you need to set this manually.
  final bool? isAttachmentUploading;

  /// Leading widget
  final Widget? leading;

  /// Will be called on [SendButton] tap. Has [types.PartialText] which can
  /// be transformed to [types.TextMessage] and added to the messages list.
  final void Function(types.PartialText) onSendPressed;

  /// Will be called whenever the text inside [TextField] changes
  final void Function(String)? onTextChanged;

  /// Will be called on [TextField] tap
  final void Function()? onTextFieldTap;

  /// Handle voice input
  final void Function(bool start)? onVoiceInput;

  /// Controls the visibility behavior of the [SendButton] based on the
  /// [TextField] state inside the [Input] widget.
  /// Defaults to [SendButtonVisibilityMode.editing].
  final SendButtonVisibilityMode sendButtonVisibilityMode;

  @override
  _InputState createState() => _InputState();
}

/// [Input] widget state
class _InputState extends State<Input> {
  final _inputFocusNode = FocusNode();
  final _voiceInputFocusNode = FocusNode();
  final _voiceRecordingFocusNode = FocusNode();
  bool _sendButtonVisible = false;
  bool _showSpecialEmojis = false;
  bool _showHoldToRecord = false;
  final _textController = TextEditingController();

  @override
  void initState() {
    super.initState();

    if (widget.sendButtonVisibilityMode == SendButtonVisibilityMode.editing) {
      _sendButtonVisible = _textController.text.trim() != '';
      _textController.addListener(_handleTextControllerChange);
    } else {
      _sendButtonVisible = true;
    }
    _inputFocusNode.addListener(() {
      if (_inputFocusNode.hasFocus) {
        _showSpecialEmojis = false;
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _inputFocusNode.dispose();
    _voiceInputFocusNode.dispose();
    _voiceRecordingFocusNode.dispose();
    _textController.dispose();
    super.dispose();
  }

  void _handleSendPressed() {
    final trimmedText = _textController.text.trim();
    if (trimmedText != '') {
      final _partialText = types.PartialText(text: trimmedText);
      widget.onSendPressed(_partialText);
      _textController.clear();
    } else {
      _inputFocusNode.unfocus();
    }
  }

  void _handleTextControllerChange() {
    setState(() {
      _sendButtonVisible = _textController.text.trim() != '';
    });
  }

  Widget _leftWidget() {
    if (widget.isAttachmentUploading == true) {
      return Container(
        height: 24,
        margin: widget.isTV ? null : const EdgeInsets.only(right: 16),
        width: 24,
        child: CircularProgressIndicator(
          backgroundColor: Colors.transparent,
          strokeWidth: 1.5,
          valueColor: AlwaysStoppedAnimation<Color>(
            InheritedChatTheme.of(context).theme.inputTextColor,
          ),
        ),
      );
    } else {
      return AttachmentButton(
        margin: widget.isTV ? null : const EdgeInsets.only(right: 16),
        onPressed: widget.onAttachmentPressed,
      );
    }
  }

  Widget get _selectSpecialEmoji {
    return SelectEmoji(
      onSelected: ({required String code, required String asset}) {
        if (widget.isTV) {
          Navigator.of(context).pop();
        }
        setState(() {
          _showSpecialEmojis = false;
        });
        widget.onImageAssetSelected?.call(asset);
        widget.onEmojiSelected?.call(code, asset);
      },
    );
  }

  Widget get _specialEmojis {
    return IconButton(
      focusColor: Colors.blueAccent,
      icon: Icon(
        Icons.emoji_emotions_outlined,
        color: InheritedChatTheme.of(context).theme.inputTextColor,
      ),
      onPressed: () {
        if (widget.isTV) {
          setState(() {
            _showSpecialEmojis = true;
          });
          showBottomSheet(
            constraints: const BoxConstraints(minWidth: double.infinity),
            context: context,
            builder: (context) => _selectSpecialEmoji,
          );
          return;
        }
        setState(() {
          _showSpecialEmojis = true;
          _showHoldToRecord = false;
          _inputFocusNode.unfocus();
        });
      },
    );
  }

  Widget get _keyboard {
    return IconButton(
      focusColor: Colors.blueAccent,
      icon: Icon(
        Icons.keyboard_outlined,
        color: InheritedChatTheme.of(context).theme.inputTextColor,
      ),
      onPressed: () {
        setState(() {
          _showSpecialEmojis = false;
          _showHoldToRecord = false;
          _inputFocusNode.requestFocus();
        });
      },
    );
  }

  Widget get _voiceInput {
    return IconButton(
      autofocus: widget.isTV,
      focusColor: Colors.blueAccent,
      focusNode: _voiceInputFocusNode,
      icon: Icon(
        Icons.mic_outlined,
        color: InheritedChatTheme.of(context).theme.inputTextColor,
      ),
      onPressed: () async {
        if (widget.isTV) {
          final l10n = InheritedL10n.of(context).l10n;
          final theme = InheritedChatTheme.of(context).theme;
          _voiceRecordingFocusNode.requestFocus();
          showBottomSheet(
            constraints: const BoxConstraints(minWidth: double.infinity),
            context: context,
            builder: (context) => InheritedChatTheme(
              theme: theme,
              child: InheritedL10n(
                l10n: l10n,
                child: _holdToRecord,
              ),
            ),
          );
          return;
        }
        setState(() {
          _showHoldToRecord = true;
          _showSpecialEmojis = false;
        });
      },
    );
  }

  Widget get _holdToRecord {
    return VoiceRecording(
      focusNode: _voiceRecordingFocusNode,
      onTapStartStop: widget.isTV,
      onStart: () => widget.onVoiceInput?.call(true),
      onStop: () {
        setState(() {
          _showHoldToRecord = false;
        });
        widget.onVoiceInput?.call(false);
      },
    );
  }

  Widget get _buildForTV {
    if (widget.onVoiceInput != null) {
      _voiceInputFocusNode.requestFocus();
    }
    return Material(
      color: Colors.black45,
      child: Container(
        alignment: Alignment.center,
        width: 128,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (widget.leading != null) widget.leading!,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  if (widget.onAttachmentPressed != null) _leftWidget(),
                  if (widget.onVoiceInput != null) _voiceInput,
                  _specialEmojis,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final _query = MediaQuery.of(context);
    final theme = InheritedChatTheme.of(context).theme;
    if (widget.isTV) {
      return _buildForTV;
    }

    return GestureDetector(
      onTap: () => _inputFocusNode.requestFocus(),
      child: Shortcuts(
        shortcuts: {
          LogicalKeySet(LogicalKeyboardKey.enter): const SendMessageIntent(),
          LogicalKeySet(LogicalKeyboardKey.enter, LogicalKeyboardKey.alt):
              const NewLineIntent(),
          LogicalKeySet(LogicalKeyboardKey.enter, LogicalKeyboardKey.shift):
              const NewLineIntent(),
          LogicalKeySet(LogicalKeyboardKey.escape): const EscapeIntent(),
        },
        child: Actions(
          actions: {
            SendMessageIntent: CallbackAction<SendMessageIntent>(
              onInvoke: (SendMessageIntent intent) => _handleSendPressed(),
            ),
            NewLineIntent: CallbackAction<NewLineIntent>(
              onInvoke: (NewLineIntent intent) {
                final _newValue = '${_textController.text}\r\n';
                _textController.value = TextEditingValue(
                  text: _newValue,
                  selection: TextSelection.fromPosition(
                    TextPosition(offset: _newValue.length),
                  ),
                );
                return null;
              },
            ),
            EscapeIntent: CallbackAction<EscapeIntent>(onInvoke: (intent) {
              _inputFocusNode.unfocus();
              return null;
            }),
          },
          child: Focus(
            autofocus: true,
            child: Column(
              children: [
                Padding(
                  padding: theme.inputPadding,
                  child: Material(
                    borderRadius: theme.inputBorderRadius,
                    color: theme.inputBackgroundColor,
                    child: Container(
                      padding: EdgeInsets.fromLTRB(
                        24 + _query.padding.left,
                        20,
                        24 + _query.padding.right,
                        20 + _query.viewInsets.bottom + _query.padding.bottom,
                      ),
                      child: _input,
                    ),
                  ),
                ),
                if (_showSpecialEmojis) _selectSpecialEmoji,
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget get _textInput {
    final theme = InheritedChatTheme.of(context).theme;
    return TextField(
      controller: _textController,
      cursorColor: theme.inputTextCursorColor,
      decoration: theme.inputTextDecoration.copyWith(
        hintStyle: theme.inputTextStyle.copyWith(
          color: theme.inputTextColor.withValues(alpha: 0.5),
        ),
        hintText: InheritedL10n.of(context).l10n.inputPlaceholder,
      ),
      focusNode: _inputFocusNode,
      keyboardType: TextInputType.multiline,
      maxLines: 5,
      minLines: 1,
      onChanged: widget.onTextChanged,
      onTap: widget.onTextFieldTap,
      style: theme.inputTextStyle.copyWith(color: theme.inputTextColor),
      textCapitalization: TextCapitalization.sentences,
    );
  }

  Widget get _input {
    return Row(
      children: [
        if (widget.onAttachmentPressed != null) _leftWidget(),
        Expanded(child: _showHoldToRecord ? _holdToRecord : _textInput),
        if (widget.onVoiceInput != null)
          Visibility(
            visible: !_sendButtonVisible,
            child: _showHoldToRecord ? _keyboard : _voiceInput,
          ),
        Visibility(
          visible: _sendButtonVisible,
          child: SendButton(
            onPressed: _handleSendPressed,
          ),
        ),
        Visibility(
          visible: !_sendButtonVisible,
          child: _showSpecialEmojis ? _keyboard : _specialEmojis,
        ),
      ],
    );
  }
}
