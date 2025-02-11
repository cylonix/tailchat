import 'package:flutter/material.dart';
import 'inherited_chat_theme.dart';
import 'inherited_l10n.dart';

/// A class that represents attachment button widget
class AttachmentButton extends StatelessWidget {
  /// Creates attachment button widget
  const AttachmentButton({
    Key? key,
    this.focusNode,
    this.margin,
    this.onPressed,
  }) : super(key: key);

  /// Callback for attachment button tap event
  final void Function()? onPressed;
  final EdgeInsets? margin;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 24,
      margin: margin,
      width: 24,
      child: IconButton(
        focusNode: focusNode,
        focusColor: Colors.blue,
        icon: InheritedChatTheme.of(context).theme.attachmentButtonIcon != null
            ? InheritedChatTheme.of(context).theme.attachmentButtonIcon!
            : Image.asset(
                'assets/icon-attachment.png',
                color: InheritedChatTheme.of(context).theme.inputTextColor,
                package: 'flutter_chat_ui',
              ),
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        tooltip:
            InheritedL10n.of(context).l10n.attachmentButtonAccessibilityLabel,
      ),
    );
  }
}
